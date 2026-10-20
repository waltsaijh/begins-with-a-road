@tool
extends Control
## Both tracks reuse the same editable marker scene; only the fill is clipped.
@export var filled := false
@export var marker_scene: PackedScene = preload("res://scenes/levels/components/wave_timeline_marker.tscn")
var _signature: Array = []
var _markers: Array[Node2D] = []

func refresh(timeline: WaveTimeline) -> void:
	if not is_node_ready(): return
	var count := timeline.level.wave_count() if timeline.level != null else 0
	var ends: Array[bool] = []
	for i in count: ends.append(timeline.is_act_end(i))
	var outline := timeline.progress_color if filled else timeline.muted_color
	var signature := [timeline.size, ends, outline, filled, marker_scene]
	if signature == _signature: return
	_signature = signature
	visible = count > 0
	if anchor_left == anchor_right and anchor_top == anchor_bottom: size = timeline.size
	var line: Line2D = $Line
	line.set_point_position(1, Vector2(timeline.size.x, line.points[1].y))
	line.default_color = outline if filled else Color(outline, 0.4)
	$StartDivider.default_color = outline
	while _markers.size() > count: _markers.pop_back().free()
	while _markers.size() < count:
		var marker := marker_scene.instantiate() as Node2D
		$Markers.add_child(marker)
		_markers.append(marker)
	for i in count:
		var marker := _markers[i]
		marker.position = Vector2(timeline.size.x*timeline.node_fraction(i), line.points[0].y)
		marker.get_node("Divider").visible = ends[i]
		marker.get_node("Divider").default_color = outline
		marker.get_node("Dot").visible = not ends[i]
		marker.get_node("Dot/Outline").default_color = outline
		if filled: marker.get_node("Dot/Fill").color = outline

func marker_extent(index: int) -> float:
	if index < 0 or index >= _markers.size(): return WaveTimeline.NODE_RADIUS+1.0
	var marker := _markers[index]
	if marker.get_node("Divider").visible: return marker.get_node("Divider").width*0.5
	var right := 0.0
	for point: Vector2 in marker.get_node("Dot/Fill").polygon: right = maxf(right, point.x)
	return right+marker.get_node("Dot/Outline").width*0.5
