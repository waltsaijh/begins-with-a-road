#include "route_planner.hpp"
#include "portal_routes_pack.hpp"
#include <chrono>
#include <set>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
using namespace godot;
using Clock=std::chrono::steady_clock;
static uint64_t micros(Clock::time_point began) {return uint64_t(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now()-began).count());}
static Dictionary copy_plan_summary(const Dictionary &source) {return source.duplicate(true);}
void RoadRoutePlanner::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare","graph"),&RoadRoutePlanner::prepare);
    ClassDB::bind_method(D_METHOD("find_paths","profile","tile_costs","start","goal","score_threshold","overlap_penalty","search_budget"),&RoadRoutePlanner::find_paths,DEFVAL(String("default")),DEFVAL(PackedFloat64Array()),DEFVAL(-1),DEFVAL(-1),DEFVAL(10.0),DEFVAL(1.0),DEFVAL(64));
    ClassDB::bind_method(D_METHOD("sample_route","profile","seed","route_index"),&RoadRoutePlanner::sample_route,DEFVAL(String("default")),DEFVAL(0),DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("get_region_paths","profile"),&RoadRoutePlanner::get_region_paths,DEFVAL(String("default")));
    ClassDB::bind_method(D_METHOD("get_debug_graph","profile"),&RoadRoutePlanner::get_debug_graph,DEFVAL(String("default")));
    ClassDB::bind_method(D_METHOD("invalidate","profile"),&RoadRoutePlanner::invalidate,DEFVAL(String("")));
}
void RoadRoutePlanner::invalidate(const String &profile) {if(profile.is_empty()) profiles.clear();else profiles.erase(profile.utf8().get_data());}
Dictionary RoadRoutePlanner::prepare(const Dictionary &graph) {
    auto began=Clock::now();physical=road::PortalGraph{};geometry=road::PortalRoutes{};profiles.clear();input_error="";prepare_us=0;
    auto status=[&](){
        Dictionary result;result["valid"]=!*input_error;result["error"]=input_error;result["prepare_us"]=int64_t(prepare_us);result["vertices"]=int64_t(physical.nodes.size());
        PackedVector2Array positions;for(const auto &c:physical.cells) positions.push_back(Vector2(c.x,c.y));result["cells"]=positions;
        int64_t bytes=physical.cells.capacity()*sizeof(road::Tile)+physical.nodes.capacity()*sizeof(road::PortalNode);
        for(const auto &r:physical.regions) bytes+=sizeof(r)+(r.cells.capacity()+r.nodes.capacity())*sizeof(int);
        for(const auto &c:physical.corridors) bytes+=sizeof(c)+c.cells.capacity()*sizeof(int);
        for(const auto &r:geometry.regions) bytes+=sizeof(r)+r.links.capacity()*sizeof(std::array<int,2>);
        result["geometry_bytes"]=bytes;return result;
    };
    if(!bool(graph.get("valid",false)) || !graph.has("tiles")) {input_error="invalid_graph";return status();}
    std::unordered_map<uint64_t,int> cells;
    auto intern=[&](Vector2i cell) {
        auto key=road::portal_detail::key(cell.x,cell.y);auto found=cells.find(key);if(found!=cells.end()) return found->second;
        int id=int(physical.cells.size());physical.cells.push_back({cell.x,cell.y,15});cells.emplace(key,id);return id;
    };
    PackedVector2Array tile_cells=graph["tiles"];for(int i=0;i<tile_cells.size();++i) intern(Vector2i(tile_cells[i]));
    Array nodes=graph["nodes"],regions=graph["regions"],corridors=graph["corridors"];
    for(int i=0;i<nodes.size();++i) {Dictionary source=nodes[i];road::PortalNode node;node.cell=intern(source["cell"]);physical.nodes.push_back(std::move(node));}
    physical.regions.resize(regions.size());geometry.regions.resize(regions.size());
    for(int r=0;r<regions.size();++r) {
        Dictionary source=regions[r];auto &region=physical.regions[r];auto &data=geometry.regions[r];
        PackedVector2Array area=source["cells"];PackedInt32Array attached=source["nodes"],links=source["route_links"];
        for(int a=0;a<area.size();++a) region.cells.push_back(intern(Vector2i(area[a])));
        for(int a=0;a<attached.size();++a) {int id=attached[a];if(id<0 || id>=nodes.size()) {input_error="invalid_region_node";return status();}region.nodes.push_back(id);}
        if(links.size()%2) {input_error="invalid_region_links";return status();}
        for(int a=0;a<links.size();a+=2) {
            if(links[a]<0 || links[a+1]<0 || links[a]>=area.size() || links[a+1]>=area.size()) {input_error="invalid_region_link";return status();}
            data.links.push_back({links[a],links[a+1]});
        }
    }
    for(int e=0;e<corridors.size();++e) {
        Dictionary source=corridors[e];road::Corridor edge;edge.from=source["from"];edge.to=source["to"];
        PackedVector2Array walk=source["cells"];for(int a=0;a<walk.size();++a) edge.cells.push_back(intern(Vector2i(walk[a])));
        physical.corridors.push_back(std::move(edge));
    }
    if(physical.cells.size()!=size_t(tile_cells.size())) {input_error="unknown_tile_in_graph";return status();}
    physical.start_node=graph.get("start_node",-1);physical.goal_node=graph.get("goal_node",-1);
    prepare_us=micros(began);return status();
}
Dictionary RoadRoutePlanner::find_paths(const String &profile,const PackedFloat64Array &costs,int64_t start,int64_t goal,double threshold,double penalty,int64_t budget) {
    Dictionary result;result["valid"]=false;result["reachable"]=false;result["error"]=input_error;if(*input_error) return result;
    auto began=Clock::now();std::string key=profile.utf8().get_data();std::vector<double> weights;
    if(costs.is_empty()) weights.assign(physical.cells.size(),1.0);else for(int i=0;i<costs.size();++i) weights.push_back(costs[i]);
    const char *error=weights.size()!=physical.cells.size() ? "tile_cost_size_mismatch" : "";
    for(double c:weights) if(!std::isfinite(c) || c<=0) {error="tile_cost_must_be_positive_finite";break;}
    if(std::isnan(threshold) || threshold<0) error="threshold_must_be_nonnegative";
    if(!std::isfinite(penalty) || penalty<0) error="penalty_must_be_nonnegative_finite";
    if(budget<1 || budget>256) error="search_budget_out_of_range";
    if(*error) {profiles.erase(key);result["error"]=error;return result;}
    int from=start<0 ? physical.start_node : int(start),to=goal<0 ? physical.goal_node : int(goal);
    auto found=profiles.find(key);bool geometry_cached=found!=profiles.end() && found->second.weights==weights;
    if(geometry_cached && found->second.plan.start==from && found->second.plan.goal==to && found->second.threshold==threshold && found->second.penalty==penalty && found->second.budget==budget) {
        result=copy_plan_summary(found->second.summary);result["cached"]=true;result["geometry_cached"]=true;return result;
    }
    if(!geometry_cached) {
        CachedPlan item;item.weights=std::move(weights);auto local_began=Clock::now();
        item.local=road::build_portal_routes(physical,item.weights,&geometry);item.local_us=micros(local_began);
        auto choices_began=Clock::now();item.choices=road::build_route_choices(physical,geometry,item.weights);item.choices_us=micros(choices_began);
        profiles[key]=std::move(item);found=profiles.find(key);
    }
    auto &entry=found->second;auto search_began=Clock::now();
    entry.plan=road::build_diverse_routes(entry.choices,from,to,threshold,penalty,int(budget));entry.search_us=micros(search_began);
    entry.debug_graph.clear();
    entry.threshold=threshold;entry.penalty=penalty;entry.budget=int(budget);
    const auto &plan=entry.plan;
    result["valid"]=plan.valid;result["error"]=plan.error;result["reachable"]=plan.reachable;result["score"]=plan.score;
    result["routes"]=int64_t(plan.routes.size());result["choice_edges"]=int64_t(entry.choices.edges.size());
    result["score_threshold"]=threshold;result["overlap_penalty"]=penalty;result["search_budget"]=budget;
    result["attempts"]=plan.attempts;result["expanded"]=plan.expanded;result["rejected"]=plan.rejected;result["duplicates"]=plan.duplicates;result["stop_reason"]=plan.stop;
    result["waypoint_attempts"]=plan.waypoint_attempts;result["waypoint_searches"]=plan.waypoint_searches;
    result["waypoint_expanded"]=plan.waypoint_expanded;result["waypoint_added"]=plan.waypoint_added;
    result["geometry_cached"]=geometry_cached;result["cached"]=false;
    result["local_us"]=int64_t(entry.local_us);result["choices_us"]=int64_t(entry.choices_us);result["search_us"]=int64_t(entry.search_us);
    int64_t bytes=sizeof(CachedPlan)+entry.weights.capacity()*sizeof(double)+entry.choices.edges.capacity()*sizeof(road::RouteChoice)+entry.choices.positions.capacity()*sizeof(std::pair<int,int>);
    for(const auto &e:entry.choices.edges) bytes+=e.cells.capacity()*sizeof(int)+e.dag.capacity()*sizeof(std::array<int,2>);
    for(const auto &r:entry.local.regions) bytes+=sizeof(r)+(r.distances.capacity()+r.reverse_distances.capacity()+r.cell_costs.capacity())*sizeof(double)+(r.node_cells.capacity()+r.visible_links.capacity())*sizeof(int)+r.links.capacity()*sizeof(std::array<int,2>);
    bytes+=entry.local.pairs.capacity()*sizeof(road::LocalRoute)+plan.routes.capacity()*sizeof(road::PoolRoute);
    std::set<int> used_edges,used_nodes;
    for(const auto &r:plan.routes) {bytes+=(r.nodes.capacity()+r.edges.capacity())*sizeof(int);used_edges.insert(r.edges.begin(),r.edges.end());used_nodes.insert(r.nodes.begin(),r.nodes.end());}
    result["plan_bytes"]=bytes;result["active_nodes"]=int64_t(used_nodes.size());result["used_edges"]=int64_t(used_edges.size());
    std::set<std::array<int,2>> physical_directions;std::vector<int> steps;
    for(int id:used_edges) {const auto &e=entry.choices.edges[id];steps.insert(steps.end(),{e.from,id,e.to});for(auto link:e.dag) physical_directions.insert(link);}
    PackedVector2Array directions;directions.resize(physical_directions.size()*2);Vector2 *write=directions.ptrw();size_t cursor=0;
    for(auto link:physical_directions) for(int id:link) {const auto &p=physical.cells[id];write[cursor++]=Vector2(p.x,p.y);}
    result["steps"]=pack_route_values<PackedInt32Array>(steps);result["directions"]=directions;
    result["cpu_us"]=int64_t(micros(began));entry.summary=copy_plan_summary(result);return result;
}
Dictionary RoadRoutePlanner::get_region_paths(const String &profile) const {
    Dictionary result;auto found=profiles.find(profile.utf8().get_data());if(found==profiles.end() || !found->second.plan.valid) return result;
    Array regions;for(const auto &data:found->second.local.regions) {Dictionary region;pack_region_routes(region,data);regions.push_back(region);}
    result["regions"]=regions;result["local_routes"]=pack_local_routes(found->second.local);return result;
}
Dictionary RoadRoutePlanner::get_debug_graph(const String &profile) {
    auto found=profiles.find(profile.utf8().get_data());if(found==profiles.end() || !found->second.plan.valid) return {};
    auto &entry=found->second;
    if(!entry.debug_graph.is_empty()) return entry.debug_graph.duplicate(true);
    std::set<int> nodes,edge_ids;
    for(const auto &route:entry.plan.routes) {nodes.insert(route.nodes.begin(),route.nodes.end());edge_ids.insert(route.edges.begin(),route.edges.end());}
    Array edges;
    for(int id:edge_ids) {
        const auto &e=entry.choices.edges[id];Dictionary edge;
        edge["id"]=id;edge["from"]=e.from;edge["to"]=e.to;edge["cost"]=e.cost;
        PackedVector2Array links;links.resize(e.dag.size()*2);Vector2 *write=links.ptrw();size_t i=0;
        for(auto link:e.dag) for(int cell:link) {const auto &p=physical.cells[cell];write[i++]=Vector2(p.x,p.y);}
        edge["links"]=links;edges.push_back(edge);
    }
    std::vector<int> ids(nodes.begin(),nodes.end());
    entry.debug_graph["nodes"]=pack_route_values<PackedInt32Array>(ids);entry.debug_graph["edges"]=edges;
    return entry.debug_graph.duplicate(true);
}
Dictionary RoadRoutePlanner::sample_route(const String &profile,int64_t seed,int64_t route_index) const {
    Dictionary result;auto found=profiles.find(profile.utf8().get_data());if(found==profiles.end()) return result;
    const auto &entry=found->second;const auto &plan=entry.plan;if(!plan.valid || plan.routes.empty()) return result;
    if(route_index < -1 || route_index >= int64_t(plan.routes.size())) return result;
    uint64_t state=uint64_t(seed);auto random=[&](){return road::route_random(state);};
    // Consume the same RNG value in both modes so the seeded local walk stays
    // identical when its randomly selected pool entry is requested explicitly.
    size_t random_index=random()%plan.routes.size();
    size_t index=route_index<0 ? random_index : size_t(route_index);const auto &route=plan.routes[index];
    PackedVector2Array walk;double score=0;
    auto append=[&](int cell,bool charge=true){const auto &p=physical.cells[cell];walk.push_back(Vector2(p.x,p.y));if(charge) score+=entry.weights[cell];};
    append(physical.nodes[plan.start].cell,false);
    for(int id:route.edges) {
        const auto &edge=entry.choices.edges[id];
        if(!edge.cells.empty()) {for(size_t i=1;i<edge.cells.size();++i) append(edge.cells[i]);}
        else {
            int cell=physical.nodes[edge.from].cell,target=physical.nodes[edge.to].cell;size_t length=0;
            while(cell!=target) {
                auto first=std::lower_bound(edge.dag.begin(),edge.dag.end(),std::array<int,2>{cell,INT32_MIN});
                auto last=std::upper_bound(edge.dag.begin(),edge.dag.end(),std::array<int,2>{cell,INT32_MAX});
                if(first==last || ++length>physical.cells.size()) return Dictionary{};
                cell=(first+random()%size_t(last-first))->at(1);append(cell);
            }
        }
    }
    if(!road::cost_equal(score,route.score) || route.score-plan.score>=entry.threshold) return Dictionary{};
    result["nodes"]=pack_route_values<PackedInt32Array>(route.nodes);result["edges"]=pack_route_values<PackedInt32Array>(route.edges);
    result["cells"]=walk;result["length"]=walk.size()-1;result["score"]=score;result["best_score"]=plan.score;result["route_index"]=int64_t(index);return result;
}
