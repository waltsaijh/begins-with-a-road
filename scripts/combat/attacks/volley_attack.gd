@tool
class_name VolleyAttack
extends TowerAttack
## Shared single/all delivery; mortar shells own real delayed impact payloads.
enum Mode { SINGLE, SPLASH, ALL }
@export var mode: Mode = Mode.SINGLE
@export var circular_range := true
@export var splash_radius := 1.0
@export var mortar_visual := false
@export var shell_speed := 6.0
@export var shell_minimum_seconds := 0.25
@export var shell_arc_height := 1.1

func configuration_error() -> String:
	var error := super.configuration_error()
	if not error.is_empty(): return error
	if not is_finite(shell_speed) or shell_speed <= 0 or not is_finite(shell_minimum_seconds) or shell_minimum_seconds <= 0: return "砲彈飛行參數無效"
	return "範圍傷害半徑無效" if not is_finite(splash_radius) or splash_radius < 0 else ""

func targets(combat: Node, tower: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = combat.targets_for(tower,self)
	result.sort_custom(func(a: Node3D,b: Node3D): return a.enemy_id < b.enemy_id)
	return result

func select_target(combat: Node, tower: Node3D) -> Node3D:
	var valid := targets(combat,tower)
	if mode != Mode.ALL:
		var preferred: Node3D = combat.enemy_abilities.preferred(tower,valid)
		if preferred != null: return preferred
	return null if valid.is_empty() else valid[0]

func fire(combat: Node, tower: Node3D, target: Node3D) -> void:
	if mortar_visual:
		combat.fire_mortar(tower,target,self)
		return
	if tower.has_relic(&"powerful_shot"):
		combat.fire_piercing_bolt(tower,target,self)
		return
	var victims: Array[Node3D] = [target]
	if mode == Mode.ALL: victims = targets(combat,tower)
	if mode == Mode.SPLASH: victims = combat._index.targets_near(target.global_position,splash_radius)
	for victim in victims:
		tower.prepare_shot(victim)
		combat.visuals.add_beam(tower.muzzle_position(),victim.global_position+Vector3.UP*0.24,Color("a7e6f2") if tower.has_relic(&"frost_ray") else color,0.035,0.16)
		var payload := AttackPayload.new(tower,victim,self)
		payload.knockback *= combat.map.cell_size.x*combat.map.global_basis.x.length()
		payload.apply(victim)
