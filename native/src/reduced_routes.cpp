#include "reduced_routes.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <queue>
#include <set>
#include <vector>
using namespace godot;
namespace {
using Cell = std::pair<int,int>;
struct Grid {
    std::vector<Cell> cells;
    std::map<Cell,int> ids;
    std::vector<std::vector<int>> adj;
    std::vector<std::pair<int,int>> edges;
    Grid(const PackedInt32Array &packed,const PackedByteArray &ports) {
        std::map<Cell,int> masks;
        for(int i=0;i<ports.size() && i*2+1<packed.size();++i) masks[{packed[i*2],packed[i*2+1]}]=ports[i];
        for(auto &p:masks) {ids[p.first]=(int)cells.size(); cells.push_back(p.first);}
        adj.resize(cells.size());
        const int dx[4]={0,1,0,-1},dy[4]={-1,0,1,0};
        for(int i=0;i<(int)cells.size();++i) for(int d=0;d<4;++d) {
            Cell b={cells[i].first+dx[d],cells[i].second+dy[d]};
            auto it=masks.find(b);
            if((masks[cells[i]]&(1<<d)) && it!=masks.end() && (it->second&(1<<((d+2)%4)))) {
                int j=ids[b]; adj[i].push_back(j); if(i<j) edges.push_back({i,j});
            }
        }
    }
    bool has_edge(Cell a,Cell b) const {
        auto i=ids.find(a),j=ids.find(b); if(i==ids.end() || j==ids.end()) return false;
        return std::find(adj[i->second].begin(),adj[i->second].end(),j->second)!=adj[i->second].end();
    }
};
std::vector<int> bfs(const Grid &g,int root,const std::vector<char> &allowed) {
    std::vector<int> dist(g.cells.size(),-1); std::queue<int> q; dist[root]=0;q.push(root);
    while(!q.empty()) {int u=q.front();q.pop();for(int v:g.adj[u]) if(allowed[v]&&dist[v]<0){dist[v]=dist[u]+1;q.push(v);}}
    return dist;
}
// Lowest achievable "worst tile" from s to t, Dijkstra with max in place of sum.
double bottleneck(const Grid &g,int s,int t,const std::vector<double> &score) {
    std::vector<double> best(g.cells.size(),std::numeric_limits<double>::infinity());
    using Item=std::pair<double,int>;
    std::priority_queue<Item,std::vector<Item>,std::greater<Item>> q;
    best[s]=score[s];q.push({best[s],s});
    while(!q.empty()){
        auto [at,u]=q.top();q.pop();if(at>best[u])continue;
        for(int v:g.adj[u]){double next=std::max(at,score[v]);if(next<best[v]){best[v]=next;q.push({next,v});}}
    }
    return best[t];
}
// Two units of vertex-capacitated flow connect the edge's two ends to distinct
// terminals. This proves a SIMPLE s-t path through that edge; spurs cannot pass.
std::vector<int> witness(const Grid &g,int s,int t,int a,int b) {
    struct Edge {int to,rev,cap,original;};
    int n=(int)g.cells.size(),source=2*n,sink=source+1;
    std::vector<std::vector<Edge>> net(2*n+2);
    auto add=[&](int u,int v,int cap) {
        int ui=(int)net[u].size(),vi=(int)net[v].size();
        net[u].push_back({v,vi,cap,cap});net[v].push_back({u,ui,0,0});
    };
    for(int i=0;i<n;++i) add(2*i,2*i+1,1);
    for(int u=0;u<n;++u) for(int v:g.adj[u]) {
        if((u==a&&v==b)||(u==b&&v==a)) continue;
        add(2*u+1,2*v,1);
    }
    add(source,2*a,1);add(source,2*b,1);add(2*s+1,sink,1);add(2*t+1,sink,1);
    for(int flow=0;flow<2;++flow) {
        std::vector<int> parent(net.size(),-1),pe(net.size());std::queue<int> q;
        parent[source]=source;q.push(source);
        while(!q.empty()&&parent[sink]<0){int u=q.front();q.pop();for(int i=0;i<(int)net[u].size();++i){auto &e=net[u][i];if(e.cap>0&&parent[e.to]<0){parent[e.to]=u;pe[e.to]=i;q.push(e.to);}}}
        if(parent[sink]<0) return {};
        for(int v=sink;v!=source;v=parent[v]){auto &e=net[parent[v]][pe[v]];--e.cap;++net[v][e.rev].cap;}
    }
    auto extract=[&](int at) {
        std::vector<int> parent(net.size(),-1);std::queue<int> q;parent[2*at]=2*at;q.push(2*at);
        while(!q.empty()&&parent[sink]<0){int u=q.front();q.pop();for(auto &e:net[u])if(e.original>0&&e.cap<e.original&&parent[e.to]<0){parent[e.to]=u;q.push(e.to);}}
        std::vector<int> path;
        if(parent[sink]<0) return path;
        for(int v=parent[sink];;v=parent[v]){if(v%2==0)path.push_back(v/2);if(v==2*at)break;}
        std::reverse(path.begin(),path.end());return path;
    };
    auto left=extract(a),right=extract(b);
    if(left.empty()||right.empty())return {};
    if(left.back()!=s) std::swap(left,right);
    if(left.back()!=s||right.back()!=t)return {};
    std::reverse(left.begin(),left.end());left.insert(left.end(),right.begin(),right.end());return left;
}
}
void RoadReducedRoutes::_bind_methods() {
    ClassDB::bind_method(D_METHOD("plan","cells","ports","start","goal","tile_scores","use_min"),&RoadReducedRoutes::plan);
}
// tile_scores follows cells. Max keeps the shortest routes under the lowest
// reachable worst tile; min keeps routes through the lowest reachable tile.
Dictionary RoadReducedRoutes::plan(const PackedInt32Array &cells,const PackedByteArray &ports,Vector2i start,Vector2i goal,const PackedFloat64Array &tile_scores,bool use_min) {
    Dictionary out;Array packed_routes;out["paths"]=packed_routes;
    Grid g(cells,ports);Cell sc={start.x,start.y},tc={goal.x,goal.y};
    if(!g.ids.count(sc)||!g.ids.count(tc))return out;
    int s=g.ids[sc],t=g.ids[tc];
    std::vector<double> score(g.cells.size(),std::numeric_limits<double>::infinity());
    for(int i=0;i<tile_scores.size()&&i*2+1<cells.size();++i){auto id=g.ids.find({cells[i*2],cells[i*2+1]});if(id!=g.ids.end())score[id->second]=tile_scores[i];}
    std::vector<char> every(g.cells.size(),1);
    if(bfs(g,s,every)[t]<0)return out;
    std::set<std::vector<int>> paths;
    if(use_min){
        std::map<double,std::vector<int>> batches;
        for(int i=0;i<(int)g.cells.size();++i)if(std::isfinite(score[i]))batches[score[i]].push_back(i);
        // Tiles this entrance cannot route through yield no witness, so the
        // search moves on to the next lowest batch.
        for(auto &batch:batches){
            for(int tile:batch.second)for(int next:g.adj[tile]){auto p=witness(g,s,t,tile,next);if(!p.empty())paths.insert(p);}
            if(!paths.empty())break;
        }
    }else{
        double limit=bottleneck(g,s,t,score);
        std::vector<char> allowed(g.cells.size(),0);
        for(int i=0;i<(int)g.cells.size();++i)allowed[i]=score[i]<=limit;
        auto ds=bfs(g,s,allowed),dt=bfs(g,t,allowed);
        // One shortest witness per directed DAG edge, no exponential enumeration.
        for(int u=0;u<(int)g.cells.size();++u)for(int v:g.adj[u])if(allowed[u]&&allowed[v]&&ds[u]>=0&&dt[v]>=0&&ds[u]+1+dt[v]==ds[t]){
            std::vector<int> p={u};int at=u;while(at!=s){for(int next:g.adj[at])if(allowed[next]&&ds[next]==ds[at]-1){at=next;break;}p.push_back(at);}
            std::reverse(p.begin(),p.end());p.push_back(v);at=v;
            while(at!=t){for(int next:g.adj[at])if(allowed[next]&&dt[next]==dt[at]-1){at=next;break;}p.push_back(at);}paths.insert(p);
        }
    }
    if(s==t)paths.insert({s});
    for(auto &p:paths){PackedVector2Array points;for(int id:p)points.push_back(Vector2(g.cells[id].first,g.cells[id].second));Dictionary route;route["cells"]=points;packed_routes.push_back(route);}
    return out;
}
