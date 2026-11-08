#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
namespace godot {
class RoadReducedRoutes : public RefCounted {
    GDCLASS(RoadReducedRoutes, RefCounted);
protected:
    static void _bind_methods();
public:
    Dictionary plan(const PackedInt32Array &cells, const PackedByteArray &ports,
                    Vector2i start, Vector2i goal, const PackedFloat64Array &tile_scores, bool use_min);
};
}
