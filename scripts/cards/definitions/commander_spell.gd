@tool
class_name CommanderSpell
extends Resource

@export var name_key := "spell.shot.name"
@export var icon: Texture2D
@export var accent_color := Color("c68b50")
@export var kind: StringName = &"shot"
@export_range(0, 1000, 1, "or_greater") var damage := 70
@export_range(0.25, 5.0, 0.25) var radius := 1.0

func localized_name() -> String:
	return tr(name_key)

func stacks_with(other: CommanderSpell) -> bool:
	return other != null and kind == other.kind and name_key == other.name_key and damage == other.damage and radius == other.radius

func description() -> String:
	if kind not in [&"shot", &"cannon", &"support", &"volley"]:
		return tr("spell.%s.effect" % kind)
	return tr("spell.area_damage").format({"damage": damage, "radius": str(radius).trim_suffix(".0")})

func can_target(map: GridMap, cell: Vector3i) -> bool:
	return cell.y == 0 and cell != TileConstants.INVALID_CELL and TileConstants.base_item(map.get_cell_item(cell)) > 0

func valid_target(combat: Node, cell: Vector3i) -> bool:
	if cell == TileConstants.INVALID_CELL: return false
	var at := Vector2i(cell.x, cell.z)
	if kind == &"fortify":
		var tower: DefenseTower = combat.tower_map.occupied.get(at)
		return tower != null and tower.deployment != null
	if kind == &"reinforce": return combat.barracks.road(at)
	if kind == &"rally" and combat.tower_map.occupied.has(at): return true
	return can_target(combat.map, cell)

func resolve(combat: Node, cell: Vector3i) -> void:
	var map: GridMap = combat.map
	var visuals: Node3D = combat.visuals
	var center := map.map_to_local(cell)
	var impact := map.to_global(center + Vector3.UP * 0.12)
	visuals.add_beam(impact + Vector3.UP * 2.5, impact, accent_color, 0.055, 0.15)
	visuals.add_impact(impact, radius, accent_color, map)
	match kind:
		&"reinforce":
			combat.barracks.summon(Vector2i(cell.x,cell.z))
			return
		&"fortify":
			var tower: DefenseTower = combat.tower_map.occupied[Vector2i(cell.x,cell.z)]
			for unit in combat.barracks.units:
				if unit.temporary or unit.dead or not is_instance_valid(unit.tower): continue
				if combat.barracks.distance(unit.tower.combat_origin(),tower.combat_origin()) <= radius:
					unit.shield = 30
					unit.shield_seconds = 6
			return
		&"rally":
			for tower: DefenseTower in combat.tower_map.towers.values():
				if combat.barracks.distance(tower.combat_origin(),impact) <= radius:
					tower.clear_disable()
					tower.disable_immunity = 4
			return
		&"delayed":
			combat.projectiles.append({"spell":self,"cell":cell,"start":impact+Vector3.UP*3,"end":impact,"age":0.0,"duration":0.8,"arc":0.4,"visual_size":0.14,"color":accent_color,"radius":radius})
			return
	hit_enemies(combat, cell)

func hit_enemies(combat: Node, cell: Vector3i) -> void:
	var map: GridMap = combat.map
	var center := map.map_to_local(cell)
	var nearest: Node3D
	var nearest_distance := INF
	for enemy in combat.wave.living_enemies():
		var offset := (map.to_local(enemy.global_position) - center) / map.cell_size
		var distance := Vector2(offset.x, offset.z).length_squared()
		if distance > radius * radius: continue
		if kind == &"snipe":
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = enemy
			continue
		if damage > 0: enemy.take_damage(damage, "commander_"+str(kind))
		if not enemy.can_be_targeted(): continue
		match kind:
			&"lightning": enemy.stun(1)
			&"last": enemy.stun(2)
			&"bind": enemy.apply_slow(0.7,3,preload("res://assets/sprites/effects/slowness.png"))
	if nearest != null: nearest.take_damage(damage, "commander_snipe")
