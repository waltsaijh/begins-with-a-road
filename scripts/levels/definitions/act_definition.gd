@tool
class_name ActDefinition
extends Resource
@export var title := "ACT I"
## After this ACT, choose one additional entrance if another ACT follows.
@export var add_start_after_completion := true
@export var waves: Array[WaveDefinition] = []

func repair_missing_defaults() -> void:
	# Live editor instances can retain Nil for newly introduced exports.
	if get("add_start_after_completion") == null: set("add_start_after_completion", true)
