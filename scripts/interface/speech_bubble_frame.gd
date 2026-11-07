@tool
extends Node2D
## Shared clipped corners and centered pointer for world-anchored UI.
@export var frame_size := Vector2(144,88):
	set(value):
		frame_size = value
		_update_geometry()
@export var tail_height := 8.0:
	set(value):
		tail_height = value
		_update_geometry()

func _ready() -> void:
	_update_geometry()

func _update_geometry() -> void:
	if not is_node_ready(): return
	var w := frame_size.x
	var bottom := frame_size.y-tail_height
	var outline := PackedVector2Array([Vector2(4,0),Vector2(w-4,0),Vector2(w,4),Vector2(w,bottom-4),Vector2(w-4,bottom),Vector2(w*0.5+5,bottom),Vector2(w*0.5,frame_size.y),Vector2(w*0.5-5,bottom),Vector2(4,bottom),Vector2(0,bottom-4),Vector2(0,4),Vector2(4,0)])
	$Background.polygon = outline
	$Border.points = outline
