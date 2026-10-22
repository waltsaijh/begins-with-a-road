@tool
class_name RelicCatalog
extends Resource
@export var entries: Array[RelicDefinition] = []
@export var weak_base_weight := 1.0
@export var weak_count_weight := 0.25
@export var random_seed := 73183

func find(id: StringName) -> RelicDefinition:
	for relic in entries:
		if relic != null and relic.id == id: return relic
	return null
