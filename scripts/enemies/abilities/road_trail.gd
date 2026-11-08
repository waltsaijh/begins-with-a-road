extends Node3D
## Shared ground trail for TrailAbility: which road tiles are marked this wave,
## the translucent strip drawn over them, and the speed-up for ground enemies
## standing on a marked tile. Shares the GridMap transform; positions are map-local.
## Marks and buffs end with the wave; the strip then fades out.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SURFACE_HEIGHT := 0.07
const FADE_SECONDS := 0.8
var host: Node
## cell -> {marker instance id: Vector2(bonus, seconds)}. An enemy never gets
## the speed-up from its own trail, only from tiles other enemies marked.
var buffs: Dictionary[Vector2i, Dictionary] = {}
var icon: Texture2D
## Style key [color, width] -> {"links": {cell: port mask}, "mesh", "dirty", "color", "half"}
var _layers := {}

## Marks cell, joined to the previous tile when the two are adjacent.
func mark(marker: Node3D, cell: Vector2i, previous: Variant, style: Dictionary) -> void:
	var key := [style.color, style.width]
	if not _layers.has(key): _layers[key] = {"links": {}, "mesh": null, "dirty": true, "color": style.color, "half": style.width*0.5}
	var layer: Dictionary = _layers[key]
	var links: Dictionary = layer.links
	links[cell] = int(links.get(cell, 0))
	if previous is Vector2i:
		var step: Vector2i = cell-previous
		var direction := DIRECTIONS.find(step)
		if direction >= 0:
			links[previous] = int(links.get(previous, 0)) | (1 << direction)
			links[cell] = int(links[cell]) | (1 << ((direction+2)%4))
	layer.dirty = true
	if not buffs.has(cell): buffs[cell] = {}
	var id := marker.get_instance_id()
	var current: Vector2 = buffs[cell].get(id, Vector2.ZERO)
	buffs[cell][id] = Vector2(maxf(current.x, style.bonus), maxf(current.y, style.seconds))
	if style.icon != null: icon = style.icon

func update(_delta: float) -> void:
	for layer: Dictionary in _layers.values():
		if layer.dirty: _rebuild(layer)
	if buffs.is_empty(): return
	for enemy in host.living_enemies():
		if enemy.troop != null and enemy.troop.has_tag(&"flying"): continue
		var markers: Dictionary = buffs.get(host.cell_of(enemy), {})
		if markers.is_empty(): continue
		var own: int = enemy.get_instance_id()
		var best := Vector2.ZERO
		for id: int in markers:
			if id == own: continue
			best = Vector2(maxf(best.x, markers[id].x), maxf(best.y, markers[id].y))
		if best.x > 0: enemy.apply_haste(best.x, best.y, icon)

## Wave end: buffs stop at once, the drawn strip fades out.
func clear() -> void:
	buffs.clear()
	for layer: Dictionary in _layers.values():
		var mesh: MeshInstance3D = layer.mesh
		if not is_instance_valid(mesh): continue
		var material: StandardMaterial3D = mesh.material_override
		var fade := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(material, "albedo_color:a", 0.0, FADE_SECONDS)
		fade.tween_callback(mesh.queue_free)
	_layers.clear()

func _rebuild(layer: Dictionary) -> void:
	layer.dirty = false
	var map: GridMap = host.combat.map
	var color: Color = layer.color
	var half: float = layer.half
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(color)
	# A center square plus one arm per joined side: pieces never overlap, so the
	# translucent strip keeps one even opacity through corners and junctions.
	for cell: Vector2i in layer.links:
		var center := map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*SURFACE_HEIGHT
		_quad(surface, center, map.cell_size, Vector2(-half, -half), Vector2(half, half))
		var mask: int = layer.links[cell]
		for direction in 4:
			if not mask & (1 << direction): continue
			var along := Vector2(DIRECTIONS[direction])
			var across := Vector2(-along.y, along.x)
			var a := along*half+across*half
			var b := along*0.5-across*half
			_quad(surface, center, map.cell_size, Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y)))
	if not is_instance_valid(layer.mesh):
		var mesh := MeshInstance3D.new()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override = SolidMaterials.transparent(Color.WHITE)
		add_child(mesh)
		layer.mesh = mesh
	layer.mesh.mesh = surface.commit()

## One flat rectangle in cell units around center.
func _quad(surface: SurfaceTool, center: Vector3, size: Vector3, low: Vector2, high: Vector2) -> void:
	var corners := [Vector2(low.x, low.y), Vector2(high.x, low.y), Vector2(high.x, high.y), Vector2(low.x, high.y)]
	var points: Array[Vector3] = []
	for corner: Vector2 in corners: points.append(center+Vector3(corner.x*size.x, 0, corner.y*size.z))
	for index in [0, 1, 2, 0, 2, 3]: surface.add_vertex(points[index])
