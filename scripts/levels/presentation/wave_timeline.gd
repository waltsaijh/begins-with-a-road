@tool
class_name WaveTimeline
extends Control
## Every marker represents one wave; ACT-ending waves use a divider.
const NODE_RADIUS := 4.0
const NODE_OUTLINE_WIDTH := 1.5
const DIVIDER_WIDTH := 2.0
const RELIC_ICON = preload("res://assets/sprites/interface/relic_choice.svg")
@export var act_label_scene: PackedScene = preload("res://scenes/levels/components/wave_timeline_act.tscn")
@export var level: LevelDefinition:
	set(value):
		level = value
		_refresh()
@export_group("Preview")
@export_range(0, 100, 1) var wave_index := 0
@export_range(0.0, 1.0, 0.01) var progress := 0.0
@export var running := false
@export_group("Appearance")
@export var act_font: Font
@export var current_act_font: Font
@export_range(8, 48, 1) var font_size := 16
@export var label_color := Color("244c52")
@export var muted_color := Color("6b8588")
@export var progress_color := Color("218f9b")
var _act_signature: Array = []
var _act_labels: Array[Label] = []
var expanded := false
var _pinned := false
var _hovered := false
var _motion: Tween
var reward_active := false
var _reward_icons: Array[Sprite2D] = []
var _header_managed := false
var _header_width_limit := 640.0
var expansion := 0.0:
	set(value):
		expansion = value
		if is_node_ready() and not Engine.is_editor_hint():
			var full_width := _header_width_limit if _header_managed else minf(640.0,maxf(180.0,get_viewport_rect().size.x-40.0))
			var width := lerpf(minf(300.0,full_width),full_width,value)
			if _header_managed:
				size.x = width
			else:
				offset_left = -width*0.5
				offset_right = width*0.5
			_refresh()

func manage_header_width(limit: float) -> void:
	var next := clampf(limit,180.0,640.0)
	if _header_managed and is_equal_approx(next,_header_width_limit): return
	_header_managed = true
	_header_width_limit = next
	expansion = expansion

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if not Engine.is_editor_hint():
		anchor_left = 0.5
		anchor_right = 0.5
		expansion = 0.0
		mouse_entered.connect(func(): _hovered = true; set_expanded(true))
		mouse_exited.connect(func(): _hovered = false; set_expanded(_pinned))
		get_viewport().size_changed.connect(func(): expansion = expansion)
	resized.connect(_refresh)
	set_process(Engine.is_editor_hint())
	_refresh()

func _process(_delta: float) -> void:
	# Redraw editor previews when nested ACT/wave resources change in Inspector.
	_refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	$Track.refresh(self)
	$Progress/Fill.refresh(self)
	$Progress.size = Vector2(fill_cutoff(), size.y)
	$Progress.visible = position_fraction() > 0.0
	_refresh_labels()
	_refresh_rewards()
	tooltip_text = _summary()
	var amount := 1.0 if Engine.is_editor_hint() else expansion
	for child in [$Track,$Progress,$Acts]:
		child.modulate.a = amount
		if child != $Progress: child.visible = amount > 0.001
	$Progress.visible = amount > 0.001 and position_fraction() > 0.0
	queue_redraw()

func set_reward_active(value: bool) -> void:
	if reward_active == value: return
	reward_active = value
	_refresh()

func reward_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	if level == null: return result
	for i in level.wave_count():
		if is_act_end(i) and (i+1 < level.wave_count() or level.reward_final_act): result.append(i)
	return result

func reward_fraction(index: int) -> float:
	return node_fraction(index)+0.5/(level.wave_count()+(0.5 if level.reward_final_act else 0.0))

func _refresh_rewards() -> void:
	var indices := reward_indices()
	while _reward_icons.size() > indices.size(): _reward_icons.pop_back().free()
	while _reward_icons.size() < indices.size():
		var icon := Sprite2D.new()
		icon.texture = RELIC_ICON
		$Rewards.add_child(icon)
		_reward_icons.append(icon)
	for i in indices.size():
		var active := reward_active and indices[i] == wave_index
		_reward_icons[i].position = Vector2(size.x*reward_fraction(indices[i]),43)
		_reward_icons[i].scale = Vector2.ONE*(0.95 if active else 0.75)
		_reward_icons[i].modulate.a = (1.0 if active or indices[i] < wave_index else 0.7)*(1.0 if Engine.is_editor_hint() else expansion)

func set_expanded(value: bool) -> void:
	expanded = value
	if _motion != null: _motion.kill()
	_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion.tween_property(self,"expansion",1.0 if value else 0.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pinned = not _pinned
		set_expanded(_pinned)
		accept_event()

func _draw() -> void:
	if Engine.is_editor_hint() or level == null or level.wave_count() == 0 or expansion >= 0.999: return
	var font := get_theme_default_font()
	var color := Color(label_color,1.0-expansion)
	var muted := Color(muted_color,1.0-expansion)
	var text := _summary().get_slice("\n",0)
	draw_string(font,Vector2(4,20),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	var entries := compact_entries()
	for i in entries.size():
		var point := compact_point(i,entries.size())
		if i+1 < entries.size(): draw_line(point,compact_point(i+1,entries.size()),Color(muted,0.35*(1.0-expansion)),1)
		if entries[i].reward:
			draw_texture_rect(RELIC_ICON,Rect2(point-Vector2(7,7),Vector2(14,14)),false,Color(1,1,1,1.0-expansion))
		else:
			var complete: bool = entries[i].index < wave_index or (running and entries[i].index == wave_index)
			if not complete: draw_circle(point,4,Color(0.953,0.973,0.969,1.0-expansion))
			draw_circle(point,4,color if complete else muted,complete,-1.0 if complete else 1.5,true)
			draw_string(font,point+Vector2(10,5),str(entries[i].index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	draw_string(font,Vector2(size.x-24,43),"−" if _pinned else "+",HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)

func compact_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level == null or level.wave_count() == 0: return result
	var current := mini(wave_index,level.wave_count()-1)
	var rewards := reward_indices()
	if reward_active:
		result.append({"index":current,"reward":true})
		current += 1
	for index in range(current,mini(current+3,level.wave_count())):
		result.append({"index":index,"reward":false})
		if rewards.has(index): result.append({"index":index,"reward":true})
	return result

func compact_point(index: int, count: int) -> Vector2:
	return Vector2(16.0+index*minf(72.0,(size.x-64.0)/maxi(1,count-1)),43)

func _act_for(index: int) -> Dictionary:
	var first := 0
	for i in level.acts.size():
		var act: ActDefinition = level.acts[i]
		if index < first+act.waves.size(): return {"index":i,"local":index-first,"act":act}
		first += act.waves.size()
	return {}

func _summary() -> String:
	if level == null or level.wave_count() == 0: return ""
	var index := mini(wave_index,level.wave_count()-1)
	var act := _act_for(index)
	var english := TranslationServer.get_locale().begins_with("en")
	var text := "ACT %d / %d · %s %d / %d" % [act.index+1,level.acts.size(),"Wave" if english else "波次",index+1,level.wave_count()]
	if reward_active: text = "ACT %d / %d · %s" % [act.index+1,level.acts.size(),"Choose a relic" if english else "選擇遺物"]
	return text+("\nHover to expand · click to pin or collapse." if english else "\n移入展開全局時間線；點擊固定展開或收合。")

func milestone_tooltip(index: int, reward: bool) -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	var act := _act_for(index)
	if reward:
		return ("Choose a relic\nAfter %s · choose one of three relics." if english else "遺物選擇\n完成 %s 後，從三件遺物選擇一件。") % act.act.title
	var wave: WaveDefinition = act.act.waves[act.local]
	var population := 0
	for group in wave.groups: population += group.enemy_count
	var complete := index < wave_index or reward_active and index == wave_index
	var status := ("Completed" if english else "已完成") if complete else (("In battle" if english else "戰鬥中") if index == wave_index and running else ("Upcoming" if english else "即將進行"))
	return ("%s · Wave %d (%d / %d)\n%s · %d enemies · reward %d gold" if english else "%s · 第 %d 波（全局 %d / %d）\n%s · %d 名敵軍 · 完成獎勵 %d 金幣") % [act.act.title,act.local+1,index+1,level.wave_count(),status,population,wave.reward]

func _get_tooltip(at_position: Vector2) -> String:
	if level == null or level.wave_count() == 0: return ""
	if expansion >= 0.5:
		for index in reward_indices():
			if at_position.distance_to(Vector2(size.x*reward_fraction(index),43)) <= 10: return milestone_tooltip(index,true)
		for index in level.wave_count():
			if at_position.distance_to(Vector2(size.x*node_fraction(index),43)) <= 12: return milestone_tooltip(index,false)
	else:
		var entries := compact_entries()
		for i in entries.size():
			if at_position.distance_to(compact_point(i,entries.size())) <= 14: return milestone_tooltip(entries[i].index,entries[i].reward)
	return _summary()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh()

func configure(value: LevelDefinition) -> void:
	level = value

func set_state(index: int, fraction: float, active: bool) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	if index == wave_index and is_equal_approx(fraction, progress) and active == running: return
	wave_index = index
	progress = fraction
	running = active
	_refresh()

func node_fraction(index: int) -> float:
	return float(index+1)/(level.wave_count()+(0.5 if level.reward_final_act else 0.0))

func is_act_end(index: int) -> bool:
	if level == null: return false
	var last := -1
	for act in level.acts:
		if act == null: continue
		last += act.waves.size()
		if index == last: return true
	return false

func _marker_right_edge(index: int) -> float:
	if index < 0: return 0.0
	var track := get_node_or_null("Track")
	var half_width: float = track.marker_extent(index) if track != null else NODE_RADIUS+NODE_OUTLINE_WIDTH*0.5
	# Include the antialiased edge so the whole marker is filled on wave start.
	return maxf(1.0, size.x)*node_fraction(index)+half_width+1.0

func fill_cutoff() -> float:
	if level == null or level.wave_count() == 0: return 0.0
	if wave_index >= level.wave_count(): return _marker_right_edge(level.wave_count()-1)
	var target := _marker_right_edge(wave_index)
	return target if running else lerpf(_marker_right_edge(wave_index-1), target, progress)

func position_fraction() -> float:
	if level == null or level.wave_count() == 0: return 0.0
	if wave_index >= level.wave_count(): return 1.0
	var target := node_fraction(wave_index)
	return target if running else lerpf(node_fraction(wave_index-1), target, progress)

func _refresh_labels() -> void:
	var titles: Array[String] = []
	var lengths: Array[int] = []
	if level != null:
		for act in level.acts:
			if act != null:
				titles.append(act.title)
				lengths.append(act.waves.size())
	var signature := [titles, lengths, size, wave_index, font_size, act_font, current_act_font, label_color, muted_color, act_label_scene]
	if signature == _act_signature: return
	_act_signature = signature
	while _act_labels.size() > titles.size(): _act_labels.pop_back().free()
	while _act_labels.size() < titles.size():
		var label := act_label_scene.instantiate() as Label
		$Acts.add_child(label)
		_act_labels.append(label)
	if level == null or level.wave_count() == 0: return
	var count := level.wave_count()
	var first := 0
	var font := act_font if act_font != null else get_theme_default_font()
	for i in titles.size():
		var last := first+lengths[i]
		var current := mini(wave_index, count-1) >= first and mini(wave_index, count-1) < last
		var act_left := float(first)/count
		var act_right := float(last)/count
		var label_font: Font = current_act_font if current and current_act_font != null else font
		var label := _act_labels[i]
		label.text = titles[i]
		label.position.x = size.x*act_left
		label.size.x = size.x*(act_right-act_left)
		label.add_theme_font_override("font", label_font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", label_color if current else muted_color)
		first = last
