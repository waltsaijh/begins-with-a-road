extends Node
const Fixture = preload("res://tests/levels/road_flow_fixture.gd")

func _ready() -> void:
	var level: Node3D = load("res://scenes/level.tscn").instantiate()
	level.level = Fixture.level()
	add_child(level)
