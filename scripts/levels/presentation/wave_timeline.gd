@tool
class_name WaveTimeline
extends Control
## A fixed five-event window scrolls beneath a stationary current marker.
const NODE_RADIUS := 4.0
const NODE_OUTLINE_WIDTH := 1.5
const EXPANSION_ICON = preload("res://assets/sprites/interface/spawn_expansion.svg")
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
var _act_labels: Array[Label] = []
var reward_active := false
var expansion_active := false
var _header_managed := false
var _header_width_limit := 360.0
const VISIBLE_EVENTS := 5
const PAST_EVENTS := 1
@export_range(180, 480, 1) var fixed_width := 360.0
var event_cursor := 0.0
var marker_pulse := 0.0
var _event_motion: Tween
var _pulse_motion: Tween

func events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level == null: return result
	var rewards := reward_indices()
	var expansions := expansion_indices()
	for i in level.wave_count():
		result.append({"kind":"wave", "wave":i})
		if i in rewards: result.append({"kind":"relic", "wave":i})
		if i in expansions: result.append({"kind":"entrance", "wave":i})
	return result

func event_index(kind: String, index: int) -> int:
	var schedule := events()
	for i in schedule.size():
		if schedule[i].kind == kind and schedule[i].wave == index: return i
	return -1

func event_position(kind: String, index: int) -> Vector2:
	return Vector2(size.x/VISIBLE_EVENTS*(0.5+PAST_EVENTS+event_index(kind,index)-event_cursor),43)

## ACT boundaries fall between events; rewards and entrances belong to the ACT
## whose final wave produced them, so the divider follows those events.
func act_boundaries() -> PackedInt32Array:
	var result := PackedInt32Array()
	if level == null: return result
	var wave := 0
	for act in level.acts:
		if act == null: continue
		result.append(event_index("wave",wave))
		wave += act.waves.size()
	return result

func event_caption(event: Dictionary) -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	match event.kind:
		"relic": return GameText.text("text.wave_timeline.1",{},english)
		"entrance": return GameText.text("text.wave_timeline.2",{},english)
	return (GameText.text("text.wave_timeline.3",{},english)) % (event.wave+1)

func _set_cursor(value: float) -> void:
	event_cursor = value
	_refresh()

func _pulse(value: float) -> void:
	marker_pulse = value
	_refresh()

func _animate_event(target: int) -> void:
	if target < 0: return
	if _event_motion != null: _event_motion.kill()
	_event_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_event_motion.tween_method(_set_cursor,event_cursor,float(target),0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if _pulse_motion != null: _pulse_motion.kill()
	_pulse_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_pulse_motion.tween_method(_pulse,0.0,0.16,0.14)
	_pulse_motion.tween_method(_pulse,0.16,0.0,0.21)

func _apply_width() -> void:
	if Engine.is_editor_hint() or not is_node_ready(): return
	if _header_managed:
		size.x = fixed_width
	else:
		var width := fixed_width
		offset_left = -width*0.5
		offset_right = width*0.5
	_refresh()

func manage_header_width(_limit: float) -> void:
	var next := fixed_width
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
	# Inspector previews use the same window and cursor as live play.
	if Engine.is_editor_hint() and level != null and level.wave_count() > 0:
		size.x = fixed_width
		var target := event_index("wave",mini(wave_index,level.wave_count()-1))
		event_cursor = float(target) if running else lerpf(float(maxi(0,target-1)),float(target),progress)
		marker_pulse = sin(progress*PI)*0.16 if not running else 0.0
	_refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	$Track.refresh(self)
	$Progress.hide()
	_refresh_labels()
	tooltip_text = _summary()

func set_reward_active(value: bool) -> void:
	if reward_active == value: return
	reward_active = value
	if value: _animate_event(event_index("relic",wave_index))
	_refresh()

func reward_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	if level == null: return result
	for i in level.wave_count():
		if is_act_end(i) and (i+1 < level.wave_count() or level.reward_final_act): result.append(i)
	return result

func expansion_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	if level != null:
		for i in level.wave_count():
			if level.expands_after(i+1): result.append(i)
	return result

func _slot_count() -> int:
	return level.wave_count()+reward_indices().size()+expansion_indices().size()

func _events_through(index: int) -> int:
	var count := 0
	for i in reward_indices():
		if i <= index: count += 1
	for i in expansion_indices():
		if i <= index: count += 1
	return count

func reward_fraction(index: int) -> float:
	return node_fraction(index)+1.0/_slot_count()

func expansion_fraction(index: int) -> float:
	return node_fraction(index)+(2.0 if index in reward_indices() else 1.0)/_slot_count()

func set_expansion_active(value: bool) -> void:
	if expansion_active == value: return
	expansion_active = value
	if value: _animate_event(event_index("entrance",wave_index-1))
	_refresh()

func _previous_fraction() -> float:
	if wave_index <= 0: return 0.0
	return float(wave_index+_events_through(wave_index-1))/_slot_count()

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
	var text := "ACT %d / %d · %s %d / %d" % [act.index+1,level.acts.size(),GameText.text("text.wave_timeline.4",{},english),index+1,level.wave_count()]
	if expansion_active: return GameText.text("text.wave_timeline.5",{},english)
	if reward_active: text = "ACT %d / %d · %s" % [act.index+1,level.acts.size(),GameText.text("text.wave_timeline.6",{},english)]
	return text

func milestone_tooltip(index: int, reward: bool) -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	var act := _act_for(index)
	if reward:
		return (GameText.text("text.wave_timeline.7",{},english)) % act.act.title
	var wave: WaveDefinition = act.act.waves[act.local]
	var population := 0
	for group in wave.groups: population += group.enemy_count
	var complete := index < wave_index or reward_active and index == wave_index
	var status := (GameText.text("text.wave_timeline.8",{},english)) if complete else ((GameText.text("text.wave_timeline.9",{},english)) if index == wave_index and running else (GameText.text("text.wave_timeline.10",{},english)))
	return (GameText.text("text.wave_timeline.11",{},english)) % [act.act.title,act.local+1,index+1,level.wave_count(),status,population,wave.reward]

func _get_tooltip(at_position: Vector2) -> String:
	if level == null or level.wave_count() == 0: return ""
	var schedule := events()
	for i in schedule.size():
		var event := schedule[i]
		var point := event_position(event.kind,event.wave)
		if point.x < 0 or point.x > size.x: continue
		if absf(at_position.x-point.x) > 14 or at_position.y < 13 or at_position.y > 56: continue
		if event.kind == "entrance":
			return (GameText.text("text.wave_timeline.global_1")) % (event.wave+1)
		return milestone_tooltip(event.wave,event.kind == "relic")
	return _summary()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh()

func configure(value: LevelDefinition) -> void:
	if _event_motion != null: _event_motion.kill()
	event_cursor = 0.0
	level = value

func set_state(index: int, fraction: float, active: bool) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	if index == wave_index and is_equal_approx(fraction, progress) and active == running: return
	var preparing_next := index != wave_index and is_zero_approx(fraction) and not active
	if index != wave_index:
		reward_active = false
		expansion_active = false
	wave_index = index
	progress = fraction
	running = active
	if preparing_next:
		_refresh()
		return
	if _event_motion != null: _event_motion.kill()
	var target := event_index("wave",mini(index,level.wave_count()-1))
	var previous := maxi(0,target-1)
	event_cursor = float(target) if active or index >= level.wave_count() else lerpf(float(previous),float(target),fraction)
	marker_pulse = sin(fraction*PI)*0.16 if not active else 0.0
	_refresh()

func node_fraction(index: int) -> float:
	return float(index+1+_events_through(index-1))/_slot_count()

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

## Legacy logical progress queries remain independent of the scrolling view.
func fill_cutoff() -> float:
	if level == null or level.wave_count() == 0: return 0.0
	if wave_index >= level.wave_count(): return _marker_right_edge(level.wave_count()-1)
	if reward_active: return size.x*reward_fraction(wave_index)+9.0
	if expansion_active: return size.x*expansion_fraction(wave_index-1)+9.0
	var target := _marker_right_edge(wave_index)
	var previous := size.x*_previous_fraction()+9.0 if wave_index > 0 and _events_through(wave_index-1) > _events_through(wave_index-2) else _marker_right_edge(wave_index-1)
	return target if running else lerpf(previous, target, progress)

func position_fraction() -> float:
	if level == null or level.wave_count() == 0: return 0.0
	if wave_index >= level.wave_count(): return 1.0
	if reward_active: return reward_fraction(wave_index)
	if expansion_active: return expansion_fraction(wave_index-1)
	var target := node_fraction(wave_index)
	return target if running else lerpf(_previous_fraction(), target, progress)

func _refresh_labels() -> void:
	if _act_labels.is_empty():
		var label := act_label_scene.instantiate() as Label
		$Acts.add_child(label)
		_act_labels.append(label)
	var label := _act_labels[0]
	label.visible = level != null and level.wave_count() > 0
	if not label.visible: return
	var schedule := events()
	var current := clampi(int(floor(event_cursor+0.001)),0,schedule.size()-1)
	var act := _act_for(schedule[current].wave)
	label.text = act.act.title
	label.position.x = 0
	label.size.x = size.x
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",label_color)
	var font := current_act_font if current_act_font != null else act_font
	if font != null: label.add_theme_font_override("font",font)
