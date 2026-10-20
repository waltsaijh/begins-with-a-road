#include "../../native/src/portal_graph_core.hpp"
#include <chrono>
#include <iostream>
#include <random>
#include <set>
#include <stdexcept>
#include <string>
#define CHECK(x) do {if(!(x)) throw std::runtime_error("line "+std::to_string(__LINE__)+": "+#x);} while(false)
using Point=std::pair<int,int>;
static std::vector<road::Tile> tiles(const std::set<Point> &mask) {
    std::vector<road::Tile> result;for(auto p:mask) result.push_back({p.first,p.second,15});return result;
}
static std::set<Point> grid(int w,int h,bool maze=false) {
    std::set<Point> mask;for(int y=0;y<h;++y) for(int x=0;x<w;++x) if(!maze || x%2==0 || y%2==0) mask.insert({x,y});return mask;
}
static int holes(const std::set<Point> &mask) {
    if(mask.empty()) return 0;
    int x0=0,x1=0,y0=0,y1=0;for(auto p:mask) {x0=std::min(x0,p.first);x1=std::max(x1,p.first);y0=std::min(y0,p.second);y1=std::max(y1,p.second);}--x0;++x1;--y0;++y1;
    std::set<Point> seen;int count=0;
    for(int x=x0;x<=x1;++x) for(int y=y0;y<=y1;++y) if(!mask.count({x,y}) && !seen.count({x,y})) {
        std::vector<Point> queue{{x,y}};seen.insert({x,y});bool outside=false;
        for(size_t i=0;i<queue.size();++i) {
            auto p=queue[i];outside=outside || p.first==x0 || p.first==x1 || p.second==y0 || p.second==y1;
            for(int dx=-1;dx<=1;++dx) for(int dy=-1;dy<=1;++dy) {
                Point q{p.first+dx,p.second+dy};
                if(q.first<x0 || q.first>x1 || q.second<y0 || q.second>y1 || mask.count(q) || !seen.insert(q).second) continue;queue.push_back(q);
            }
        }
        if(!outside) ++count;
    }
    return count;
}
static void verify(const road::PortalGraph &g) {
    if(!g.valid) std::cerr<<"error="<<g.error<<" tiles="<<g.cells.size()<<" regions="<<g.regions.size()<<" nodes="<<g.nodes.size()<<" cycles="<<g.cycles<<" logical="<<g.logical_cycles<<"\n";
    CHECK(g.valid);CHECK(g.logical_cycles==g.cycles);
    auto point=[&](int a){return Point{g.cells[a].x,g.cells[a].y};};
    for(const auto &edge:g.corridors) {
        CHECK(edge.from!=edge.to);CHECK(edge.cells.size()>=2);
        CHECK(edge.cells.front()==g.nodes[edge.from].cell);CHECK(edge.cells.back()==g.nodes[edge.to].cell);
        std::set<int> visited;
        for(size_t i=0;i<edge.cells.size();++i) {
            CHECK(visited.insert(edge.cells[i]).second);
            if(i) {
                auto a=point(edge.cells[i-1]),b=point(edge.cells[i]);CHECK(std::abs(a.first-b.first)+std::abs(a.second-b.second)==1);
                int d=b.first>a.first ? 1 : b.first<a.first ? 3 : b.second>a.second ? 2 : 0;
                CHECK(g.cells[edge.cells[i-1]].ports&(1<<d));CHECK(g.cells[edge.cells[i]].ports&(1<<((d+2)%4)));
            }
        }
    }
    for(int r=0;r<int(g.regions.size());++r) {
        const auto &region=g.regions[r];std::set<int> unique(region.cells.begin(),region.cells.end());CHECK(unique.size()==region.cells.size());
        for(int node:region.nodes) {
            CHECK(g.nodes[node].component==region.component);
            CHECK(std::find(g.nodes[node].regions.begin(),g.nodes[node].regions.end(),r)!=g.nodes[node].regions.end());
            CHECK(unique.count(g.nodes[node].cell));
        }
    }
}
static road::PortalGraph build(const std::set<Point> &mask,Point s,Point t) {auto g=road::build_portal_graph(tiles(mask),s,t);verify(g);return g;}
static int routes(const road::PortalGraph &g) {
    int n=int(g.nodes.size()),total=n+int(g.regions.size());
    std::vector<std::vector<int>> links(total);
    auto add=[&](int a,int b){links[a].push_back(b);links[b].push_back(a);};
    for(const auto &e:g.corridors) add(e.from,e.to);
    for(int r=0;r<int(g.regions.size());++r) for(int node:g.regions[r].nodes) add(node,n+r);
    std::vector<bool> seen(total,false);int count=0;
    auto dfs=[&](auto &&self,int a)->void {
        if(a==g.goal_node) {++count;return;}seen[a]=true;
        for(int b:links[a]) if(!seen[b]) self(self,b);seen[a]=false;
    };
    dfs(dfs,g.start_node);return count;
}
int main(int argc,char**) {
    try {
        auto room=grid(11,11);for(int x=-3;x<0;++x) room.insert({x,5});for(int x=11;x<14;++x) room.insert({x,5});
        auto g=build(room,{-3,5},{13,5});CHECK(g.regions.size()==1 && g.nodes.size()==4 && g.corridors.size()==2 && g.cycles==0);CHECK(routes(g)==1);
        for(const auto &node:g.nodes) if(std::string(node.kind)=="portal") CHECK(g.cells[node.cell].x==0 || g.cells[node.cell].x==10);
        auto holed=room;for(int x=4;x<7;++x) for(int y=3;y<8;++y) holed.erase({x,y});
        g=build(holed,{-3,5},{13,5});CHECK(g.cycles==1 && g.regions.size()==4 && routes(g)==2);
        auto annotated=grid(5,3);
        for(int x=-3;x<12;++x) annotated.insert({x,0});
        for(int y=2;y<=5;++y) annotated.insert({1,y});
        for(int x=1;x<=8;++x) annotated.insert({x,5});
        for(int y=0;y<=5;++y) annotated.insert({8,y});
        g=build(annotated,{-3,0},{11,0});CHECK(g.regions.size()==1 && g.nodes.size()==6 && g.corridors.size()==4 && routes(g)==2);
        int junctions=0;for(const auto &node:g.nodes) if(std::string(node.kind)=="junction") {++junctions;CHECK(g.cells[node.cell].x==8 && g.cells[node.cell].y==0);}CHECK(junctions==1);
        // Broad T/step shapes with no hole merge into one region.
        auto irregular=grid(8,4);for(int x=2;x<6;++x) for(int y=4;y<9;++y) irregular.insert({x,y});
        g=build(irregular,{0,0},{5,8});CHECK(g.regions.size()==1 && g.cycles==0 && g.nodes.size()==2);
        g=build(grid(2,2),{0,0},{1,1});CHECK(g.regions.size()==1 && g.nodes.size()==2 && routes(g)==1);
        // Adjacent broad squares touching at a single cell keep their gate.
        auto touching=grid(2,2);for(int x=1;x<3;++x) for(int y=1;y<3;++y) touching.insert({x,y});
        g=build(touching,{0,0},{2,2});CHECK(g.regions.size()==2 && g.cycles==0 && routes(g)==1);
        // Both endpoints on different cells of a shared window remain distinct.
        g=build(holed,{3,0},{3,1});CHECK(g.start_node!=g.goal_node);
        g=build({{0,0},{1,0},{2,0},{1,1},{1,2}},{0,0},{2,0});CHECK(g.regions.empty() && g.nodes.size()==4 && g.corridors.size()==3);
        g=road::build_portal_graph(tiles({{0,0},{1,0},{2,0},{3,0}}),{0,0},{3,0},{{1,0}});
        verify(g);CHECK(g.nodes.size()==3 && g.corridors.size()==2);
        g=road::build_portal_graph(tiles(grid(5,5)),{0,0},{4,4},{{2,2}});
        verify(g);CHECK(g.regions.size()==1 && g.nodes.size()==3 && g.regions[0].nodes.size()==3);
        auto thin_ring=grid(5,5);for(int x=1;x<4;++x) for(int y=1;y<4;++y) thin_ring.erase({x,y});
        g=build(thin_ring,{99,99},{99,99});CHECK(g.regions.empty() && g.cycles==1 && g.nodes.size()==2 && g.corridors.size()==2);
        g=build({{0,0},{2,2}},{0,0},{2,2});CHECK(g.components==2);
        CHECK(build({}, {0,0},{1,1}).nodes.empty());
        g=build(grid(17,17,true),{0,0},{16,16});CHECK(g.regions.empty() && g.cycles==64 && g.nodes.size()==79 && g.corridors.size()==142);
        g=build(grid(50,50),{0,25},{49,25});CHECK(g.regions.size()==1 && g.nodes.size()==2 && g.corridors.empty());
        auto teeth=grid(20,20);for(int x=0;x<20;x+=2) teeth.insert({x,-1});
        g=build(teeth,{0,-1},{18,-1});CHECK(g.regions.size()==1 && g.regions[0].nodes.size()==10 && g.nodes.size()==20 && g.corridors.size()==10);
        std::mt19937 random(70913);
        for(int trial=0;trial<3000;++trial) {
            auto mask=grid(9,9);for(auto it=mask.begin();it!=mask.end();) if(random()%4==0) it=mask.erase(it);else ++it;
            g=build(mask,{0,0},{8,8});CHECK(g.cycles==holes(mask));
        }
        auto partial=tiles(grid(2,2));partial[0].ports=0;g=road::build_portal_graph(partial,{0,0},{1,1});verify(g);CHECK(g.faces==0 && g.components==2);
        CHECK(!road::build_portal_graph({{0,0,15},{0,0,15}},{0,0},{1,1}).valid);
        CHECK(build({{-30000,0},{30000,0}},{-30000,0},{30000,0}).components==2);
        std::cout<<"PASS: portal positions, annotated branch/obstacle scene, broad-area merging, internal obstacles, thin maze, rings, window endpoints, ports, islands, 50x50 and 3000 random maps vs independent obstacle flood-fill\n";
        if(argc>1) for(auto entry:std::vector<std::pair<const char*,std::set<Point>>>{{"filled11",room},{"maze9_junctions",grid(17,17,true)},{"filled50",grid(50,50)}}) {
            std::string name=entry.first;
            Point s=name=="filled11" ? Point{-3,5} : name=="filled50" ? Point{0,25} : Point{0,0};
            Point t=name=="filled11" ? Point{13,5} : name=="filled50" ? Point{49,25} : Point{16,16};
            std::vector<double> times;
            for(int i=0;i<21;++i) {auto before=std::chrono::steady_clock::now();g=road::build_portal_graph(tiles(entry.second),s,t);if(i) times.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-before).count());}
            std::sort(times.begin(),times.end());std::cout<<entry.first<<" median_ms="<<times[times.size()/2]<<" nodes="<<g.nodes.size()<<" regions="<<g.regions.size()<<" corridors="<<g.corridors.size()<<" cycles="<<g.cycles<<"\n";
        }
    } catch(const std::exception &error) {std::cerr<<error.what()<<"\n";return 1;}
}
