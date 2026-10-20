#pragma once
#include "road_edit_guard_core.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
class RoadEditGuard : public godot::RefCounted {
    GDCLASS(RoadEditGuard,godot::RefCounted)
    road::RoadEditGuardCore guard;
protected:
    static void _bind_methods();
public:
    godot::Dictionary prepare(const godot::PackedInt32Array &cells,const godot::PackedByteArray &ports,const godot::PackedVector2Array &terminals);
    bool add_cell(godot::Vector2i cell);
};
