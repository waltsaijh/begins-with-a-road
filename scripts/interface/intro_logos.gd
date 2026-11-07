extends Control
## Startup logos, shared by Boot and the transition that continues it.
const ROW_LIFT := 40.0

## A hidden copy misses the web canvas' first resize and would show at size zero,
## held on screen for seconds while the menu loads. Call this when revealing it.
func refresh() -> void:
	size = get_parent_area_size()
	$Row.size = $Row.get_combined_minimum_size()
	$Row.position = (size-$Row.size)*0.5-Vector2(0.0, ROW_LIFT)
