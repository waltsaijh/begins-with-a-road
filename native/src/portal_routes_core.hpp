#pragma once
#include "portal_graph_core.hpp"
#include "tile_cost_core.hpp"

namespace road {
struct RegionRouteData {
    std::vector<std::array<int,2>> links;
    std::vector<int> node_cells,visible_links;
    std::vector<double> distances,reverse_distances,cell_costs;
};
struct LocalRoute {
    int region,from,to,source_field,target_field,length;
    int64_t count;
    bool count_capped;
    double score=0,reverse_score=0;
};
struct PortalRoutes {std::vector<RegionRouteData> regions;std::vector<LocalRoute> pairs;};

inline PortalRoutes build_portal_geometry(const PortalGraph &graph) {
    PortalRoutes out;if(!graph.valid) return out;out.regions.resize(graph.regions.size());
    std::vector<std::vector<std::array<int,2>>> global_links(graph.regions.size());
    {
        std::unordered_map<uint64_t,int> index;index.reserve(graph.cells.size()*2);
        for(int a=0;a<int(graph.cells.size());++a) index.emplace(portal_detail::key(graph.cells[a].x,graph.cells[a].y),a);
        for(const auto &quad:graph.quads) {
            const auto &c=graph.cells[quad.cell];int a=quad.cell,b=index.at(portal_detail::key(c.x+1,c.y));
            int v=index.at(portal_detail::key(c.x+1,c.y+1)),d=index.at(portal_detail::key(c.x,c.y+1));
            auto &links=global_links[quad.region];links.insert(links.end(),{{a,b},{b,v},{d,v},{a,d}});
        }
    }
    std::vector<int> local(graph.cells.size(),-1);
    for(int r=0;r<int(graph.regions.size());++r) {
        const auto &region=graph.regions[r];auto &data=out.regions[r];int n=int(region.cells.size());
        for(int a=0;a<n;++a) local[region.cells[a]]=a;
        {
            for(auto e:global_links[r]) {int a=local[e[0]],b=local[e[1]];if(a>b) std::swap(a,b);data.links.push_back({a,b});}
            std::sort(data.links.begin(),data.links.end());data.links.erase(std::unique(data.links.begin(),data.links.end()),data.links.end());
        }
        for(int node:region.nodes) data.node_cells.push_back(local[graph.nodes[node].cell]);
    }
    return out;
}

inline PortalRoutes build_portal_routes(const PortalGraph &graph,const std::vector<double> &costs={},const PortalRoutes *geometry=nullptr) {
    PortalRoutes out;if(!graph.valid) return out;out.regions.resize(graph.regions.size());
    PortalRoutes built;if(!geometry) built=build_portal_geometry(graph);
    const auto &shape=geometry ? *geometry : built;
    std::vector<int> local(graph.cells.size(),-1);
    for(int r=0;r<int(graph.regions.size());++r) {
        const auto &region=graph.regions[r];auto &data=out.regions[r];int n=int(region.cells.size()),p=int(region.nodes.size());
        data.links=shape.regions[r].links;data.cell_costs.reserve(n);
        for(int a=0;a<n;++a) {local[region.cells[a]]=a;data.cell_costs.push_back(costs.empty() ? 1.0 : costs[region.cells[a]]);}
        std::vector<std::vector<int>> adjacent(n),edges(n);
        for(int e=0;e<int(data.links.size());++e) {int a=data.links[e][0],b=data.links[e][1];adjacent[a].push_back(b);edges[a].push_back(e);adjacent[b].push_back(a);edges[b].push_back(e);}
        for(int node:region.nodes) data.node_cells.push_back(local[graph.nodes[node].cell]);
        data.distances.assign(size_t(p)*n,-1);data.reverse_distances.assign(size_t(p)*n,-1);
        std::vector<bool> visible(data.links.size(),false);
        bool uniform=std::all_of(data.cell_costs.begin(),data.cell_costs.end(),[&](double c){return c==data.cell_costs[0];});
        for(int s=0;s<p;++s) {
            int origin=data.node_cells[s];auto field=tile_cost_field(adjacent,data.cell_costs,origin);
            CostField reverse;
            if(!uniform) reverse=tile_cost_field(adjacent,data.cell_costs,origin,true);
            const auto &reverse_distance=uniform ? field.distance : reverse.distance;
            std::copy(field.distance.begin(),field.distance.end(),data.distances.begin()+size_t(s)*n);
            std::copy(reverse_distance.begin(),reverse_distance.end(),data.reverse_distances.begin()+size_t(s)*n);
            std::vector<int64_t> ways(n,0);std::vector<bool> capped(n,false),active(n,false);
            std::vector<int> steps(n,INT32_MAX);ways[origin]=1;steps[origin]=0;
            for(int a:field.order) for(int b:adjacent[a]) if(cost_step(field.distance[a],field.distance[b],data.cell_costs[b])) {
                steps[b]=std::min(steps[b],steps[a]+1);
                if(capped[a] || ways[b]>INT64_MAX-ways[a]) {ways[b]=INT64_MAX;capped[b]=true;}else ways[b]+=ways[a];
            }
            for(int t=0;t<p;++t) if(t!=s) {
                int a=data.node_cells[t];if(field.distance[a]<0) continue;active[a]=true;
                if(s<t) out.pairs.push_back({r,region.nodes[s],region.nodes[t],s,t,steps[a],ways[a],capped[a],field.distance[a],reverse_distance[a]});
            }
            for(auto it=field.order.rbegin();it!=field.order.rend();++it) if(active[*it]) {
                int a=*it;
                for(size_t i=0;i<adjacent[a].size();++i) {int b=adjacent[a][i];if(cost_step(field.distance[b],field.distance[a],data.cell_costs[a])) {active[b]=true;visible[edges[a][i]]=true;}}
            }
        }
        for(int e=0;e<int(visible.size());++e) if(visible[e]) data.visible_links.push_back(e);
    }
    return out;
}
}
