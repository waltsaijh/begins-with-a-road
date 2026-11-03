class_name MenuMapDefinition
extends Resource
## Catalog-generated view data; no separate menu Resource is required.
@export var title_key := ""
@export var description_key := ""
@export var level: LevelDefinition
@export_file("*.tscn") var level_scene := "res://scenes/level.tscn"
var id := ""
var requirements := PackedStringArray()
var missing_titles := PackedStringArray()
var problem: StringName = &""
var unlocked := false
var completed := false
