@tool
class_name WaveTimeline
extends Control
## Every marker ends one preparation interval; ACT-ending waves use a divider.
const NODE_RADIUS := 4.0
const NODE_OUTLINE_WIDTH := 1.5
const DIVIDER_WIDTH := 2.0
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	return target if running else lerpf(float(wave_index)/level.wave_count(), target, progress)

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
