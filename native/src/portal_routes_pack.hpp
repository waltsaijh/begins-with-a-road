#pragma once
#include "portal_routes_core.hpp"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

template<class Packed,class Value> inline Packed pack_route_values(const std::vector<Value> &source) {
    Packed result;result.resize(source.size());
    if(!source.empty()) std::copy(source.begin(),source.end(),result.ptrw());return result;
}
inline void pack_region_routes(godot::Dictionary &region,const road::RegionRouteData &data) {
    godot::PackedInt32Array links,node_cells,visible;
    godot::PackedFloat64Array distances,reverse,costs;
    links.resize(data.links.size()*2);int32_t *link_data=links.ptrw();
    for(size_t i=0;i<data.links.size();++i) {link_data[i*2]=data.links[i][0];link_data[i*2+1]=data.links[i][1];}
    distances=pack_route_values<godot::PackedFloat64Array>(data.distances);
    reverse=pack_route_values<godot::PackedFloat64Array>(data.reverse_distances);
    costs=pack_route_values<godot::PackedFloat64Array>(data.cell_costs);
    node_cells=pack_route_values<godot::PackedInt32Array>(data.node_cells);
    visible=pack_route_values<godot::PackedInt32Array>(data.visible_links);
    region["route_links"]=links;region["route_distances"]=distances;region["route_reverse_distances"]=reverse;
    region["route_cell_costs"]=costs;region["route_node_cells"]=node_cells;region["route_visible_links"]=visible;
}
inline godot::Array pack_local_routes(const road::PortalRoutes &routing) {
    godot::Array result;
    result.resize(routing.pairs.size());
    const godot::Variant id="id",region="region",from="from",to="to",source="source_field",target="target_field",
        length="length",score="score",reverse="reverse_score",count="count",capped="count_capped";
    for(size_t i=0;i<routing.pairs.size();++i) {
        const auto &pair=routing.pairs[i];
        godot::Dictionary route;
        route[id]=int64_t(i);route[region]=pair.region;route[from]=pair.from;route[to]=pair.to;
        route[source]=pair.source_field;route[target]=pair.target_field;
        route[length]=pair.length;route[score]=pair.score;route[reverse]=pair.reverse_score;
        route[count]=pair.count;route[capped]=pair.count_capped;result[i]=route;
    }
    return result;
}
