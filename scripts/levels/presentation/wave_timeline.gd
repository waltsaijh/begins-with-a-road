@tool
class_name WaveTimeline
extends Control
## Every marker represents one wave; ACT-ending waves use a divider.
const NODE_RADIUS := 4.0
const NODE_OUTLINE_WIDTH := 1.5
const DIVIDER_WIDTH := 2.0
## The relic diamond sits on its divider like a pin head, above the track.
const REWARD_HEAD_Y := 30.0
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
var reward_active := false
var _reward_icons: Array[Sprite2D] = []
var _header_managed := false
var _header_width_limit := 640.0
func _apply_width() -> void:
	if Engine.is_editor_hint() or not is_node_ready(): return
	if _header_managed:
		size.x = _header_width_limit
	else:
		var width := minf(640.0,maxf(180.0,get_viewport_rect().size.x-40.0))
		offset_left = -width*0.5
		offset_right = width*0.5
	_refresh()

func manage_header_width(limit: float) -> void:
	var next := clampf(limit,180.0,640.0)
	if _header_managed and is_equal_approx(next,_header_width_limit): return
	_header_managed = true
	_header_width_limit = next
	_apply_width()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not Engine.is_editor_hint():
		anchor_left = 0.5
		anchor_right = 0.5
		_apply_width()
		get_viewport().size_changed.connect(_apply_width)
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

## The relic choice sits on the divider of the ACT it follows.
func reward_fraction(index: int) -> float:
	return node_fraction(index)

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
		_reward_icons[i].position = Vector2(size.x*reward_fraction(indices[i]),REWARD_HEAD_Y)
		_reward_icons[i].scale = Vector2.ONE*(0.95 if active else 0.75)

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
	return text

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
	for index in reward_indices():
		# The whole pin answers, from its head down to the end of the divider.
		if absf(at_position.x-size.x*reward_fraction(index)) <= 10 and at_position.y >= REWARD_HEAD_Y-10 and at_position.y <= 53: return milestone_tooltip(index,true)
	for index in level.wave_count():
		if at_position.distance_to(Vector2(size.x*node_fraction(index),43)) <= 12: return milestone_tooltip(index,false)
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
	return float(index+1)/level.wave_count()

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
		# Only the ACT being played is named; the others are read from the dividers.
		label.visible = current
		first = last
