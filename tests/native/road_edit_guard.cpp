#include "../../native/src/road_edit_guard_core.hpp"
#include <cassert>
#include <functional>
#include <iostream>
#include <set>
using namespace road;
static std::vector<Tile> tiles(const std::set<std::pair<int,int>> &cells) {
    std::vector<Tile> result;for(auto cell:cells) result.push_back({cell.first,cell.second,15});return result;
}
static bool on_path(const std::set<std::pair<int,int>> &cells,std::pair<int,int> target) {
    const std::pair<int,int> start{0,1},goal{2,1};std::set<std::pair<int,int>> visited;
    std::function<bool(std::pair<int,int>,bool)> dfs=[&](auto at,bool contains) {
        contains=contains || at==target;if(at==goal) return contains;
        visited.insert(at);
        for(auto delta:std::vector<std::pair<int,int>>{{0,-1},{1,0},{0,1},{-1,0}}) {
            std::pair<int,int> next{at.first+delta.first,at.second+delta.second};
            if(cells.count(next) && !visited.count(next) && dfs(next,contains)) return true;
        }
        visited.erase(at);return false;
    };return dfs(start,false);
}
int main() {
    int checked=0;
    for(int mask=0;mask<512;++mask) {
        std::set<std::pair<int,int>> cells{{0,1},{2,1}};
        for(int y=0;y<3;++y) for(int x=0;x<3;++x) if(mask&(1<<(y*3+x))) cells.insert({x,y});
        for(int y=0;y<3;++y) for(int x=0;x<3;++x) if(!cells.count({x,y})) {
            RoadEditGuardCore guard;assert(guard.prepare(tiles(cells),{{2,1},{0,1}}));
            auto added=cells;added.insert({x,y});
            assert(guard.add_cell(x,y)==on_path(added,{x,y}));++checked;
        }
        RoadEditGuardCore guard;assert(guard.prepare(tiles(cells),{{2,1},{0,1}}));
        // Several skipped additions must accumulate and eventually reconnect.
        for(int y=0;y<3;++y) for(int x=0;x<3;++x) if(!cells.count({x,y})) {
            cells.insert({x,y});bool changed=guard.add_cell(x,y);
            assert(changed==on_path(cells,{x,y}));++checked;
            if(changed) assert(guard.prepare(tiles(cells),{{2,1},{0,1}}));
        }
    }
    // A cycle attached at one articulation is still a dead branch.
    std::set<std::pair<int,int>> spur;
    for(int x=0;x<=8;++x) spur.insert({x,0});
    spur.insert({4,1});spur.insert({4,2});spur.insert({5,2});spur.insert({5,3});spur.insert({4,3});
    RoadEditGuardCore guard;assert(guard.prepare(tiles(spur),{{0,0},{8,0}}));
    assert(!guard.add_cell(4,1));
    assert(!guard.add_cell(6,3));assert(!guard.add_cell(6,2)); // Close a loop inside the spur.
    assert(guard.add_cell(6,1)); // Connect the spur back to a different route cell.
    std::set<std::pair<int,int>> dense;
    for(int y=0;y<50;++y) for(int x=0;x<50;++x) dense.insert({x,y});
    assert(guard.prepare(tiles(dense),{{0,25},{49,25}}) && guard.route_tiles==2500);
    for(int x=50;x<1050;++x) assert(!guard.add_cell(x,25));
    std::cout<<"PASS: "<<checked<<" edits checked against exhaustive simple-path oracle, accumulated additions and spur cycles\n";
}
