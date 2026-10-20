#pragma once
#include "diverse_routes_core.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <string>
class RoadRoutePlanner : public godot::RefCounted {
    GDCLASS(RoadRoutePlanner,godot::RefCounted)
    struct CachedPlan {
        road::DiversePlan plan;road::RouteChoices choices;road::PortalRoutes local;
        std::vector<double> weights;godot::Dictionary summary,debug_graph;
        double threshold=10,penalty=1;int budget=64;
        uint64_t local_us=0,choices_us=0,search_us=0;
    };
    road::PortalGraph physical;road::PortalRoutes geometry;
    std::unordered_map<std::string,CachedPlan> profiles;
    uint64_t prepare_us=0;const char *input_error="not_prepared";
protected:
    static void _bind_methods();
public:
    godot::Dictionary prepare(const godot::Dictionary &graph);
    godot::Dictionary find_paths(const godot::String &profile="default",const godot::PackedFloat64Array &costs={},int64_t start=-1,int64_t goal=-1,double score_threshold=10,double overlap_penalty=1,int64_t search_budget=64);
    godot::Dictionary sample_route(const godot::String &profile="default",int64_t seed=0,int64_t route_index=-1) const;
    godot::Dictionary get_region_paths(const godot::String &profile="default") const;
    godot::Dictionary get_debug_graph(const godot::String &profile="default");
    void invalidate(const godot::String &profile="");
};
