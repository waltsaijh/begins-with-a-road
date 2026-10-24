extends Control
@export var increase_color := Color("617958")
@export var decrease_color := Color("a46a50")
@export_range(4.0, 20.0, 1.0) var arrow_size := 8.0
@export_group("Floating Motion")
@export_range(0.0, 12.0, 0.5) var float_distance := 5.0
@export_range(0.5, 5.0, 0.1) var float_period := 2.0
var _float_started_usec := 0
var _float_elapsed := 0.0
var markers := {}
var map: GridMap
var hint := ""
var hint_point := Vector3.ZERO
var _hint: Label

func _ready() -> void:
	_float_started_usec = Time.get_ticks_usec()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font",preload("res://assets/fonts/NotoSansTC-Light.ttf"))
	_hint.add_theme_font_size_override("font_size",14)
	_hint.add_theme_color_override("font_color",Color("524d3e"))
	add_child(_hint)

func _process(_delta: float) -> void:
	_float_elapsed = (Time.get_ticks_usec()-_float_started_usec)/1000000.0
	queue_redraw()
	var camera := get_viewport().get_camera_3d()
	_hint.visible = visible and not hint.is_empty() and camera != null and not camera.is_position_behind(hint_point)
	if _hint.visible:
		_hint.text = hint
		_hint.position = camera.unproject_position(hint_point)+Vector2(12,-30)

func _draw() -> void:
	if map == null: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for edge: Vector4i in markers:
		var a := map.map_to_local(Vector3i(edge.x,0,edge.y))
		var b := map.map_to_local(Vector3i(edge.z,0,edge.w))
		var world := map.to_global(a.lerp(b,0.65)+Vector3.UP*0.18)
		if camera.is_position_behind(world): continue
		var center := camera.unproject_position(world)
		var direction: int = -int(markers[edge])
		var phase := fposmod(_float_elapsed/maxf(0.01,float_period),1.0)
		# Drift in the sign's direction; fade at the loop seam so it never jumps back.
		center.y += direction*float_distance*phase
		var color := increase_color if direction < 0 else decrease_color
		if float_distance > 0.0:
			color.a *= smoothstep(0.0,0.16,phase)*(1.0-smoothstep(0.80,1.0,phase))
		var tip := center+Vector2(0,direction*arrow_size)
		draw_line(center-Vector2(0,direction*arrow_size*0.7),tip,color,2.0,true)
		draw_polyline(PackedVector2Array([tip+Vector2(-arrow_size*0.5,-direction*arrow_size*0.5),tip,tip+Vector2(arrow_size*0.5,-direction*arrow_size*0.5)]),color,2.0,true)
