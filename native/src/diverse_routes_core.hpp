#pragma once
#include "route_choices_core.hpp"
#include "waypoint_routes_core.hpp"
#include <map>
#include <set>
#include <tuple>

namespace road {
inline uint64_t route_random(uint64_t &state) {
    state+=0x9e3779b97f4a7c15ULL;uint64_t z=state;
    z=(z^(z>>30))*0xbf58476d1ce4e5b9ULL;z=(z^(z>>27))*0x94d049bb133111ebULL;return z^(z>>31);
}
struct PoolRoute {std::vector<int> nodes,edges;double score=0;};
struct DiversePlan {
    bool valid=true,reachable=false;const char *error="";
    int start=-1,goal=-1,attempts=0,expanded=0,rejected=0,duplicates=0;
    int waypoint_attempts=0,waypoint_searches=0,waypoint_expanded=0,waypoint_added=0;
    double score=0;const char *stop="unreachable";
    std::vector<PoolRoute> routes;
};
// Full cyclic road graph: two directed cost entries share one physical-road
// penalty, but retain their own entering-tile cost and local shortest walks.
inline DiversePlan build_diverse_routes(const RouteChoices &g,int start,int goal,
                                        double threshold=10,double penalty=1,int budget=64) {
    DiversePlan out;out.start=start;out.goal=goal;
    auto fail=[&](const char *e){out.valid=false;out.error=e;return out;};
    if(start<0 || goal<0 || start>=g.vertices || goal>=g.vertices) return fail("invalid_endpoint");
    if(std::isnan(threshold) || threshold<0) return fail("threshold_must_be_nonnegative");
    if(!std::isfinite(penalty) || penalty<0) return fail("penalty_must_be_nonnegative_finite");
    if(budget<1 || budget>256) return fail("search_budget_out_of_range");
    std::vector<std::vector<std::pair<int,int>>> adjacent(g.vertices);
    std::map<std::tuple<int,int,int,int>,int> roads;
    std::vector<int> road_ids;
    for(int id=0;id<int(g.edges.size());++id) {
        const auto &e=g.edges[id];
        if(e.from<0 || e.to<0 || e.from>=g.vertices || e.to>=g.vertices) return fail("invalid_edge");
        if(!std::isfinite(e.cost) || e.cost<=0 || e.length<=0) return fail("cost_must_be_positive_finite");
        adjacent[e.from].push_back({id,e.to});if(!g.directed) adjacent[e.to].push_back({id,e.from});
        auto key=std::make_tuple(std::min(e.from,e.to),std::max(e.from,e.to),e.region,e.corridor);
        auto inserted=roads.emplace(key,int(roads.size()));road_ids.push_back(inserted.first->second);
    }
    std::vector<int> uses(roads.size(),0);std::set<std::vector<int>> seen;
    int stale=0;const double inf=std::numeric_limits<double>::infinity();
    for(int attempt=0;attempt<budget;++attempt) {
        ++out.attempts;
        std::vector<double> distance(g.vertices,inf);std::vector<int> parent(g.vertices,-1),via(g.vertices,-1);
        using Item=std::pair<double,int>;std::priority_queue<Item,std::vector<Item>,std::greater<Item>> queue;
        distance[start]=0;queue.push({0,start});
        while(!queue.empty()) {
            auto [d,a]=queue.top();queue.pop();if(d!=distance[a]) continue;
            ++out.expanded;if(a==goal) break;
            for(auto [id,b]:adjacent[a]) {
                const auto &e=g.edges[id];double cost=e.cost+penalty*e.length*uses[road_ids[id]];
                double candidate=d+cost;
                if(!std::isfinite(candidate) || candidate<=d) return fail("cost_overflow_or_below_numeric_resolution");
                if(candidate<distance[b]) {distance[b]=candidate;parent[b]=a;via[b]=id;queue.push({candidate,b});}
            }
        }
        if(!std::isfinite(distance[goal])) break;
        PoolRoute route;int v=goal;route.nodes.push_back(v);
        while(v!=start) {int id=via[v];route.edges.push_back(id);route.score+=g.edges[id].cost;v=parent[v];route.nodes.push_back(v);}
        std::reverse(route.nodes.begin(),route.nodes.end());std::reverse(route.edges.begin(),route.edges.end());
        if(!out.reachable) {out.reachable=true;out.score=route.score;}
        // Also penalize rejected/repeated candidates to escape plateaus. These
        // exploration counters are not enemy traffic and never alter scoring.
        for(int id:route.edges) ++uses[road_ids[id]];
        bool accepted=threshold>0 && route.score-out.score<threshold;
        bool fresh=accepted && seen.insert(route.edges).second;
        if(fresh) {out.routes.push_back(std::move(route));stale=0;}
        else {++stale;if(accepted) ++out.duplicates;else ++out.rejected;}
        if(threshold==0) {out.stop="zero_threshold";break;}
        if(penalty==0 || start==goal) {out.stop="no_diversification";break;}
        if(stale>=8) {out.stop="no_new_route";break;}
        out.stop="search_budget";
    }
    // One completion pass only after eight consecutive unsuccessful attempts.
    // Snapshot the unused roads so both directions get a chance, even when
    // the first accepted route also covers another pending waypoint.
    if(stale>=8 && start!=goal) {
        waypoint_detail::Adjacency reverse(g.vertices);
        for(int a=0;a<g.vertices;++a) for(auto [id,b]:adjacent[a]) reverse[b].push_back({id,a});
        std::vector<bool> blocked(g.vertices,false),unused(uses.size(),false);
        for(size_t i=0;i<uses.size();++i) unused[i]=uses[i]==0;
        bool any=std::any_of(unused.begin(),unused.end(),[](bool value){return value;});
        if(!any) return out;
        auto from_start=waypoint_detail::shortest(g,adjacent,start,blocked,-1,out.waypoint_searches,out.waypoint_expanded);
        auto to_goal=waypoint_detail::shortest(g,reverse,goal,blocked,-1,out.waypoint_searches,out.waypoint_expanded);
        for(int a=0;a<g.vertices;++a) for(auto [id,b]:adjacent[a]) if(unused[road_ids[id]]) {
            ++out.waypoint_attempts;
            double lower_bound=from_start.distance[a]+g.edges[id].cost+to_goal.distance[b];
            if(!std::isfinite(lower_bound) || lower_bound-out.score>=threshold) continue;
            auto walk=waypoint_detail::through(g,adjacent,reverse,from_start,to_goal,start,goal,id,a,b,out.waypoint_searches,out.waypoint_expanded);
            if(walk.nodes.empty() || walk.score-out.score>=threshold || !seen.insert(walk.edges).second) continue;
            PoolRoute route;route.nodes=std::move(walk.nodes);route.edges=std::move(walk.edges);route.score=walk.score;
            out.routes.push_back(std::move(route));++out.waypoint_added;
        }
        if(out.waypoint_added) out.stop="waypoint_completion";
    }
    return out;
}
}
