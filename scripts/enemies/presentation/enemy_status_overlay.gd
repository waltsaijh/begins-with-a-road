extends Control
## Editable appearance is sampled once; ordered quads use one 2D MultiMesh.
const Batch = preload("res://scripts/enemies/presentation/enemy_status_batch.gd")
const Atlas = preload("res://scripts/enemies/presentation/enemy_status_atlas.gd")
@export var icon_gap := 2.0
var renderer: MultiMeshInstance3D
var batch: MultiMeshInstance2D
var _atlas: RefCounted
var _frames: Array[Rect2] = []
var _bounds: Array[Rect2] = []
var _flat: Array[bool] = []
var _update_queued := false
var _atlas_ready := false
var _bar_size: Vector2
var _skill_size: Vector2
var _skill_position: Vector2
var _icon_size: Vector2
var _icon_y: float
var _health_color: Color
var _shield_color: Color
var _skill_color: Color
@onready var appearance: Control = $Appearance

class FrameCanvas extends Control:
	var styles: Array[StyleBox] = []
	var rectangles: Array[Rect2] = []
	func _draw() -> void:
		for i in styles.size(): draw_style_box(styles[i], rectangles[i])

func _ready() -> void:
	process_priority = 110
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	appearance.hide()
	batch = Batch.new()
	batch.name = "StatusBatch"
	add_child(batch)
	batch.clear()
	_atlas = Atlas.new()
	batch.texture = _atlas.texture
	set_process(false)
	_prepare_appearance()

func _prepare_appearance() -> void:
	_bar_size = appearance.size
	var skill: ColorRect = appearance.get_node("Skill")
	var icon: Control = appearance.get_node("Icon")
	_skill_size = skill.size
	_skill_position = skill.position
	_icon_size = icon.size
	_icon_y = icon.position.y
	_health_color = appearance.get_node("Health").color
	_shield_color = appearance.get_node("Shield").color
	_skill_color = skill.color
	var frame: StyleBox = appearance.get_node("Background").get_theme_stylebox("panel")
	var styles: Array[StyleBox] = [frame, frame, icon.get_node("Background").get_theme_stylebox("panel")]
	var sizes: Array[Vector2] = [_bar_size, _skill_size, _icon_size]
	var canvas := FrameCanvas.new()
	canvas.styles = styles
	var extent := Vector2i.ZERO
	var backgrounds := PackedColorArray()
	var borders := PackedColorArray()
	var rectangles: Array[Vector4] = []
	var widths: Array[Vector4] = []
	for i in sizes.size():
		var bounds := Rect2(Vector2.ZERO, sizes[i])
		if styles[i] is StyleBoxFlat or styles[i] is StyleBoxTexture:
			bounds = bounds.grow_individual(styles[i].get_expand_margin(SIDE_LEFT), styles[i].get_expand_margin(SIDE_TOP), styles[i].get_expand_margin(SIDE_RIGHT), styles[i].get_expand_margin(SIDE_BOTTOM))
		if styles[i] is StyleBoxFlat and styles[i].shadow_size > 0:
			bounds = bounds.merge(Rect2(bounds.position+styles[i].shadow_offset, bounds.size).grow(styles[i].shadow_size))
		var content := bounds
		bounds = Rect2(bounds.position.floor()-Vector2.ONE, bounds.end.ceil()-bounds.position.floor()+Vector2.ONE*2)
		_bounds.append(bounds)
		var simple: bool = styles[i] is StyleBoxFlat and styles[i].shadow_size == 0 and styles[i].skew == Vector2.ZERO and not styles[i].border_blend and styles[i].corner_radius_top_left == 0 and styles[i].corner_radius_top_right == 0 and styles[i].corner_radius_bottom_left == 0 and styles[i].corner_radius_bottom_right == 0
		_flat.append(simple)
		backgrounds.append(styles[i].bg_color if simple and styles[i].draw_center else Color.TRANSPARENT)
		borders.append(styles[i].border_color if simple else Color.TRANSPARENT)
		rectangles.append(Vector4(content.position.x-bounds.position.x, content.position.y-bounds.position.y, content.end.x-bounds.position.x, content.end.y-bounds.position.y))
		widths.append(Vector4(styles[i].border_width_left, styles[i].border_width_top, styles[i].border_width_right, styles[i].border_width_bottom) if simple else Vector4.ZERO)
		canvas.rectangles.append(Rect2(Vector2(1, extent.y+1)-bounds.position, sizes[i]))
		extent.x = maxi(extent.x, ceili(bounds.size.x)+2)
		extent.y += ceili(bounds.size.y)+2
	var shader_material := batch.material as ShaderMaterial
	shader_material.set_shader_parameter("frame_backgrounds", backgrounds)
	shader_material.set_shader_parameter("frame_borders", borders)
	shader_material.set_shader_parameter("frame_rects", rectangles)
	shader_material.set_shader_parameter("frame_widths", widths)
	# Rectangular styles stay analytical, avoiding blur at fractional UI scales.
	if not false in _flat:
		canvas.free()
		_atlas.seal()
		_atlas.upload()
		_atlas_ready = true
		_process(0.0)
		return
	var picture: Image
	if DisplayServer.get_name() == "headless":
		# No pixels are inspected without a display; data-only checks stay usable.
		picture = Image.create_empty(maxi(1, extent.x), maxi(1, extent.y), false, Image.FORMAT_RGBA8)
		canvas.free()
	else:
		var viewport := SubViewport.new()
		viewport.size = extent
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		viewport.add_child(canvas)
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		picture = viewport.get_texture().get_image()
		viewport.queue_free()
		# Transparent render targets store premultiplied RGB; atlas samples use mix.
		for y in picture.get_height():
			for x in picture.get_width():
				var color := picture.get_pixel(x, y)
				if color.a > 0.0:
					picture.set_pixel(x, y, Color(color.r/color.a, color.g/color.a, color.b/color.a, color.a))
	picture.convert(Image.FORMAT_RGBA8)
	var top := 1
	for bounds in _bounds:
		_frames.append(_atlas.add_image(picture.get_region(Rect2i(Vector2i(1, top), Vector2i(bounds.size)))))
		top += int(bounds.size.y)+2
	_atlas.seal()
	_atlas.upload()
	_atlas_ready = true
	_process(0.0)

func clear() -> void:
	if batch != null: batch.clear()
	if _atlas != null: _atlas.clear_icons()

func request_update() -> void:
	if _update_queued: return
	_update_queued = true
	_flush_update.call_deferred()

func _flush_update() -> void:
	_update_queued = false
	if is_inside_tree(): _process(0.0)

static func health_fills(enemy: Node3D) -> Vector2:
	var capacity: float = maxf(0.0, enemy.max_health)+maxf(0.0, enemy.max_shield)
	if capacity <= 0.0: return Vector2.ZERO
	return Vector2(clampf(enemy.health, 0.0, enemy.max_health), clampf(enemy.shield, 0.0, enemy.max_shield))/capacity

func _process(_delta: float) -> void:
	if not _atlas_ready: return
	batch.begin()
	if renderer == null or not renderer.is_visible_in_tree():
		batch.submit()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		batch.submit()
		return
	var viewport := get_viewport_rect().grow(64)
	for i in renderer.units.size():
		var enemy: Node3D = renderer.units[i]
		if not enemy.can_be_targeted(): continue
		var head: Vector3 = renderer.head_positions[i]
		if camera.is_position_behind(head): continue
		var center := camera.unproject_position(head)
		if not viewport.has_point(center): continue
		var origin := (center-_bar_size*Vector2(0.5, 1)).round()
		var fills := health_fills(enemy)
		_frame(0, origin)
		batch.append(Rect2(origin, Vector2(_bar_size.x*fills.x, _bar_size.y)), _atlas.white, _health_color)
		batch.append(Rect2(origin+Vector2(_bar_size.x*fills.x, 0), Vector2(_bar_size.x*fills.y, _bar_size.y)), _atlas.white, _shield_color)
		if is_finite(enemy.skill_progress) and enemy.skill_progress >= 0:
			var skill_origin := origin+_skill_position
			_frame(1, skill_origin)
			batch.append(Rect2(skill_origin, Vector2(_skill_size.x*clampf(enemy.skill_progress, 0, 1), _skill_size.y)), _atlas.white, _skill_color)
		var count: int = enemy.effect_icons.size()
		var width: float = count*_icon_size.x+maxi(0, count-1)*icon_gap
		var icon_origin := Vector2(roundf(center.x-width*0.5), origin.y+_icon_y)
		for id: StringName in enemy.effect_icons:
			_frame(2, icon_origin)
			var region: Rect2 = _atlas.icon(enemy.effect_icons[id])
			batch.append(Rect2(icon_origin, _icon_size), region)
			icon_origin.x += _icon_size.x+icon_gap
	_atlas.upload()
	batch.submit()

func _frame(index: int, origin: Vector2) -> void:
	var bounds := _bounds[index]
	var region := Rect2(index, bounds.size.x, bounds.size.y, -1) if _flat[index] else _frames[index]
	batch.append(Rect2(origin+bounds.position, bounds.size), region)
