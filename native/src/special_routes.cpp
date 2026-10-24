#include "special_routes.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <map>
#include <queue>
#include <set>
#include <vector>
#include <functional>
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
std::vector<int> bfs(const Grid &g,int root) {
    std::vector<int> dist(g.cells.size(),-1); std::queue<int> q; dist[root]=0;q.push(root);
    while(!q.empty()) {int u=q.front();q.pop();for(int v:g.adj[u]) if(dist[v]<0){dist[v]=dist[u]+1;q.push(v);}}
    return dist;
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
void RoadSpecialRoutes::_bind_methods() {
    ClassDB::bind_method(D_METHOD("plan","cells","ports","start","goal","history","shortest","work_limit"),&RoadSpecialRoutes::plan,DEFVAL(200000));
}
Dictionary RoadSpecialRoutes::plan(const PackedInt32Array &cells,const PackedByteArray &ports,Vector2i start,Vector2i goal,const Array &history,bool shortest,int64_t work_limit) {
    Dictionary out;out["valid"]=true;Array packed_routes;out["paths"]=packed_routes;
    Grid g(cells,ports);Cell sc={start.x,start.y},tc={goal.x,goal.y};
    if(!g.ids.count(sc)||!g.ids.count(tc))return out;
    int s=g.ids[sc],t=g.ids[tc];auto ds=bfs(g,s),dt=bfs(g,t);if(ds[t]<0)return out;
    std::set<std::vector<int>> paths;
    int newest=-1;
    std::vector<std::set<std::pair<int,int>>> old_edges;
    std::vector<int> waves;
    bool monotone=true;std::set<std::pair<int,int>> previous;
    for(int i=0;i<history.size();++i){
        Dictionary h=history[i];Vector2i hg=h["goal"];PackedVector2Array starts=h["starts"];
        if(hg!=goal||!starts.has(Vector2(start)))continue;
        Grid old(h["cells"],h["ports"]);std::set<std::pair<int,int>> present;
        for(auto e:g.edges)if(old.has_edge(g.cells[e.first],g.cells[e.second]))present.insert(e);
        if(!std::includes(present.begin(),present.end(),previous.begin(),previous.end()))monotone=false;
        previous=present;old_edges.push_back(present);waves.push_back((int)h["wave"]);
    }
    auto birth=[&](const std::vector<int> &p){
        for(size_t i=0;i<old_edges.size();++i){bool valid=true;for(size_t j=1;j<p.size();++j){auto e=std::minmax(p[j-1],p[j]);if(!old_edges[i].count(e)){valid=false;break;}}if(valid)return waves[i];}
        return -1;
    };
    auto keep=[&](const std::vector<int> &p){if(p.empty())return;int w=shortest?0:birth(p);if(w<newest)return;if(w>newest){newest=w;paths.clear();}paths.insert(p);};
    int64_t work=0;
    if(shortest){
        // One shortest witness per directed DAG edge, no exponential enumeration.
        for(int u=0;u<(int)g.cells.size();++u)for(int v:g.adj[u])if(ds[u]>=0&&dt[v]>=0&&ds[u]+1+dt[v]==ds[t]){
            std::vector<int> p={u};int at=u;while(at!=s){for(int next:g.adj[at])if(ds[next]==ds[at]-1){at=next;break;}p.push_back(at);}
            std::reverse(p.begin(),p.end());p.push_back(v);at=v;
            while(at!=t){for(int next:g.adj[at])if(dt[next]==dt[at]-1){at=next;break;}p.push_back(at);}keep(p);++work;
        }
    }else if(monotone){
        // Any new complete choice contains a newly established edge. Exact
        // witnesses cover every viable edge, independently of ordinary budgets.
        for(auto e:g.edges){keep(witness(g,s,t,e.first,e.second));++work;}
    }else{
        // Non-monotone editing needs simultaneous-history checks. Bound work;
        // never silently return an older batch without proving eligibility.
        std::vector<int> p={s};std::vector<bool> used(g.cells.size());used[s]=true;bool exhausted=false;
        std::function<void(int)> visit=[&](int at){
            if(exhausted)return;if(++work>work_limit){exhausted=true;return;}if(at==t){keep(p);return;}
            for(int next:g.adj[at])if(!used[next]&&dt[next]>=0){used[next]=true;p.push_back(next);visit(next);p.pop_back();used[next]=false;if(exhausted)return;}
        };visit(s);
        if(exhausted){out["valid"]=false;out["error"]="Scout history search budget exceeded; no older-route fallback";out["work"]=work;return out;}
    }
    if(s==t)keep({s});
    for(auto &p:paths){PackedVector2Array points;for(int id:p)points.push_back(Vector2(g.cells[id].first,g.cells[id].second));Dictionary route;route["cells"]=points;route["birth_wave"]=newest;packed_routes.push_back(route);}
    out["birth_wave"]=newest;out["work"]=work;out["history_monotone"]=monotone;out["distance"]=ds[t];return out;
}
