#include "../../native/src/diverse_routes_core.hpp"
#include <cassert>
#include <functional>
#include <iostream>
using namespace road;
static void edge(RouteChoices &g,int a,int b,double cost=1) {
    int road=int(g.edges.size());RouteChoice e;e.from=a;e.to=b;e.length=1;e.cost=cost;e.corridor=road;
    g.edges.push_back(e);if(g.directed) {std::swap(e.from,e.to);g.edges.push_back(e);}
}
static double brute(const RouteChoices &g,int s,int t) {
    double best=INFINITY;std::vector<bool> visited(g.vertices,false);
    std::function<void(int,double)> dfs=[&](int v,double cost) {
        if(v==t) {best=std::min(best,cost);return;}visited[v]=true;
        for(const auto &e:g.edges) if(e.from==v || (!g.directed && e.to==v)) {
            int to=e.from==v ? e.to : e.from;if(!visited[to]) dfs(to,cost+e.cost);
        }visited[v]=false;
    };dfs(s,0);return best;
}
static void verify(const RouteChoices &g,const DiversePlan &p,double threshold) {
    assert(p.valid && p.attempts<=64);double best=brute(g,p.start,p.goal);
    assert(p.reachable==std::isfinite(best));if(!p.reachable) return;assert(cost_equal(best,p.score));
    std::set<std::vector<int>> all;
    for(const auto &r:p.routes) {
        assert(all.insert(r.edges).second);assert(r.nodes.front()==p.start && r.nodes.back()==p.goal);
        assert(std::set<int>(r.nodes.begin(),r.nodes.end()).size()==r.nodes.size());assert(r.nodes.size()==r.edges.size()+1);
        double score=0;for(size_t i=0;i<r.edges.size();++i) {const auto &e=g.edges[r.edges[i]];
            assert((e.from==r.nodes[i] && e.to==r.nodes[i+1]) || (!g.directed && e.to==r.nodes[i] && e.from==r.nodes[i+1]));score+=e.cost;}
        assert(cost_equal(score,r.score) && r.score-p.score<threshold);
    }
    if(threshold>0) assert(!p.routes.empty() && cost_equal(p.routes[0].score,best));else assert(p.routes.empty());
}
int main() {
    RouteChoices shared;shared.vertices=6;shared.directed=true;
    edge(shared,0,1);edge(shared,1,2);edge(shared,2,4);edge(shared,1,3);edge(shared,3,4);edge(shared,4,5);
    auto p=build_diverse_routes(shared,0,5);verify(shared,p,10);assert(p.routes.size()==2);
    // Both directions and non-monotone vertex IDs are usable; a fake rank
    // 0<1<2<3 would lose the cheaper 0 -> 2 -> 1 -> 3 route.
    RouteChoices back;back.vertices=4;back.directed=true;
    edge(back,0,2);edge(back,2,1);edge(back,1,3);edge(back,0,3,5);
    p=build_diverse_routes(back,0,3,2);verify(back,p,2);assert(p.score==3 && p.routes.size()==1);
    assert((p.routes.front().nodes==std::vector<int>{0,2,1,3}));
    p=build_diverse_routes(back,0,3,INFINITY);verify(back,p,INFINITY);assert(p.routes.size()==2);
    p=build_diverse_routes(back,0,3,0);verify(back,p,0);
    assert(build_diverse_routes(back,0,3,10,0).routes.size()==1);
    assert(!build_diverse_routes(back,0,3,10,-1).valid);
    assert(!build_diverse_routes(back,0,3,10,1,257).valid);
    assert(!build_diverse_routes(back,99,3).valid);
    assert(!build_diverse_routes(back,0,3,NAN).valid);
    // Two symmetric loops: ordinary overlap penalties keep alternating the
    // upper and lower routes, never using the central connector (edge 8/9).
    RouteChoices ladder;ladder.vertices=4;ladder.directed=true;
    edge(ladder,0,1,5);edge(ladder,1,3,5);edge(ladder,0,2,9);edge(ladder,2,3,9);edge(ladder,1,2,4);
    for(auto &choice:ladder.edges) choice.length=int(choice.cost);
    p=build_diverse_routes(ladder,0,3,INFINITY);verify(ladder,p,INFINITY);
    assert(p.stop==std::string("waypoint_completion") && p.waypoint_added==2 && p.routes.size()==4);
    assert(p.attempts==10 && p.waypoint_searches==2 && p.waypoint_attempts==2);
    assert(build_diverse_routes(ladder,0,3,INFINITY,1,9).waypoint_attempts==0);
    p=build_diverse_routes(ladder,0,3,8);verify(ladder,p,8);assert(p.waypoint_added==0);
    // A spur cannot belong to a simple start-goal route: joining shortest
    // legs through it would revisit its attachment vertex and must fail.
    edge(ladder,1,4);ladder.vertices=5;
    p=build_diverse_routes(ladder,0,3,INFINITY);verify(ladder,p,INFINITY);
    for(const auto &route:p.routes) assert(std::find(route.nodes.begin(),route.nodes.end(),4)==route.nodes.end());
    // The two independently shortest legs overlap at node 1. Both locking
    // orders have a legal detour; the repaired path must keep its waypoint.
    RouteChoices overlap;overlap.vertices=7;overlap.directed=true;
    edge(overlap,0,1);edge(overlap,1,2);edge(overlap,2,3);edge(overlap,3,1);edge(overlap,1,5);
    edge(overlap,3,4,2);edge(overlap,4,5,2);edge(overlap,0,6,2);edge(overlap,6,2,2);
    waypoint_detail::Adjacency forward(7),reverse(7);
    for(int id=0;id<int(overlap.edges.size());++id) {const auto &e=overlap.edges[id];forward[e.from].push_back({id,e.to});reverse[e.to].push_back({id,e.from});}
    std::vector<bool> blocked(7,false);int searches=0,expanded=0;
    auto head=waypoint_detail::shortest(overlap,forward,0,blocked,-1,searches,expanded);
    auto tail=waypoint_detail::shortest(overlap,reverse,5,blocked,-1,searches,expanded);
    auto repaired=waypoint_detail::through(overlap,forward,reverse,head,tail,0,5,4,2,3,searches,expanded);
    assert(repaired.score==7 && std::find(repaired.edges.begin(),repaired.edges.end(),4)!=repaired.edges.end());
    assert(std::set<int>(repaired.nodes.begin(),repaired.nodes.end()).size()==repaired.nodes.size());
    int checked=0;
    // Exhaustive topologies; compare original optimum against a simple-path
    // oracle, not another Dijkstra implementation. Asymmetric entry costs.
    for(int mask=0;mask<1024;++mask) {
        RouteChoices g;g.vertices=5;g.directed=true;int bit=0;
        for(int a=0;a<5;++a) for(int b=a+1;b<5;++b,++bit) if(mask&(1<<bit)) {
            edge(g,a,b,1+(a+b)%3);g.edges.back().cost+=0.25;
        }
        for(int s=0;s<5;++s) for(int t=0;t<5;++t) {
            p=build_diverse_routes(g,s,t,4);verify(g,p,4);++checked;
        }
    }
    std::cout<<"PASS: "<<checked<<" exhaustive endpoint cases, original-graph optimum, shared bridges, waypoint completion, dead-end rejection, eight-stale trigger, positive asymmetric costs, simple routes, exclusive threshold, bounds and no duplicates\n";
}
