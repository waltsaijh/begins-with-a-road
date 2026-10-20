#include "../../native/src/diverse_routes_core.hpp"
#include <iostream>
#include <set>
#include <string>
#include <stdexcept>
#define CHECK(x) do {if(!(x)) throw std::runtime_error("line "+std::to_string(__LINE__)+": "+#x);} while(false)
using Paths=std::set<std::vector<int>>;
static void verify(const std::vector<double> &costs) {
    std::vector<road::Tile> tiles;for(int y=0;y<3;++y) for(int x=0;x<3;++x) tiles.push_back({x,y,15});
    auto g=road::build_portal_graph(tiles,{0,1},{2,1});auto local=road::build_portal_routes(g,costs);auto choices=road::build_route_choices(g,local,costs);
    double best=1e100;Paths expected;std::vector<bool> seen(9,false);std::vector<int> walk{3};
    auto brute=[&](auto &&self,int a,double score)->void {
        if(a==5) {if(score<best && !road::cost_equal(score,best)) {best=score;expected.clear();}if(road::cost_equal(score,best)) expected.insert(walk);return;}
        seen[a]=true;
        for(int b=0;b<9;++b) if(!seen[b] && std::abs(a%3-b%3)+std::abs(a/3-b/3)==1) {walk.push_back(b);self(self,b,score+costs[b]);walk.pop_back();}
        seen[a]=false;
    };brute(brute,3,0);
    auto plan=road::build_diverse_routes(choices,choices.start,choices.goal);CHECK(plan.valid && plan.reachable && road::cost_equal(plan.score,best));
    CHECK(local.pairs.size()==1 && local.pairs[0].count==int64_t(expected.size()) && road::cost_equal(local.pairs[0].score,best));
    Paths actual;const auto &edge=choices.edges[0];CHECK(edge.from==choices.start && edge.to==choices.goal);
    auto decode=[&](auto &&self,int a)->void {
        if(a==5) {actual.insert(walk);return;}
        for(auto link:edge.dag) if(link[0]==a) {walk.push_back(link[1]);self(self,link[1]);walk.pop_back();}
    };decode(decode,3);CHECK(actual==expected);
    auto backward=road::build_diverse_routes(choices,choices.goal,choices.start);CHECK(road::cost_equal(backward.score,best+costs[3]-costs[5]));
}
int main() {
    try {
        for(int mask=0;mask<512;++mask) {std::vector<double> costs(9);for(int a=0;a<9;++a) costs[a]=(mask&(1<<a)) ? 4.0 : 1.0;verify(costs);}
        std::vector<double> costs(9,1);costs[4]=100;verify(costs);costs[4]=3;verify(costs); // tied 2-step and 4-step paths
        costs[3]=7;costs[5]=2;verify(costs); // asymmetric entry costs
        for(double &c:costs) c*=0.1;verify(costs); // roundoff-tolerant ties
        std::cout<<"PASS: 512 weighted 3x3 maps vs exhaustive physical paths; longer cheap detours; all tied paths with different step counts; reverse costs and decimal ties\n";
    } catch(const std::exception &e) {std::cerr<<e.what()<<"\n";return 1;}
}
