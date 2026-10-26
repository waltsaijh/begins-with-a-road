#include "../../native/src/candidate_walk_core.hpp"
#include <cassert>
#include <iostream>
int main() {
    std::vector<int> nodes={0,-1,-1,2,-1,1,-1,-1},positions(8,-1);
    road::CandidateWalk result;
    assert(road::normalize_candidate_walk({0,1,5,6,2,1,2,3},nodes,positions,result));
    assert((result.cells==std::vector<int>{0,1,2,3}));
    assert((result.nodes==std::vector<int>{0,2}));
    assert((result.ranges==std::vector<std::array<int,2>>{{0,3}}));
    assert(result.erased_steps==4);
    assert(road::normalize_candidate_walk({0,4,5,1,0,4,5,1,2,3},nodes,positions,result));
    assert((result.cells==std::vector<int>{0,4,5,1,2,3}));
    assert(!road::normalize_candidate_walk({0,1,99},nodes,positions,result));
    for(int position:positions) assert(position==-1);
    assert(road::normalize_candidate_walk({0},nodes,positions,result) && result.ranges.empty());
    assert(!road::normalize_candidate_walk({},nodes,positions,result));
    assert(!road::normalize_candidate_walk({1,2},nodes,positions,result));
    for(int position:positions) assert(position==-1);
    std::cout<<"CANDIDATE_WALK_CHECK: passed\n";
}
