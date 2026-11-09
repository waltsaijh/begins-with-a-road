@tool
extends Control
## Recycle six markers: five resting slots and one clipped incoming marker.
@export var filled := false
@export var marker_scene: PackedScene = preload("res://scenes/levels/components/wave_timeline_marker.tscn")
var _markers: Array[Node2D] = []
var _current: Node2D
var _act_dividers: Array[Line2D] = []
func refresh(timeline: WaveTimeline) -> void:
	if not is_node_ready() or filled: return
	if anchor_left == anchor_right and anchor_top == anchor_bottom: size = timeline.size
	clip_contents = true
	var line: Line2D = $Line
	line.set_point_position(1,Vector2(size.x,43))
	line.default_color = Color(timeline.muted_color,0.4)
	$StartDivider.hide()
	var schedule := timeline.events()
	while _markers.size() < WaveTimeline.VISIBLE_EVENTS+1:
		var marker := marker_scene.instantiate() as Node2D
		var icon := Sprite2D.new()
		icon.name = "EventIcon"
		icon.position.y = 0
		icon.z_index = 2
		icon.scale = Vector2.ONE*0.75
		marker.add_child(icon)
		var caption := Label.new()
		caption.name = "Caption"
		caption.position = Vector2(-36,12)
		caption.size = Vector2(72,18)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size",12)
		marker.add_child(caption)
		$Markers.add_child(marker)
		_markers.append(marker)
	var first := int(floor(timeline.event_cursor))-WaveTimeline.PAST_EVENTS
	for slot in _markers.size():
		var marker := _markers[slot]
		var index := first+slot
		marker.visible = index >= 0 and index < schedule.size()
		if not marker.visible: continue
		var event: Dictionary = schedule[index]
		marker.position = timeline.event_position(event.kind,event.wave)
		marker.get_node("Divider").hide()
		marker.get_node("Dot").visible = event.kind == "wave"
		marker.get_node("Dot/Outline").default_color = timeline.muted_color
		marker.get_node("Dot/Fill").color = Color("f3f8f7")
		var icon: Sprite2D = marker.get_node("EventIcon")
		icon.visible = event.kind != "wave"
		icon.texture = WaveTimeline.RELIC_ICON if event.kind == "relic" else WaveTimeline.EXPANSION_ICON
		var caption: Label = marker.get_node("Caption")
		caption.text = timeline.event_caption(event)
		caption.add_theme_color_override("font_color",timeline.muted_color)
		if timeline.act_font != null: caption.add_theme_font_override("font",timeline.act_font)
	var boundaries := timeline.act_boundaries()
	while _act_dividers.size() > boundaries.size(): _act_dividers.pop_back().free()
	while _act_dividers.size() < boundaries.size():
		var divider := $StartDivider.duplicate() as Line2D
		add_child(divider)
		_act_dividers.append(divider)
	for i in boundaries.size():
		var divider := _act_dividers[i]
		var x := size.x/WaveTimeline.VISIBLE_EVENTS*(WaveTimeline.PAST_EVENTS+boundaries[i]-timeline.event_cursor)
		divider.position = Vector2(x,43)
		divider.default_color = timeline.muted_color
		divider.visible = x >= 0 and x <= size.x
	if _current == null:
		_current = marker_scene.instantiate() as Node2D
		_current.name = "Current"
		add_child(_current)
		_current.get_node("Divider").hide()
		_current.get_node("Dot/Fill").color = Color("202c2d")
		_current.get_node("Dot/Outline").default_color = Color("202c2d")
	_current.visible = not schedule.is_empty()
	_current.position = Vector2(size.x/WaveTimeline.VISIBLE_EVENTS*(0.5+WaveTimeline.PAST_EVENTS),43)
	_current.scale = Vector2.ONE*(1.0+timeline.marker_pulse)

func marker_extent(_index: int) -> float:
	return WaveTimeline.NODE_RADIUS+WaveTimeline.NODE_OUTLINE_WIDTH*0.5
