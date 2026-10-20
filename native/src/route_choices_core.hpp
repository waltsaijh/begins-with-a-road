#pragma once
#include "portal_routes_core.hpp"

namespace road {
struct RouteChoice {
    int from=-1,to=-1,region=-1,corridor=-1,length=0;
    double cost=-1;
    std::vector<std::array<int,2>> dag;
    std::vector<int> cells;
};
struct RouteChoices {
    int vertices=0,start=-1,goal=-1;
    bool directed=false;
    double minimum_step_cost=0;
    std::vector<std::pair<int,int>> positions;
    std::vector<RouteChoice> edges;
};
inline RouteChoices build_route_choices(const PortalGraph &g,const PortalRoutes &geometry,const std::vector<double> &costs={}) {
    RouteChoices out;out.vertices=int(g.nodes.size());out.start=g.start_node;out.goal=g.goal_node;out.directed=true;
    if(!g.valid) return out;
    out.minimum_step_cost=costs.empty() ? 1.0 : *std::min_element(costs.begin(),costs.end());
    auto cost=[&](int a){return costs.empty() ? 1.0 : costs[a];};
    std::vector<int> node_at(g.cells.size(),-1);
    for(int i=0;i<out.vertices;++i) {int a=g.nodes[i].cell;node_at[a]=i;out.positions.push_back({g.cells[a].x,g.cells[a].y});}
    std::unordered_map<uint64_t,std::vector<int>> same_ends;
    auto append=[&](RouteChoice edge) {
        if(edge.dag.empty()) for(size_t i=1;i<edge.cells.size();++i) edge.dag.push_back({edge.cells[i-1],edge.cells[i]});
        std::sort(edge.dag.begin(),edge.dag.end());auto &bucket=same_ends[(uint64_t(uint32_t(edge.from))<<32)|uint32_t(edge.to)];
        for(int id:bucket) if(cost_equal(out.edges[id].cost,edge.cost) && out.edges[id].dag==edge.dag) return;
        bucket.push_back(int(out.edges.size()));out.edges.push_back(std::move(edge));
    };
    for(int c=0;c<int(g.corridors.size());++c) {
        const auto &walk=g.corridors[c].cells;int begin=0;
        for(int end=1;end<int(walk.size());++end) if(node_at[walk[end]]>=0) {
            int from=node_at[walk[begin]],to=node_at[walk[end]];
            if(from>=0 && from!=to) for(bool reverse:{false,true}) {
                RouteChoice e;e.from=reverse ? to : from;e.to=reverse ? from : to;e.corridor=c;e.length=end-begin;e.cost=0;
                for(int i=begin;i<=end;++i) e.cells.push_back(walk[reverse ? end-(i-begin) : i]);
                for(size_t i=1;i<e.cells.size();++i) e.cost+=cost(e.cells[i]);append(std::move(e));
            }
            begin=end;
        }
    }
    for(int r=0;r<int(g.regions.size());++r) {
        const auto &region=g.regions[r];const auto &data=geometry.regions[r];int n=int(region.cells.size());
        std::vector<std::vector<int>> adjacent(n);std::vector<double> local_costs;
        std::vector<bool> stops(n,false);std::vector<int> portals,locations;
        for(int a=0;a<n;++a) {local_costs.push_back(cost(region.cells[a]));if(node_at[region.cells[a]]>=0) {stops[a]=true;portals.push_back(node_at[region.cells[a]]);locations.push_back(a);}}
        for(auto e:data.links) {adjacent[e[0]].push_back(e[1]);adjacent[e[1]].push_back(e[0]);}
        for(int s=0;s<int(portals.size());++s) {
            auto field=tile_cost_field(adjacent,local_costs,locations[s],false,stops);
            for(int t=0;t<int(portals.size());++t) if(t!=s && field.distance[locations[t]]>=0) {
                std::vector<bool> active(n,false);active[locations[t]]=true;
                RouteChoice edge;edge.from=portals[s];edge.to=portals[t];edge.region=r;edge.cost=field.distance[locations[t]];
                std::vector<int> steps(n,INT32_MAX);steps[locations[t]]=0;
                for(auto it=field.order.rbegin();it!=field.order.rend();++it) if(active[*it]) {
                    int b=*it;
                    for(int a:adjacent[b]) if((a==locations[s] || !stops[a]) && cost_step(field.distance[a],field.distance[b],local_costs[b])) {
                        edge.dag.push_back({region.cells[a],region.cells[b]});active[a]=true;steps[a]=std::min(steps[a],steps[b]+1);
                    }
                }
                edge.length=steps[locations[s]];append(std::move(edge));
            }
        }
    }
    return out;
}
}
