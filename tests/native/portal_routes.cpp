#include "../../native/src/portal_routes_core.hpp"
#include <chrono>
#include <iostream>
#include <set>
#include <stdexcept>
#include <string>
#define CHECK(x) do {if(!(x)) throw std::runtime_error("line "+std::to_string(__LINE__)+": "+#x);} while(false)
using Point=std::pair<int,int>;
static road::PortalGraph rectangle(int w,int h,Point start,Point goal) {
    std::vector<road::Tile> tiles;
    for(int y=0;y<h;++y) for(int x=0;x<w;++x) tiles.push_back({x,y,15});
    auto graph=road::build_portal_graph(tiles,start,goal);CHECK(graph.valid);return graph;
}
static std::set<std::array<int,2>> dag(const road::PortalGraph &g,const road::PortalRoutes &routes,const road::LocalRoute &pair) {
    const auto &data=routes.regions[pair.region];int n=int(g.regions[pair.region].cells.size());
    const double *ds=data.distances.data()+pair.source_field*n,*dt=data.reverse_distances.data()+pair.target_field*n;
    std::set<std::array<int,2>> result;
    for(auto link:data.links) {
        int a=link[0],b=link[1];
        if(ds[a]+1+dt[b]==pair.length) result.insert({a,b});
        if(ds[b]+1+dt[a]==pair.length) result.insert({b,a});
    }
    return result;
}
static void verify(const road::PortalGraph &graph,const road::PortalRoutes &routes) {
    CHECK(routes.regions.size()==graph.regions.size());
    for(int r=0;r<int(graph.regions.size());++r) {
        const auto &region=graph.regions[r];const auto &data=routes.regions[r];
        int n=int(region.cells.size()),p=int(region.nodes.size()),pairs=0;
        CHECK(data.distances.size()==size_t(n)*p && data.node_cells.size()==size_t(p));
        std::set<std::array<int,2>> expected_visible;
        for(const auto &pair:routes.pairs) if(pair.region==r) {
            ++pairs;CHECK(pair.count>0 && pair.length>0);
            CHECK(pair.from==region.nodes[pair.source_field] && pair.to==region.nodes[pair.target_field]);
            auto paths=dag(graph,routes,pair);
            for(auto link:paths) {
                CHECK(data.distances[pair.source_field*n+link[1]]==data.distances[pair.source_field*n+link[0]]+1);
                if(link[0]>link[1]) std::swap(link[0],link[1]);expected_visible.insert(link);
            }
            // Independent path count on the extracted DAG, with saturation.
            std::vector<int64_t> counts(n);counts[data.node_cells[pair.source_field]]=1;
            constexpr int64_t cap=std::numeric_limits<int64_t>::max();
            for(int depth=0;depth<pair.length;++depth) for(auto edge:paths) if(data.distances[pair.source_field*n+edge[0]]==depth)
                counts[edge[1]]=counts[edge[1]]>cap-counts[edge[0]] ? cap : counts[edge[1]]+counts[edge[0]];
            CHECK(counts[data.node_cells[pair.target_field]]==pair.count);
        }
        CHECK(pairs==p*(p-1)/2);
        std::set<std::array<int,2>> visible;
        for(int e:data.visible_links) visible.insert(data.links[e]);
        CHECK(visible==expected_visible);
    }
}
// Exhaustively enumerate tiny physical graphs. Compare all minimum paths,
// not just a single BFS tree or an implementation-shaped distance assertion.
static void brute_rectangle(int w,int h) {
    auto graph=rectangle(w,h,{0,0},{w-1,h-1});auto routes=road::build_portal_routes(graph);verify(graph,routes);
    CHECK(routes.pairs.size()==1);const auto &pair=routes.pairs[0];
    const auto &region=graph.regions[0];int n=w*h,best=n+1;int64_t count=0;
    std::vector<int> walk{0};std::vector<bool> seen(n);seen[0]=true;
    std::set<std::array<int,2>> edges;
    auto dfs=[&](auto &&self,int a)->void {
        if(a==n-1) {
            int length=int(walk.size())-1;
            if(length<best) {best=length;count=0;edges.clear();}
            if(length==best) {++count;for(size_t i=1;i<walk.size();++i) edges.insert({walk[i-1],walk[i]});}
            return;
        }
        for(int b=0;b<n;++b) if(!seen[b] && std::abs(a%w-b%w)+std::abs(a/w-b/w)==1) {
            seen[b]=true;walk.push_back(b);self(self,b);walk.pop_back();seen[b]=false;
        }
    };
    dfs(dfs,0);
    auto actual=dag(graph,routes,pair);std::set<std::array<int,2>> physical;
    for(auto e:actual) physical.insert({region.cells[e[0]],region.cells[e[1]]});
    CHECK(best==pair.length && count==pair.count && edges==physical);
}
int main() {
    try {
        brute_rectangle(2,2);brute_rectangle(3,2);brute_rectangle(3,3);
        auto graph=rectangle(11,11,{0,0},{10,10});auto routes=road::build_portal_routes(graph);verify(graph,routes);
        CHECK(routes.pairs[0].length==20 && routes.pairs[0].count==184756 && !routes.pairs[0].count_capped);
        graph=rectangle(50,50,{0,0},{49,49});routes=road::build_portal_routes(graph);verify(graph,routes);
        CHECK(routes.pairs[0].length==98 && routes.pairs[0].count_capped && routes.pairs[0].count==std::numeric_limits<int64_t>::max());
        // Three mouths: every pair, including all ten equal 5-step walks.
        std::vector<road::Tile> tiles;
        for(int y=0;y<3;++y) for(int x=0;x<5;++x) tiles.push_back({x,y,15});
        for(Point p:std::vector<Point>{{-1,0},{5,0},{1,3}}) tiles.push_back({p.first,p.second,15});
        graph=road::build_portal_graph(tiles,{-1,0},{5,0});routes=road::build_portal_routes(graph);verify(graph,routes);
        CHECK(routes.pairs.size()==3);
        std::set<std::pair<int,int64_t>> counts;for(auto pair:routes.pairs) counts.insert({pair.length,pair.count});
        CHECK((counts==std::set<std::pair<int,int64_t>>{{3,3},{4,1},{5,10}}));
        // Fully connected board with many independent mouths (no enumeration).
        tiles.clear();for(int y=0;y<50;++y) for(int x=0;x<50;++x) tiles.push_back({x,y,15});
        for(int x=0;x<50;x+=2) {tiles.push_back({x,-1,15});tiles.push_back({x,50,15});}
        graph=road::build_portal_graph(tiles,{0,-1},{48,50});routes=road::build_portal_routes(graph);
        CHECK(graph.regions.size()==1 && graph.regions[0].nodes.size()==50 && routes.pairs.size()==1225);
        CHECK(routes.regions[0].distances.size()==125000);
        // Narrow mazes have no local room paths to construct.
        tiles.clear();for(int y=0;y<17;++y) for(int x=0;x<17;++x) if(x%2==0 || y%2==0) tiles.push_back({x,y,15});
        graph=road::build_portal_graph(tiles,{0,0},{16,16});routes=road::build_portal_routes(graph);CHECK(routes.pairs.empty());
        CHECK(road::build_portal_routes(road::PortalGraph{}).pairs.empty());
        road::PortalGraph invalid;invalid.valid=false;CHECK(road::build_portal_routes(invalid).regions.empty());
        // Obstacle boundaries remain region-local, reciprocal and on faces.
        tiles.clear();for(int y=0;y<11;++y) for(int x=0;x<11;++x) if(x<4 || x>6 || y<3 || y>7) tiles.push_back({x,y,15});
        graph=road::build_portal_graph(tiles,{0,5},{10,5});routes=road::build_portal_routes(graph);verify(graph,routes);
        CHECK(graph.regions.size()==4);
        for(int r=0;r<int(graph.regions.size());++r) for(auto link:routes.regions[r].links) {
            int a=graph.regions[r].cells[link[0]],b=graph.regions[r].cells[link[1]];
            CHECK(std::abs(graph.cells[a].x-graph.cells[b].x)+std::abs(graph.cells[a].y-graph.cells[b].y)==1);
            bool on_face=false;
            for(auto q:graph.quads) if(q.region==r) {
                auto c=graph.cells[q.cell];auto inside=[&](int v){return graph.cells[v].x>=c.x && graph.cells[v].x<=c.x+1 && graph.cells[v].y>=c.y && graph.cells[v].y<=c.y+1;};
                on_face=on_face || (inside(a) && inside(b));
            }
            CHECK(on_face);
        }
        std::cout<<"PASS: every tied shortest path vs exhaustive 2x2/3x2/3x3 enumeration; all three portal pairs; region boundaries; 184756 paths; 64-bit count saturation without path loss; 50-mouth 50x50 compression; thin maze\n";
        for(int width:{11,50}) {
            graph=rectangle(width,width,{0,0},{width-1,width-1});std::vector<double> times;
            for(int i=0;i<21;++i) {auto before=std::chrono::steady_clock::now();routes=road::build_portal_routes(graph);if(i) times.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-before).count());}
            std::sort(times.begin(),times.end());
            size_t bytes=0;for(const auto &r:routes.regions) bytes+=r.distances.size()*sizeof(int)+r.links.size()*sizeof(std::array<int,2>)+r.node_cells.size()*sizeof(int)+r.visible_links.size()*sizeof(int);
            bytes+=routes.pairs.size()*sizeof(road::LocalRoute);
            std::cout<<"filled"<<width<<" routing_ms="<<times[10]<<" encoded_bytes="<<bytes<<" count="<<routes.pairs[0].count<<" capped="<<routes.pairs[0].count_capped<<"\n";
        }
    } catch(const std::exception &e) {std::cerr<<e.what()<<"\n";return 1;}
}
