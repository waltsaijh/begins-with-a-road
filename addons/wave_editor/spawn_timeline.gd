@tool
extends Control
signal group_selected(index: int)
signal group_moved(index: int, start_tick: int)
const LABEL_WIDTH := 150.0
const HEADER_HEIGHT := 30.0
const ROW_HEIGHT := 54.0
var wave: WaveDefinition
var selected_index := 0
var preview_tick := 0
var _drag_index := -1
var _drag_x := 0.0
var _drag_start := 0
var _drag_tick := 0
var _drag_scale := 1.0

func configure(value: WaveDefinition, selection: int, tick: int) -> void:
	wave = value
	selected_index = selection
	preview_tick = tick
	update_minimum_size()
	queue_redraw()

func axis_ticks() -> int:
	return maxi(120, ceili(wave.last_spawn_tick()/24.0)*24) if wave != null else 120

func _get_minimum_size() -> Vector2:
	return Vector2(500, HEADER_HEIGHT+ROW_HEIGHT*(wave.groups.size() if wave != null else 1))

func _bar(index: int) -> Rect2:
	var group := wave.groups[index]
	if group == null: return Rect2()
	var start := _drag_tick if index == _drag_index else group.start_tick
	var duration := group.end_tick()-group.start_tick
	var span := maxf(1.0, size.x-LABEL_WIDTH-10)
	var x := LABEL_WIDTH+span*start/axis_ticks()
	var width := maxf(18.0, span*duration/axis_ticks())
	return Rect2(minf(x, size.x-width-5), HEADER_HEIGHT+index*ROW_HEIGHT+8, width, 32)

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text := get_theme_color("font_color", "Label")
	var muted := Color(text, 0.65)
	var accent := get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color("218f9b")
	var span := maxf(1.0, size.x-LABEL_WIDTH-10)
	draw_string(font, Vector2(5, 20), "秒 · 1 格 = 0.25 秒", HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH-10, font_size-1, muted)
	for i in 7:
		var x := LABEL_WIDTH+span*i/6.0
		var label := ("%.2f" % (axis_ticks()*WaveSpawnGroup.TICK_SECONDS*i/6.0)).trim_suffix(".00")
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(clampf(x-label_width*0.5, LABEL_WIDTH, size.x-label_width), 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, size.y), Color(text, 0.12), 1.0)
	if wave == null: return
	for i in wave.groups.size():
		var group := wave.groups[i]
		if group == null: continue
		var y := HEADER_HEIGHT+i*ROW_HEIGHT
		var title := "%d · %s × %d" % [i+1, group.troop.troop_name if group.troop != null else "未設定", group.enemy_count]
		var label_left := 5.0
		if group.troop != null and group.troop.icon != null:
			draw_texture_rect(group.troop.icon, Rect2(5, y+4, 18, 18), false)
			label_left = 27.0
		draw_string(font, Vector2(label_left, y+20), title, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH-label_left-5, font_size, text)
		var start := _drag_tick if i == _drag_index else group.start_tick
		var finish := group.end_tick()+start-group.start_tick
		draw_string(font, Vector2(5, y+39), "%.2f–%.2f 秒 · 入口 %d" % [start*0.25, finish*0.25, group.start_index+1], HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH-10, font_size-2, muted)
		var rect := _bar(i)
		var color := group.troop.debug_color if group.troop != null else accent
		draw_style_box(_style(color, i == selected_index), rect)
		var count := str(group.enemy_count)
		var text_width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if text_width+8 < rect.size.x:
			draw_string(font, Vector2(rect.get_center().x-text_width*0.5, rect.position.y+21), count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text)
		if group.batch_size > 0:
			var batches := ceili(float(group.enemy_count)/group.batch_size)
			for k in mini(batches, 48):
				var tick := start+k*group.interval_ticks
				var tx := LABEL_WIDTH+span*tick/axis_ticks()
				draw_line(Vector2(tx, rect.end.y-5), Vector2(tx, rect.end.y), Color(text, 0.55), 1.0)
	var cursor := LABEL_WIDTH+span*preview_tick/axis_ticks()
	draw_line(Vector2(cursor, HEADER_HEIGHT), Vector2(cursor, size.y), accent, 1.5)

func _style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.55 if selected else 0.2)
	style.set_corner_radius_all(4)
	return style

func _gui_input(event: InputEvent) -> void:
	if wave == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var index := floori((event.position.y-HEADER_HEIGHT)/ROW_HEIGHT)
			if index < 0 or index >= wave.groups.size() or wave.groups[index] == null: return
			if _bar(index).has_point(event.position):
				_drag_index = index
				_drag_x = event.position.x
				_drag_start = wave.groups[index].start_tick
				_drag_tick = _drag_start
				_drag_scale = axis_ticks()/maxf(1.0, size.x-LABEL_WIDTH-10)
			group_selected.emit(index)
			accept_event()
		elif _drag_index >= 0:
			var index := _drag_index
			var tick := _drag_tick
			_drag_index = -1
			group_moved.emit(index, tick)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag_index >= 0:
		_drag_tick = maxi(0, _drag_start+roundi((event.position.x-_drag_x)*_drag_scale))
		queue_redraw()
		accept_event()
