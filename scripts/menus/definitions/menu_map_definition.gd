class_name MenuMapDefinition
extends Resource
## Selection metadata; the playable scene and level remain authored resources.
@export var title_key := ""
@export var description_key := ""
@export var level: LevelDefinition
@export_file("*.tscn") var level_scene := "res://scenes/level.tscn"
