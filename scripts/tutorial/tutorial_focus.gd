extends Control
## Presentation-only spotlight: never steals input or moves the highlighted UI.
@export var veil_alpha := 0.42
@export var frame_color := Color(0.7,0.61,0.38,1)
var target: Control
var _rect := Rect2()
var _age := 0.0
var _alpha := 0.0
var _last_usec := 0
var _outgoing := Rect2()
var _outgoing_alpha := 0.0
var _quad := PackedVector2Array()
var _outgoing_quad := PackedVector2Array()

func follow(next: Control) -> void:
	if target == next: return
	_outgoing = _rect
	_outgoing_quad = _quad.duplicate()
	_outgoing_alpha = _alpha
	target = next
	_age = 0.0
	_alpha = 0.0

func _ready() -> void:
	_last_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now-_last_usec)/1000000.0
	_last_usec = now
	_outgoing_alpha = move_toward(_outgoing_alpha,0.0,elapsed/0.18)
	if is_instance_valid(target) and target.is_visible_in_tree():
		_age += elapsed
		_alpha = minf(1.0,_alpha+elapsed/0.18)
		_refresh_geometry()
	else:
		_alpha = move_toward(_alpha,0.0,elapsed/0.18)
	queue_redraw()

func target_quad(padding := 0.0) -> PackedVector2Array:
	if not is_instance_valid(target): return PackedVector2Array()
	# Follow the rendered artwork, including fan rotation and selected-card sway.
	var artwork := target.get_node_or_null("Visuals") as Control
	if artwork == null: artwork = target
	var transform := get_global_transform_with_canvas().affine_inverse()*artwork.get_global_transform_with_canvas()
	var inset := Vector2(padding/maxf(0.001,transform.x.length()),padding/maxf(0.001,transform.y.length()))
	var lo := -inset
	var hi := artwork.size+inset
	var points := PackedVector2Array([transform*lo,transform*Vector2(hi.x,lo.y),transform*hi,transform*Vector2(lo.x,hi.y)])
	if transform.determinant() < 0.0: points.reverse()
	return points

func _refresh_geometry() -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree(): return
	var shrink := 1.0-smoothstep(0.0,0.5,_age)
	_quad = target_quad(3.0+42.0*shrink+(1.0+sin(_age*TAU/1.5)))
	_rect = Rect2(_quad[0],Vector2.ZERO)
	for point in _quad: _rect = _rect.expand(point)

## Clip a convex polygon to either side of a line, without overlapping mask pieces.
func _clip(points: PackedVector2Array, a: Vector2, b: Vector2, inside: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty(): return result
	var previous := points[-1]
	var previous_distance := (b-a).cross(previous-a)
	for point in points:
		var distance := (b-a).cross(point-a)
		var keep := distance >= 0.0 if inside else distance <= 0.0
		var kept_previous := previous_distance >= 0.0 if inside else previous_distance <= 0.0
		if keep != kept_previous:
			result.append(previous.lerp(point,previous_distance/(previous_distance-distance)))
		if keep: result.append(point)
		previous = point
		previous_distance = distance
	return result

func _draw_frame(points: PackedVector2Array, alpha: float) -> void:
	if points.size() != 4 or alpha <= 0.0: return
	var border := points.duplicate()
	border.append(points[0])
	draw_polyline(border,Color(frame_color,0.15*alpha),5.0,true)
	draw_polyline(border,Color(frame_color,alpha),1.5,true)

func polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size(): area += points[i].cross(points[(i+1)%points.size()])
	return absf(area)*0.5

func mask_regions(hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var regions: Array[PackedVector2Array] = []
	var remaining := PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	for i in 4:
		var a := hole[i]
		var b := hole[(i+1)%4]
		var outside := _clip(remaining,a,b,false)
		if outside.size() >= 3 and polygon_area(outside) > 0.01: regions.append(outside)
		remaining = _clip(remaining,a,b,true)
	return regions

func _draw() -> void:
	# Drawing happens after layout/tweens; sample the final transform for this frame.
	_refresh_geometry()
	var opacity := maxf(_alpha,_outgoing_alpha)
	if opacity <= 0.0: return
	var hole := _quad if _alpha > 0.0 else _outgoing_quad
	if hole.size() != 4: return
	var shade := Color(0.035,0.06,0.075,veil_alpha*opacity)
	for region in mask_regions(hole): draw_colored_polygon(region,shade)
	_draw_frame(_outgoing_quad,_outgoing_alpha)
	_draw_frame(_quad,_alpha)
