class_name TrafficStructure
extends Node3D
var definition: TrafficStructureDefinition
var grid_cell := Vector2i.ZERO
var rotation_steps := 0
var remaining_waves := 0
var effect: Dictionary = {}

func _ready() -> void:
	remaining_waves = definition.duration_waves
	# Snapshot this placement; previews never instantiate a live structure.
	effect = definition.effect_at(grid_cell, rotation_steps)
	var visual := definition.model.instantiate()
	visual.name = "Visual"
	add_child(visual)
