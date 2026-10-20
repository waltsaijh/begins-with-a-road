#include "road_edit_guard.hpp"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
void RoadEditGuard::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare","cells","ports","terminals"),&RoadEditGuard::prepare);
    ClassDB::bind_method(D_METHOD("add_cell","cell"),&RoadEditGuard::add_cell);
}
Dictionary RoadEditGuard::prepare(const PackedInt32Array &cells,const PackedByteArray &ports,const PackedVector2Array &terminals) {
    Dictionary result;result["valid"]=false;
    if(cells.size()!=ports.size()*2 || terminals.is_empty()) return result;
    std::vector<road::Tile> input;input.reserve(ports.size());
    for(int i=0;i<ports.size();++i) input.push_back({cells[i*2],cells[i*2+1],ports[i]});
    std::vector<std::pair<int,int>> ends;
    for(int i=0;i<terminals.size();++i) {Vector2i cell(terminals[i]);ends.push_back({cell.x,cell.y});}
    result["valid"]=guard.prepare(input,ends);result["route_tiles"]=guard.route_tiles;return result;
}
bool RoadEditGuard::add_cell(Vector2i cell) {return guard.add_cell(cell.x,cell.y);}
