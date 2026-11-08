extends Node
## One shared post-movement pass. Behaviour and state live in each enemy's own
## EnemyAbility copies; this node only drives them and offers the world queries
## they need (nearby enemies, towers, distance, visuals).
const AbilityVisual = preload("res://scripts/enemies/rendering/ability_visual.gd")
var combat: Node
var heals := 0
var disables := 0
## Shared per-wave helpers some abilities need (e.g. the scout trail), keyed by
## script. Each has update(delta) and clear(); clear runs at wave end.
var _services := {}

func _ready() -> void:
	process_priority = 40
	if is_instance_valid(combat.wave) and combat.wave.has_signal("wave_finished"):
		combat.wave.wave_finished.connect(clear)

func _process(delta: float) -> void:
	if not is_instance_valid(combat.wave) or not is_instance_valid(combat.tower_map): return
	combat._index.rebuild(combat.wave.living_enemies(),combat.map)
	combat.friendly_index_ready = true
	advance(maxf(0,delta))

func clear() -> void:
	for tower: DefenseTower in combat.tower_map.towers.values(): tower.clear_disable()
	for enemy in combat.wave.living_enemies():
		for ability: EnemyAbility in enemy.abilities: ability.stop()
	for service in _services.values():
		if is_instance_valid(service): service.clear()

func advance(delta: float) -> void:
	for tower: DefenseTower in combat.tower_map.towers.values(): tower.advance_disable(delta)
	if not combat.wave.active: return
	for enemy in combat.wave.living_enemies():
		for ability: EnemyAbility in enemy.abilities: ability.update(self,delta)
	for service in _services.values():
		if is_instance_valid(service): service.update(delta)

## Called only AFTER attack eligibility/range filtering. Stable priority, then
## distance to the tower, then spawn ID; never taunts an ALL-target attack.
func preferred(tower: DefenseTower, candidates: Array[Node3D]) -> Node3D:
	var best: Node3D
	var priority := -1
	var distance := INF
	for enemy in candidates:
		if enemy.abilities.is_empty(): continue
		var at: float = combat.barracks.distance(enemy.global_position,tower.combat_origin())
		var rank := -1
		for ability: EnemyAbility in enemy.abilities: rank = maxi(rank,ability.taunt_rank(at))
		if rank < 0: continue
		if best == null or rank > priority or (rank == priority and (at < distance or (is_equal_approx(at,distance) and enemy.enemy_id < best.enemy_id))):
			best = enemy
			priority = rank
			distance = at
	return best

# --- Queries for abilities -------------------------------------------------

## One shared instance of a helper script, placed beside the map with the map's
## transform so its positions are map-local. (The GridMap itself is hidden; the
## visible roads are drawn by a separate layer, so it cannot be the parent.)
func service(script: Script) -> Node:
	var existing: Node = _services.get(script)
	if is_instance_valid(existing): return existing
	var created: Node = script.new()
	created.host = self
	combat.map.get_parent().add_child(created)
	if created is Node3D: created.transform = combat.map.transform
	_services[script] = created
	return created

func cell_of(enemy: Node3D) -> Vector2i:
	var cell: Vector3i = combat.map.local_to_map(combat.map.to_local(enemy.global_position))
	return Vector2i(cell.x,cell.z)

func living_enemies() -> Array:
	return combat.wave.living_enemies()

func enemies_near(position: Vector3, radius: float) -> Array:
	return combat._index.targets_near(position,radius)

func towers() -> Array:
	return combat.tower_map.towers.values()

func distance(from: Vector3, to: Vector3) -> float:
	return combat.barracks.distance(from,to)

func beam(from: Vector3, to: Vector3, color: Color, width := 0.025, seconds := 0.12) -> void:
	combat.visuals.add_beam(from,to,color,width,seconds)

func visual(enemy: Node3D) -> Node3D:
	if not is_instance_valid(enemy.ability_visual):
		enemy.ability_visual = AbilityVisual.new()
		enemy.add_child(enemy.ability_visual)
	return enemy.ability_visual
