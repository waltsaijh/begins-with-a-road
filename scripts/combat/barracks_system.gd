extends Node3D
const Soldier = preload("res://scripts/combat/friendly_soldier.gd")
var combat: Node
var map: GridMap
var units: Array[Node3D] = []
var owners := {}
func _ready() -> void:
	process_priority = 45
	map = combat.map
func cell(point: Vector3) -> Vector2i: return combat._index.cell_for(point)
func world(at: Vector2i) -> Vector3: return map.to_global(map.map_to_local(Vector3i(at.x,0,at.y)))
func distance(a: Vector3,b: Vector3) -> float:
	var d := map.to_local(a)-map.to_local(b)
	return Vector2(d.x/map.cell_size.x,d.z/map.cell_size.z).length()
func road(at: Vector2i) -> bool:
	return map.get_cell_item(Vector3i(at.x,0,at.y)) > 0 and not combat.tower_map.occupied.has(at) and not at in combat.tower_map.controller.terminal_cells()
func path(from: Vector2i,to: Vector2i,home: Vector2i,radius: float) -> Array[Vector2i]:
	var parents := {from:from}
	var queue: Array[Vector2i] = [from]
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		if at == to:
			var result: Array[Vector2i] = [at]
			while at != from:
				at = parents[at]
				result.push_front(at)
			return result
		for offset: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := at+offset
			if parents.has(next) or Vector2(next-home).length() > radius or not road(next): continue
			parents[next] = at
			queue.append(next)
	return []
func walk(unit: Node3D,destination: Vector3,delta: float) -> void:
	var from := cell(unit.global_position)
	var route := path(from,cell(destination),unit.home,unit.settings.local_radius)
	if route.is_empty(): return
	var waypoint := destination
	if route.size() > 1:
		var center := world(from)
		var next := world(route[1])
		var d := map.to_local(next)-map.to_local(center)
		var p := map.to_local(unit.global_position)-map.to_local(center)
		waypoint = center if absf(Vector2(d.x,d.z).normalized().cross(Vector2(p.x,p.z))) > 0.001 else next
	unit.global_position = unit.global_position.move_toward(waypoint,unit.settings.speed*delta*map.cell_size.x)
func effect(at: Vector3,kind: String) -> void: combat.visuals.restored_bursts.emit(at,kind)
func _process(delta: float) -> void:
	for tower: DefenseTower in combat.tower_map.towers.values():
		if tower.deployment == null or tower.is_queued_for_deletion(): continue
		var existing: int = owners.get(tower,0)
		for slot in range(existing,tower.deployment.count):
			var unit := Soldier.new()
			add_child(unit)
			unit.initialize(tower,slot,self)
			units.append(unit)
		owners[tower] = tower.deployment.count
	var active: bool = combat.wave.active
	if active and not units.is_empty():
		combat._index.rebuild(combat.wave.living_enemies(),map)
		combat.friendly_index_ready = true
	for i in range(units.size()-1,-1,-1):
		var unit := units[i]
		if not is_instance_valid(unit.tower) or unit.tower.is_queued_for_deletion() or unit.tower.health <= 0 or unit.slot_index >= unit.tower.deployment.count:
			unit.release()
			unit.queue_free()
			units.remove_at(i)
			continue
	# Stable slot order matches the source; removal traversal must not reverse
	# engagement priority between the two friendly soldiers.
	for unit in units:
		if active: unit.advance(delta)
		else:
			unit.release()
			if not unit.dead: unit.global_position = unit.home_position
	for owner in owners.keys():
		if not is_instance_valid(owner) or owner.is_queued_for_deletion(): owners.erase(owner)
