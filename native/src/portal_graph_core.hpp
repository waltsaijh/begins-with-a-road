#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <numeric>
#include <unordered_map>
#include <utility>
#include <vector>

namespace road {
struct Tile { int x, y; uint8_t ports; };
struct PortalNode {
    int cell=-1, component=-1;
    const char *kind="portal";
    std::vector<int> window, regions;
};
struct Corridor { int from, to; std::vector<int> cells; };
struct PassageRegion {
    int component=-1;
    bool divided_obstacle=false;
    std::vector<int> cells, nodes;
};
struct Border { int a, b, region, neighbor; };
struct FilledQuad { int cell, region; };
struct PortalGraph {
    std::vector<Tile> cells;
    std::vector<PortalNode> nodes;
    std::vector<Corridor> corridors;
    std::vector<PassageRegion> regions;
    std::vector<Border> borders;
    std::vector<FilledQuad> quads;
    int physical_edges=0, faces=0, components=0, cycles=0, logical_cycles=0;
    int start_node=-1, goal_node=-1, divided_components=0;
    bool valid=true;
    const char *error="";
};

namespace portal_detail {
struct Dsu {
    std::vector<int> parent, size;
    explicit Dsu(int n):parent(n),size(n,1) { std::iota(parent.begin(),parent.end(),0); }
    int find(int a) {
        while(parent[a]!=a) {parent[a]=parent[parent[a]];a=parent[a];}
        return a;
    }
    void join(int a,int b) {
        a=find(a);b=find(b);if(a==b) return;
        if(size[a]<size[b]) std::swap(a,b);
        parent[b]=a;size[a]+=size[b];
    }
};
inline uint64_t key(int x,int y) { return (uint64_t(uint32_t(x))<<32)|uint32_t(y); }
inline void unique_append(std::vector<int> &values,int value) {
    if(std::find(values.begin(),values.end(),value)==values.end()) values.push_back(value);
}
struct Edge {
    int a,b;
    std::array<int,2> faces{{-1,-1}};
    int face_count=0;
};
struct Face { std::array<int,4> vertices,edges; int region=-1; };
struct Run { int column,lo,hi;std::vector<int> faces; };
}

// Build a cell-and-portal graph, not a list of paths. A fully connected 2x2
// plaquette is a filled face: lane changes inside it are equivalent.
inline PortalGraph build_portal_graph(std::vector<Tile> tiles,
                                     std::pair<int,int> start,
                                     std::pair<int,int> goal,
                                     const std::vector<std::pair<int,int>> &extra_terminals={}) {
    using namespace portal_detail;
    PortalGraph out;
    std::sort(tiles.begin(),tiles.end(),[](const Tile &a,const Tile &b){return a.y!=b.y ? a.y<b.y : a.x<b.x;});
    out.cells=std::move(tiles);
    const int n=int(out.cells.size());
    std::unordered_map<uint64_t,int> index;
    index.reserve(n*2);
    for(int a=0;a<n;++a) {
        const auto &c=out.cells[a];
        if(c.x<=-32767 || c.x>=32767 || c.y<=-32767 || c.y>=32767 || !index.emplace(key(c.x,c.y),a).second) {
            out.valid=false;out.error="invalid_or_duplicate_cell";return out;
        }
    }
    auto lookup=[&](int x,int y) {auto it=index.find(key(x,y));return it==index.end() ? -1 : it->second;};
    const int source=lookup(start.first,start.second),target=lookup(goal.first,goal.second);
    std::vector<bool> terminal(n,false);
    if(source>=0) terminal[source]=true;
    if(target>=0) terminal[target]=true;
    std::vector<int> extra_cells;
    for(auto cell:extra_terminals) {
        int a=lookup(cell.first,cell.second);
        if(a<0) {out.valid=false;out.error="missing_terminal";return out;}
        if(!terminal[a]) {terminal[a]=true;extra_cells.push_back(a);}
    }
    constexpr int dx[4]={0,1,0,-1},dy[4]={-1,0,1,0};
    std::vector<std::array<int,4>> neighbors(n,{{-1,-1,-1,-1}}),edge_at(n,{{-1,-1,-1,-1}});
    std::vector<Edge> edges;
    for(int a=0;a<n;++a) for(int d:{1,2}) {
        const auto &c=out.cells[a];int b=lookup(c.x+dx[d],c.y+dy[d]);
        if(b<0 || !(c.ports&(1<<d)) || !(out.cells[b].ports&(1<<((d+2)%4)))) continue;
        int e=int(edges.size());edges.push_back({a,b});
        neighbors[a][d]=b;neighbors[b][(d+2)%4]=a;
        edge_at[a][d]=edge_at[b][(d+2)%4]=e;
    }
    auto other=[&](int e,int a){return edges[e].a==a ? edges[e].b : edges[e].a;};
    out.physical_edges=int(edges.size());
    std::vector<int> component(n,-1),queue;
    for(int seed=0;seed<n;++seed) if(component[seed]<0) {
        queue={seed};component[seed]=out.components;
        for(size_t head=0;head<queue.size();++head) for(int b:neighbors[queue[head]]) if(b>=0 && component[b]<0) {
            component[b]=out.components;queue.push_back(b);
        }
        ++out.components;
    }
    std::vector<Face> faces;
    for(int a=0;a<n;++a) {
        int b=neighbors[a][1],d=neighbors[a][2];
        if(b<0 || d<0) continue;
        int c=neighbors[b][2];if(c<0 || neighbors[d][1]!=c) continue;
        int f=int(faces.size());
        faces.push_back({{{a,b,c,d}},{{edge_at[a][1],edge_at[b][2],edge_at[d][1],edge_at[a][2]}}});
        for(int e:faces.back().edges) edges[e].faces[edges[e].face_count++]=f;
    }
    out.faces=int(faces.size());
    out.cycles=out.physical_edges-n+out.components-out.faces;

    // Adjacent filled faces form wide components. Vertex-only contact is a gate,
    // not permission to merge the two broad areas.
    Dsu face_groups(int(faces.size()));
    for(const auto &e:edges) if(e.face_count==2) face_groups.join(e.faces[0],e.faces[1]);
    std::vector<std::vector<int>> groups(faces.size());
    for(int f=0;f<int(faces.size());++f) groups[face_groups.find(f)].push_back(f);
    std::vector<int> vertex_stamp(n,-1),edge_stamp(edges.size(),-1);
    auto new_region=[&](int f,bool divided) {
        int id=int(out.regions.size());PassageRegion r;
        r.component=component[faces[f].vertices[0]];r.divided_obstacle=divided;
        out.regions.push_back(std::move(r));return id;
    };
    for(int group=0;group<int(groups.size());++group) if(!groups[group].empty()) {
        auto &members=groups[group];int vertices=0,boundaries=0;
        int min_x=32767,max_x=-32767,min_y=32767,max_y=-32767;
        for(int f:members) {
            const auto &c=out.cells[faces[f].vertices[0]];
            min_x=std::min(min_x,c.x);max_x=std::max(max_x,c.x);
            min_y=std::min(min_y,c.y);max_y=std::max(max_y,c.y);
            for(int a:faces[f].vertices) if(vertex_stamp[a]!=group) {vertex_stamp[a]=group;++vertices;}
            for(int e:faces[f].edges) if(edge_stamp[e]!=group) {edge_stamp[e]=group;++boundaries;}
        }
        const int holes=boundaries-vertices+1-int(members.size());
        if(!holes) {
            int region=new_region(members[0],false);
            for(int f:members) faces[f].region=region;
            continue;
        }
        ++out.divided_components;
        // A holed area is split only at sweep split/merge events. Continuing
        // one-to-one runs remain ONE region even if their width changes.
        // Each resulting region is monotone and hole-free.
        bool horizontal=(max_x-min_x)>=(max_y-min_y);
        auto major=[&](int f){const auto &c=out.cells[faces[f].vertices[0]];return horizontal ? c.x : c.y;};
        auto minor=[&](int f){const auto &c=out.cells[faces[f].vertices[0]];return horizontal ? c.y : c.x;};
        std::sort(members.begin(),members.end(),[&](int a,int b){return major(a)!=major(b) ? major(a)<major(b) : minor(a)<minor(b);});
        std::vector<Run> runs;
        for(int f:members) {
            int x=major(f),y=minor(f);
            if(runs.empty() || runs.back().column!=x || runs.back().hi+1!=y) runs.push_back({x,y,y,{}});
            runs.back().hi=y;runs.back().faces.push_back(f);
        }
        std::vector<int> incoming(runs.size()),outgoing(runs.size());
        std::vector<std::pair<int,int>> joins;
        int previous_begin=0,previous_end=0;
        for(int begin=0;begin<int(runs.size());) {
            int end=begin+1;while(end<int(runs.size()) && runs[end].column==runs[begin].column) ++end;
            if(previous_end>previous_begin && runs[previous_begin].column+1==runs[begin].column) {
                int a=previous_begin,b=begin;
                while(a<previous_end && b<end) {
                    if(std::max(runs[a].lo,runs[b].lo)<=std::min(runs[a].hi,runs[b].hi)) {
                        joins.push_back({a,b});++outgoing[a];++incoming[b];
                    }
                    if(runs[a].hi<runs[b].hi) ++a;
                    else if(runs[b].hi<runs[a].hi) ++b;
                    else {++a;++b;}
                }
            }
            previous_begin=begin;previous_end=end;begin=end;
        }
        Dsu slabs(int(runs.size()));
        for(auto pair:joins) if(outgoing[pair.first]==1 && incoming[pair.second]==1) slabs.join(pair.first,pair.second);
        std::vector<int> slab_region(runs.size(),-1);
        for(int r=0;r<int(runs.size());++r) {
            int root=slabs.find(r);
            if(slab_region[root]<0) slab_region[root]=new_region(runs[r].faces[0],true);
            for(int f:runs[r].faces) faces[f].region=slab_region[root];
        }
    }

    std::vector<std::vector<int>> memberships(n);
    for(const auto &f:faces) {
        out.quads.push_back({f.vertices[0],f.region});
        for(int a:f.vertices) unique_append(memberships[a],f.region);
    }
    for(int a=0;a<n;++a) for(int region:memberships[a]) out.regions[region].cells.push_back(a);
    for(const auto &e:edges) if(e.face_count) {
        int a=faces[e.faces[0]].region,b=e.face_count==2 ? faces[e.faces[1]].region : -1;
        if(a!=b) out.borders.push_back({e.a,e.b,a,b});
    }

    // A shared boundary window is one portal. Its physical cells remain in the
    // result, so later movement need not be forced through its display marker.
    Dsu windows(n);
    for(const auto &e:edges) if(e.face_count==2 && faces[e.faces[0]].region!=faces[e.faces[1]].region) windows.join(e.a,e.b);
    std::vector<std::vector<int>> window_cells(n);
    for(int a=0;a<n;++a) if(memberships[a].size()>1) window_cells[windows.find(a)].push_back(a);
    std::vector<int> node_at(n,-1),parent(n,-1),narrow_degree(n);
    for(const auto &e:edges) if(!e.face_count) {++narrow_degree[e.a];++narrow_degree[e.b];}
    auto add_node=[&](int cell,std::vector<int> cells,std::vector<int> regions,const char *kind,bool assign=true) {
        int id=int(out.nodes.size());out.nodes.push_back({cell,component[cell],kind,std::move(cells),std::move(regions)});
        for(int region:out.nodes.back().regions) out.regions[region].nodes.push_back(id);
        if(assign) for(int a:out.nodes.back().window) node_at[a]=id;
        return id;
    };
    for(auto &window:window_cells) if(!window.empty()) {
        long long sx=0,sy=0;std::vector<int> regions;
        for(int a:window) {sx+=out.cells[a].x;sy+=out.cells[a].y;for(int r:memberships[a]) unique_append(regions,r);}
        auto score=[&](int a){long long x=out.cells[a].x*int(window.size())-sx,y=out.cells[a].y*int(window.size())-sy;return x*x+y*y;};
        int center=window[0];for(int a:window) if(score(a)<score(center)) center=a;
        if(std::find(window.begin(),window.end(),source)!=window.end()) center=source;
        else if(std::find(window.begin(),window.end(),target)!=window.end()) center=target;
        int id=add_node(center,window,regions,"portal");
        queue={center};parent[center]=center;
        for(size_t head=0;head<queue.size();++head) for(int e:edge_at[queue[head]]) if(e>=0 && edges[e].face_count) {
            int b=other(e,queue[head]);
            if(node_at[b]==id && parent[b]<0) {parent[b]=queue[head];queue.push_back(b);}
        }
    }
    for(int a=0;a<n;++a) if(node_at[a]<0) {
        bool portal=!memberships[a].empty() && narrow_degree[a]>0;
        bool external=memberships[a].empty() && (narrow_degree[a]!=2 || terminal[a]);
        if(portal || external) {
            const char *kind=portal ? "portal" : narrow_degree[a]>2 ? "junction" : narrow_degree[a]==0 ? "isolated" : "end";
            add_node(a,{a},memberships[a],kind);parent[a]=a;
        }
    }
    auto root_path=[&](int cell) {
        std::vector<int> path{cell};
        while(parent[path.back()]>=0 && parent[path.back()]!=path.back()) path.push_back(parent[path.back()]);
        std::reverse(path.begin(),path.end());return path;
    };
    auto endpoint=[&](int cell) {
        if(cell<0) return -1;
        int id=node_at[cell];
        if(id<0) {parent[cell]=cell;return add_node(cell,{cell},memberships[cell],"terminal");}
        if(out.nodes[id].cell==cell) return id;
        int terminal=add_node(cell,{cell},{},"terminal",false);
        out.corridors.push_back({id,terminal,root_path(cell)});return terminal;
    };
    out.start_node=endpoint(source);out.goal_node=source==target ? out.start_node : endpoint(target);
    // Obstacles can turn a secondary spawn into a degree-two corridor cell.
    // Keep every spawn explicit, including terminals inside a broad region/window.
    for(int a:extra_cells) endpoint(a);

    std::vector<bool> used(edges.size(),false);
    auto append_corridor=[&](int from,int to,const std::vector<int> &walk) {
        auto path=root_path(walk.front());path.insert(path.end(),walk.begin()+1,walk.end());
        auto tail=root_path(walk.back());
        for(int i=int(tail.size())-2;i>=0;--i) path.push_back(tail[i]);
        out.corridors.push_back({from,to,std::move(path)});
    };
    auto trace_node=[&](int id) {
        // Copy because a closed corridor may append a loop endpoint below.
        auto members=out.nodes[id].window;
        for(int a:members) if(node_at[a]==id) for(int first:edge_at[a]) {
            if(first<0 || edges[first].face_count || used[first]) continue;
            std::vector<int> walk{a};int current=a,e=first;
            while(true) {
                used[e]=true;current=other(e,current);walk.push_back(current);
                if(node_at[current]>=0) break;
                int next=-1;
                for(int candidate:edge_at[current]) if(candidate>=0 && !edges[candidate].face_count && !used[candidate]) {next=candidate;break;}
                if(next<0) {out.valid=false;out.error="unfinished_corridor";return;}
                e=next;
            }
            int to=node_at[current];
            if(to==id) {
                int middle=int(walk.size())/2,cell=walk[middle];parent[cell]=cell;
                int loop=add_node(cell,{cell},{},"loop");
                append_corridor(id,loop,{walk.begin(),walk.begin()+middle+1});
                append_corridor(loop,id,{walk.begin()+middle,walk.end()});
            } else append_corridor(id,to,walk);
        }
    };
    for(int id=0;id<int(out.nodes.size());++id) trace_node(id);
    // Components consisting solely of a thin closed loop have no natural ends.
    for(int e=0;e<int(edges.size());++e) if(!edges[e].face_count && !used[e]) {
        int a=edges[e].a;parent[a]=a;int id=add_node(a,{a},{},"loop");trace_node(id);
    }

    // Regions are hyperedges, represented internally by incidence vertices with
    // NO physical position. Do not turn p portals into a clique of p*(p-1)/2
    // independent edges: that would invent cycles inside an empty broad area.
    int visible=int(out.nodes.size()),logical=visible+int(out.regions.size()),links=int(out.corridors.size());
    Dsu connectivity(logical);
    for(const auto &e:out.corridors) connectivity.join(e.from,e.to);
    for(int r=0;r<int(out.regions.size());++r) for(int node:out.regions[r].nodes) {connectivity.join(node,visible+r);++links;}
    int logical_components=0;
    for(int a=0;a<logical;++a) if(connectivity.find(a)==a) ++logical_components;
    out.logical_cycles=links-logical+logical_components;
    if(logical_components!=out.components || out.logical_cycles!=out.cycles) {out.valid=false;out.error="topology_mismatch";}
    return out;
}
}
