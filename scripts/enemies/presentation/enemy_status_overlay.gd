extends Control
## Batch rendering reads the editable Appearance scene, without per-enemy UI trees.
@export var icon_gap := 2.0
var renderer: MultiMeshInstance3D
@onready var appearance: Control = $Appearance
@onready var _frame: StyleBox = $Appearance/Background.get_theme_stylebox("panel")
@onready var _icon_frame: StyleBox = $Appearance/Icon/Background.get_theme_stylebox("panel")

func _ready() -> void:
	process_priority = 110
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	appearance.hide()

func _process(_delta: float) -> void:
	# Reproject frozen world anchors when the camera moves during pause.
	queue_redraw()

static func health_fills(enemy: Node3D) -> Vector2:
	var capacity: float = maxf(0.0, enemy.max_health)+maxf(0.0, enemy.max_shield)
	if capacity <= 0.0:
		return Vector2.ZERO
	return Vector2(clampf(enemy.health, 0.0, enemy.max_health), clampf(enemy.shield, 0.0, enemy.max_shield))/capacity

func _draw() -> void:
	if renderer == null or not renderer.is_visible_in_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewport := get_viewport_rect().grow(64)
	var bar_size := appearance.size
	var skill: ColorRect = appearance.get_node("Skill")
	var icon_view: Control = appearance.get_node("Icon")
	var health_color: Color = appearance.get_node("Health").color
	var shield_color: Color = appearance.get_node("Shield").color
	for i in renderer.units.size():
		var enemy: Node3D = renderer.units[i]
		if not enemy.can_be_targeted():
			continue
		var head: Vector3 = renderer.head_positions[i]
		if camera.is_position_behind(head):
			continue
		var center := camera.unproject_position(head)
		if not viewport.has_point(center):
			continue
		var origin := (center-bar_size*Vector2(0.5, 1)).round()
		var fills := health_fills(enemy)
		draw_style_box(_frame, Rect2(origin, bar_size))
		var size := bar_size
		size.x *= fills.x
		draw_rect(Rect2(origin, size), health_color)
		var shield_origin := origin+Vector2(size.x, 0)
		size.x = bar_size.x*fills.y
		if size.x > 0:
			draw_rect(Rect2(shield_origin, size), shield_color)
		if is_finite(enemy.skill_progress) and enemy.skill_progress >= 0:
			var skill_origin := origin+skill.position
			var skill_size := skill.size
			draw_style_box(_frame, Rect2(skill_origin, skill_size))
			skill_size.x *= clampf(enemy.skill_progress, 0, 1)
			draw_rect(Rect2(skill_origin, skill_size), skill.color)
		var count: int = enemy.effect_icons.size()
		var width: float = count*icon_view.size.x+maxi(0, count-1)*icon_gap
		var icon_origin := Vector2(roundf(center.x-width*0.5), origin.y+icon_view.position.y)
		for id: StringName in enemy.effect_icons:
			var icon: Texture2D = enemy.effect_icons[id]
			draw_style_box(_icon_frame, Rect2(icon_origin, icon_view.size))
			draw_texture_rect(icon, Rect2(icon_origin, icon_view.size), false)
			icon_origin.x += icon_view.size.x+icon_gap
