#include "portal_graph.hpp"
#include "route_planner.hpp"
#include "road_edit_guard.hpp"
#include "special_routes.hpp"
#include <godot_cpp/godot.hpp>
using namespace godot;
void initialize_road_graph(ModuleInitializationLevel level) {
    if(level==MODULE_INITIALIZATION_LEVEL_SCENE) {GDREGISTER_CLASS(RoadPortalGraph);GDREGISTER_CLASS(RoadRoutePlanner);GDREGISTER_CLASS(RoadEditGuard);GDREGISTER_CLASS(RoadSpecialRoutes);}
}
void uninitialize_road_graph(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT road_graph_init(GDExtensionInterfaceGetProcAddress get_proc_address,
                                         GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address,library,initialization);
    init.register_initializer(initialize_road_graph);
    init.register_terminator(uninitialize_road_graph);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
