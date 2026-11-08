extends MeshInstance3D
## Only the selected unit owns visible geometry. Cell coverage is combat's cache.
const FILL := Color(0.35,0.93,0.75,0.16)
const EDGE := Color(0.20,0.70,0.46,0.72)
const MARK := Color(0.73,0.58,0.30,0.75)
var cells: Array[Vector2i] = []
var circular := false
var center := Vector3.ZERO
var radius := 0.0
var gun_segments: Array = []
var rebuilds := 0
var _signature: Array = []
var _planes: Array[Plane] = []
var _vertices := 0

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	hide()

func clear() -> void:
	mesh = null
	_signature.clear()
	cells.clear()
	gun_segments.clear()
	hide()

func update_tower(t: DefenseTower, map: GridMap) -> void:
	global_transform = map.global_transform
	var attack := t.attack
	var has_guns: bool = attack is VolleyAttack and attack.gun_lines and t.has_gun_lines()
	var is_circle: bool = attack is VolleyAttack and attack.circular_range and t.deployment == null and not has_guns
	var segments: Array = []
	if has_guns:
		var tile := map.cell_size.x*map.global_basis.x.length()
		for gun in t.gun_count():
			var start := t.gun_position(gun)
			var end: Vector3 = start+t.gun_direction(gun)*attack.gun_reach*t.range_multiplier*tile
			segments.append([map.to_local(start)/map.cell_size,map.to_local(end)/map.cell_size,attack.gun_half_width])
	var origin := map.to_local(t.combat_origin())
	var anchor := t.grid_cell
	if t.has_relic(&"departure"): anchor = Vector2i(map.local_to_map(map.to_local(t.patrol_visual().global_position)).x,map.local_to_map(map.to_local(t.patrol_visual().global_position)).z)
	var coverage: Array[Vector2i] = []
	if not is_circle and not has_guns and t.deployment == null and attack != null:
		for offset in t.attack_offsets(): coverage.append(anchor+offset)
	var home := t.garrison_cell()
	var soldier_state: Array = []
	if t.deployment != null:
		soldier_state = [t.deployment.local_radius,t.deployment.engage_radius,t.deployment.count,t.get_parent().controller.revision]
		for unit: Node3D in t.get_parent().combat.barracks.units:
			if unit.tower == t: soldier_state.append([unit.home_position,unit.global_position if t.has_relic(&"sharpshooter") and not unit.dead else Vector3.ZERO])
	var signature: Array = [t.get_instance_id(),is_circle,origin if is_circle else Vector3.ZERO,t.attack_radius,t.range_multiplier,coverage,t.occupied_cells.duplicate(),home,soldier_state,t.has_relic(&"crew_concentration"),t.combat_origin() if t.has_relic(&"crew_concentration") else Vector3.ZERO,t.rotation_steps]
	signature.append(segments)
	if signature == _signature: return
	_signature = signature
	rebuilds += 1
	circular = is_circle
	center = origin
	center.y = map.map_to_local(Vector3i.ZERO).y+0.13
	radius = t.attack_radius*t.range_multiplier
	cells = coverage
	gun_segments = segments
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_vertices = 0
	_planes.clear()
	if t.has_relic(&"crew_concentration"):
		var normal := map.global_basis.inverse()*t.patrol_visual().global_basis.x
		_planes.append(Plane(normal.normalized(),origin))
	if has_guns: _guns(result,map,segments)
	elif circular: _circle(result,center,radius*map.cell_size.x,radius*map.cell_size.z,FILL,EDGE)
	elif t.deployment == null: _tiles(result,map,coverage,FILL,EDGE)
	else:
		_garrison(result,t,map)
	_planes.clear()
	_tiles(result,map,t.occupied_cells,Color.TRANSPARENT,MARK)
	# An obstacle without an attack still gets a base mark.
	if _vertices == 0:
		mesh = null
		hide()
		return
	result.surface_end()
	mesh = result
	show()

func update_enemy(at: Vector3, map: GridMap) -> void:
	gun_segments.clear()
	global_transform = map.global_transform
	var local := map.to_local(at)
	local.y = map.map_to_local(Vector3i.ZERO).y+0.14
	global_transform = map.global_transform*Transform3D(Basis.IDENTITY,Vector3(local.x,0,local.z))
	if _signature == ["enemy"]: return
	_signature = ["enemy"]
	cells.clear()
	circular = false
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_planes.clear()
	_circle(result,Vector3(0,local.y,0),map.cell_size.x*0.30,map.cell_size.z*0.30,Color.TRANSPARENT,MARK)
	result.surface_end()
	mesh = result
	show()

## Match targets_along_segment's capsule in map-cell coordinates, including
## the rounded ends. Merge overlapping guns so their shared area is not darker.
func _guns(result: ImmediateMesh, map: GridMap, segments: Array) -> void:
	var polygons: Array[PackedVector2Array] = []
	for segment in segments:
		var a := Vector2(segment[0].x,segment[0].z)
		var b := Vector2(segment[1].x,segment[1].z)
		var angle := (b-a).angle()
		var polygon := PackedVector2Array()
		for i in 13: polygon.append(b+Vector2.from_angle(angle-PI*0.5+PI*i/12.0)*float(segment[2]))
		for i in 13: polygon.append(a+Vector2.from_angle(angle+PI*0.5+PI*i/12.0)*float(segment[2]))
		var index := 0
		while index < polygons.size():
			var merged := Geometry2D.merge_polygons(polygon,polygons[index])
			if merged.size() == 1:
				polygon = merged[0]
				polygons.remove_at(index)
				index = 0
			else: index += 1
		polygons.append(polygon)
	for polygon in polygons:
		var points: Array[Vector3] = []
		for p in polygon: points.append(Vector3(p.x*map.cell_size.x,center.y,p.y*map.cell_size.z))
		var triangles := Geometry2D.triangulate_polygon(polygon)
		for i in range(0,triangles.size(),3):
			_polygon(result,[points[triangles[i]],points[triangles[i+1]],points[triangles[i+2]]],FILL)
		for i in points.size():
			var a := points[i]
			var b := points[(i+1)%points.size()]
			var side := (b-a).normalized().cross(Vector3.UP)*0.0125
			_polygon(result,[a-side,b-side,b+side,a+side],EDGE)

func _tiles(result: ImmediateMesh, map: GridMap, covered: Array[Vector2i], fill: Color, edge: Color) -> void:
	var lookup := {}
	for at in covered: lookup[at] = true
	var x := map.cell_size.x*0.5
	var z := map.cell_size.z*0.5
	var width := minf(x,z)*0.045
	for at in covered:
		var c := map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*0.13
		if fill.a > 0: _quad(result,c,-x,-z,x,z,fill)
		if not lookup.has(at+Vector2i.UP): _quad(result,c,-x,-z,x,-z+width,edge)
		if not lookup.has(at+Vector2i.DOWN): _quad(result,c,-x,z-width,x,z,edge)
		if not lookup.has(at+Vector2i.LEFT): _quad(result,c,-x,-z,-x+width,z,edge)
		if not lookup.has(at+Vector2i.RIGHT): _quad(result,c,x-width,-z,x,z,edge)

func _circle(result: ImmediateMesh, c: Vector3, x: float, z: float, fill: Color, edge: Color) -> void:
	var width := 0.025
	for i in 80:
		var a := Vector3(cos(TAU*i/80.0),0,sin(TAU*i/80.0))
		var b := Vector3(cos(TAU*(i+1)/80.0),0,sin(TAU*(i+1)/80.0))
		var aa := c+Vector3(a.x*x,0,a.z*z)
		var bb := c+Vector3(b.x*x,0,b.z*z)
		if fill.a > 0: _polygon(result,[c,aa,bb],fill)
		_polygon(result,[aa,bb,c+Vector3(b.x*(x-width),0,b.z*(z-width)),c+Vector3(a.x*(x-width),0,a.z*(z-width))],edge)

func _quad(result: ImmediateMesh, c: Vector3, left: float, top: float, right: float, bottom: float, color: Color) -> void:
	_polygon(result,[c+Vector3(left,0,top),c+Vector3(right,0,top),c+Vector3(right,0,bottom),c+Vector3(left,0,bottom)],color)

func _polygon(result: ImmediateMesh, points: Array[Vector3], color: Color) -> void:
	for plane in _planes:
		var clipped: Array[Vector3] = []
		for i in points.size():
			var a := points[i]
			var b := points[(i+1)%points.size()]
			var da := plane.distance_to(a)
			var db := plane.distance_to(b)
			if da >= 0: clipped.append(a)
			if (da >= 0) != (db >= 0): clipped.append(a.lerp(b,da/(da-db)))
		points = clipped
	result.surface_set_color(color)
	for i in range(1,points.size()-1):
		for point in [points[0],points[i],points[i+1]]:
			result.surface_add_vertex(point)
			_vertices += 1

func _garrison(result: ImmediateMesh, t: DefenseTower, map: GridMap) -> void:
	var manager: Node3D = t.get_parent().combat.barracks
	var home := t.garrison_cell()
	var reachable: Array[Vector2i] = []
	var extent := ceili(t.deployment.local_radius)
	for z in range(-extent,extent+1):
		for x in range(-extent,extent+1):
			var at := home+Vector2i(x,z)
			if not manager.path(home,at,home,t.deployment.local_radius).is_empty(): reachable.append(at)
	cells = reachable
	for unit: Node3D in manager.units:
		if unit.tower != t: continue
		var center_local := map.to_local(unit.home_position)
		center_local.y = map.map_to_local(Vector3i.ZERO).y+0.13
		for at in reachable:
			var c := map.map_to_local(Vector3i(at.x,0,at.y))
			_planes.assign([Plane(Vector3.RIGHT,c-Vector3(map.cell_size.x*0.5,0,0)),Plane(Vector3.LEFT,c+Vector3(map.cell_size.x*0.5,0,0)),Plane(Vector3.BACK,c-Vector3(0,0,map.cell_size.z*0.5)),Plane(Vector3.FORWARD,c+Vector3(0,0,map.cell_size.z*0.5))])
			_circle(result,center_local,t.deployment.engage_radius*map.cell_size.x,t.deployment.engage_radius*map.cell_size.z,FILL,EDGE)
		_planes.clear()
		if t.has_relic(&"sharpshooter") and not unit.dead:
			var p := map.to_local(unit.global_position)
			p.y = center_local.y
			var reach := t.relic_value(&"sharpshooter",&"range")
			_circle(result,p,reach*map.cell_size.x,reach*map.cell_size.z,Color.TRANSPARENT,Color(0.53,0.60,0.63,0.25))
