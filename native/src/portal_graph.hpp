#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

class RoadPortalGraph : public godot::RefCounted {
    GDCLASS(RoadPortalGraph,godot::RefCounted)
protected:
    static void _bind_methods();
public:
    godot::Dictionary build(const godot::PackedInt32Array &cells,const godot::PackedByteArray &ports,
                           godot::Vector2i start,godot::Vector2i goal,bool include_routes=true,
                           const godot::PackedVector2Array &extra_terminals=godot::PackedVector2Array()) const;
};
