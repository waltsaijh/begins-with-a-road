#include "portal_graph.hpp"
#include "portal_graph_core.hpp"
#include "portal_routes_core.hpp"
#include "portal_routes_pack.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
using namespace godot;

void RoadPortalGraph::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build","cells","ports","start","goal","include_routes","extra_terminals"),&RoadPortalGraph::build,DEFVAL(true),DEFVAL(PackedVector2Array()));
}
Dictionary RoadPortalGraph::build(const PackedInt32Array &cells,const PackedByteArray &ports,Vector2i start,Vector2i goal,bool include_routes,const PackedVector2Array &extra_terminals) const {
    Dictionary result;
    if(cells.size()!=ports.size()*2) {result["valid"]=false;result["error"]="input_size_mismatch";return result;}
    std::vector<road::Tile> input;input.reserve(ports.size());
    for(int i=0;i<ports.size();++i) input.push_back({cells[i*2],cells[i*2+1],ports[i]});
    std::vector<std::pair<int,int>> terminals;terminals.reserve(extra_terminals.size());
    for(int i=0;i<extra_terminals.size();++i) terminals.push_back({int(extra_terminals[i].x),int(extra_terminals[i].y)});
    auto graph=road::build_portal_graph(std::move(input),{start.x,start.y},{goal.x,goal.y},terminals);
    auto routing=include_routes ? road::build_portal_routes(graph) : road::build_portal_geometry(graph);
    auto position=[&](int a){return Vector2(graph.cells[a].x,graph.cells[a].y);};
    auto positions=[&](const std::vector<int> &ids) {PackedVector2Array out;out.resize(ids.size());Vector2 *write=out.ptrw();for(size_t i=0;i<ids.size();++i) write[i]=position(ids[i]);return out;};
    Array nodes,regions,corridors;
    for(int id=0;id<int(graph.nodes.size());++id) {
        const auto &n=graph.nodes[id];Dictionary node;
        node["id"]=id;node["cell"]=Vector2i(position(n.cell));node["window"]=positions(n.window);node["regions"]=pack_route_values<PackedInt32Array>(n.regions);
        node["kind"]=n.kind;node["component"]=n.component;node["is_start"]=id==graph.start_node;node["is_goal"]=id==graph.goal_node;
        nodes.push_back(node);
    }
    for(int id=0;id<int(graph.regions.size());++id) {
        const auto &r=graph.regions[id];Dictionary region;
        region["id"]=id;region["cells"]=positions(r.cells);region["nodes"]=pack_route_values<PackedInt32Array>(r.nodes);region["component"]=r.component;
        region["divided_obstacle"]=r.divided_obstacle;
        if(graph.valid) pack_region_routes(region,routing.regions[id]);
        regions.push_back(region);
    }
    Array local_routes=pack_local_routes(routing);
    for(int id=0;id<int(graph.corridors.size());++id) {
        const auto &e=graph.corridors[id];Dictionary corridor;
        corridor["id"]=id;corridor["from"]=e.from;corridor["to"]=e.to;corridor["cells"]=positions(e.cells);corridors.push_back(corridor);
    }
    PackedVector2Array borders;PackedInt32Array border_regions;
    for(const auto &b:graph.borders) {borders.push_back(position(b.a));borders.push_back(position(b.b));border_regions.push_back(b.region);border_regions.push_back(b.neighbor);}
    PackedVector2Array quads;PackedInt32Array quad_regions;
    for(const auto &q:graph.quads) {quads.push_back(position(q.cell));quad_regions.push_back(q.region);}
    Dictionary stats;stats["tiles"]=int(graph.cells.size());stats["physical_edges"]=graph.physical_edges;stats["faces"]=graph.faces;
    stats["components"]=graph.components;stats["cycles"]=graph.cycles;stats["logical_cycles"]=graph.logical_cycles;
    stats["nodes"]=nodes.size();stats["regions"]=regions.size();stats["corridors"]=corridors.size();stats["divided_components"]=graph.divided_components;
    stats["local_routes"]=local_routes.size();
    result["valid"]=graph.valid;result["error"]=graph.error;result["nodes"]=nodes;result["regions"]=regions;result["corridors"]=corridors;
    result["borders"]=borders;result["border_regions"]=border_regions;result["stats"]=stats;
    result["quads"]=quads;result["quad_regions"]=quad_regions;
    result["local_routes"]=local_routes;
    PackedVector2Array tile_cells;for(int a=0;a<int(graph.cells.size());++a) tile_cells.push_back(position(a));result["tiles"]=tile_cells;
    result["start_node"]=graph.start_node;result["goal_node"]=graph.goal_node;
    return result;
}
