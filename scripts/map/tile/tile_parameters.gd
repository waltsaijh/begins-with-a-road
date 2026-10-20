extends Resource
## One record per physical road tile; no extra Node per tile.
var cell := Vector2i.ZERO
var terrain_id := 0:
	set(value):
		if terrain_id != value:
			terrain_id = value
			emit_changed()
var movement_multiplier := 1.0:
	set(value):
		if movement_multiplier != value:
			movement_multiplier = value
			emit_changed()
var damage_per_second := 0.0:
	set(value):
		if damage_per_second != value:
			damage_per_second = value
			emit_changed()
var cover := 0.0:
	set(value):
		if cover != value:
			cover = value
			emit_changed()
## Derived from towers: the eight surrounding cells exclude this tile itself.
var num_towers_around := 0:
	set(value):
		if num_towers_around != value:
			num_towers_around = value
			emit_changed()
## Sum of threat from every tower whose circular range covers this tile.
var threat := 0.0:
	set(value):
		if threat != value:
			threat = value
			emit_changed()
var _parameters := {}

func set_parameter(key: StringName, value: Variant) -> void:
	if not _parameters.has(key) or _parameters[key] != value:
		_parameters[key] = value
		emit_changed()

func get_parameter(key: StringName, fallback: Variant = null) -> Variant:
	return _parameters.get(key, fallback)
