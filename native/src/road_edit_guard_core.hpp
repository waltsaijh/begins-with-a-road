#pragma once
#include "portal_graph_core.hpp"

namespace road {
// Freeze the terminal-connecting block-cut forest as separate anchors. Every
// other component has at most one anchor. Additions only need four DSU joins;
// connecting two distinct anchors is the first edit that can add a route.
class RoadEditGuardCore {
    std::unordered_map<uint64_t,int> index;
    std::vector<int> parent,size,anchor;
    bool dirty=true;
    int root(int a) {
        while(parent[a]!=a) {parent[a]=parent[parent[a]];a=parent[a];}
        return a;
    }
    bool join(int a,int b) {
        a=root(a);b=root(b);if(a==b) return false;
        bool connects=anchor[a]>=0 && anchor[b]>=0 && anchor[a]!=anchor[b];
        if(size[a]<size[b]) std::swap(a,b);
        parent[b]=a;size[a]+=size[b];if(anchor[a]<0) anchor[a]=anchor[b];
        return connects;
    }
public:
    int route_tiles=0;
    bool prepare(const std::vector<Tile> &tiles,const std::vector<std::pair<int,int>> &terminals) {
        dirty=true;index.clear();parent.clear();size.clear();anchor.clear();route_tiles=0;
        int n=int(tiles.size());index.reserve(n*2);
        for(int a=0;a<n;++a) if(!index.emplace(portal_detail::key(tiles[a].x,tiles[a].y),a).second) return false;
        constexpr int dx[4]={0,1,0,-1},dy[4]={-1,0,1,0};
        std::vector<std::vector<int>> adjacent(n);
        for(int a=0;a<n;++a) for(int d=0;d<4;++d) if(tiles[a].ports&(1<<d)) {
            auto found=index.find(portal_detail::key(tiles[a].x+dx[d],tiles[a].y+dy[d]));
            if(found!=index.end() && (tiles[found->second].ports&(1<<((d+2)%4)))) adjacent[a].push_back(found->second);
        }
        // Iterative Tarjan: long roads never consume the C++/Web call stack.
        std::vector<int> discovery(n,-1),low(n),up(n,-1),next(n),stack,stamp(n,-1);
        std::vector<std::pair<int,int>> edges;
        std::vector<std::vector<int>> blocks;
        int clock=0;
        for(int seed=0;seed<n;++seed) if(discovery[seed]<0) {
            discovery[seed]=low[seed]=clock++;stack.push_back(seed);
            while(!stack.empty()) {
                int a=stack.back();
                if(next[a]<int(adjacent[a].size())) {
                    int b=adjacent[a][next[a]++];
                    if(discovery[b]<0) {
                        up[b]=a;discovery[b]=low[b]=clock++;edges.push_back({a,b});stack.push_back(b);
                    } else if(b!=up[a] && discovery[b]<discovery[a]) {
                        low[a]=std::min(low[a],discovery[b]);edges.push_back({a,b});
                    }
                } else {
                    stack.pop_back();int p=up[a];if(p<0) continue;
                    low[p]=std::min(low[p],low[a]);
                    if(low[a]>=discovery[p]) {
                        int block=int(blocks.size());blocks.emplace_back();
                        while(!edges.empty()) {
                            auto edge=edges.back();edges.pop_back();
                            for(int v:{edge.first,edge.second}) if(stamp[v]!=block) {stamp[v]=block;blocks.back().push_back(v);}
                            if(edge.first==p && edge.second==a) break;
                        }
                    }
                }
            }
        }
        // Vertex/block incidence is a forest. Its terminal-connecting subtree
        // marks whole biconnected blocks, retaining both sides of obstacles.
        std::vector<std::vector<int>> tree(n+blocks.size());
        for(int b=0;b<int(blocks.size());++b) for(int v:blocks[b]) {tree[v].push_back(n+b);tree[n+b].push_back(v);}
        std::vector<int> endpoints,tree_up(tree.size(),-1),queue;
        for(auto cell:terminals) {
            auto found=index.find(portal_detail::key(cell.first,cell.second));if(found==index.end()) return false;
            int endpoint=found->second;endpoints.push_back(endpoint);
            if(tree_up[endpoint]!=-1) continue;
            tree_up[endpoint]=-2;queue={endpoint};
            for(size_t head=0;head<queue.size();++head) for(int b:tree[queue[head]]) if(tree_up[b]==-1) {tree_up[b]=queue[head];queue.push_back(b);}
        }
        std::vector<bool> marked(tree.size(),false),active(n,false);
        for(int endpoint:endpoints) {
            active[endpoint]=true;
            for(int a=endpoint;a>=0 && !marked[a];a=tree_up[a]) marked[a]=true;
        }
        for(int b=0;b<int(blocks.size());++b) if(marked[n+b]) for(int v:blocks[b]) active[v]=true;
        parent.resize(n);std::iota(parent.begin(),parent.end(),0);size.assign(n,1);anchor.assign(n,-1);
        for(int a=0;a<n;++a) if(active[a]) {anchor[a]=a;++route_tiles;}
        for(int a=0;a<n;++a) for(int b:adjacent[a]) if(a<b && (!active[a] || !active[b])) if(join(a,b)) return false;
        dirty=false;return true;
    }
    bool add_cell(int x,int y) {
        if(dirty) return true;
        auto inserted=index.emplace(portal_detail::key(x,y),int(parent.size()));
        if(!inserted.second) return false;
        int a=int(parent.size());parent.push_back(a);size.push_back(1);anchor.push_back(-1);
        constexpr int dx[4]={0,1,0,-1},dy[4]={-1,0,1,0};
        for(int d=0;d<4;++d) {
            auto found=index.find(portal_detail::key(x+dx[d],y+dy[d]));
            if(found!=index.end() && join(a,found->second)) dirty=true;
        }
        return dirty;
    }
};
}
