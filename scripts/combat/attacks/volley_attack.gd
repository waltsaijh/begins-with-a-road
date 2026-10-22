@tool
class_name VolleyAttack
extends TowerAttack
## Prototype delivery: damage is immediate; all travel is presentation only.
enum Mode { SINGLE, SPLASH, ALL }
@export var mode: Mode = Mode.SINGLE
@export var circular_range := true
@export var splash_radius := 1.0
@export var mortar_visual := false

func configuration_error() -> String:
	var error := super.configuration_error()
	if not error.is_empty(): return error
	return "範圍傷害半徑無效" if not is_finite(splash_radius) or splash_radius < 0 else ""

func targets(combat: Node, tower: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = combat._index.targets_near(tower.global_position,tower.attack_radius) if circular_range else combat._index.targets_in_offsets(tower.grid_cell,tower.attack_offsets())
	result.sort_custom(func(a: Node3D,b: Node3D): return a.enemy_id < b.enemy_id)
	return result

func select_target(combat: Node, tower: Node3D) -> Node3D:
	var valid := targets(combat,tower)
	return null if valid.is_empty() else valid[0]

func fire(combat: Node, tower: Node3D, target: Node3D) -> void:
	var victims: Array[Node3D] = [target]
	if mode == Mode.ALL: victims = targets(combat,tower)
	if mode == Mode.SPLASH: victims = combat._index.targets_near(target.global_position,splash_radius)
	# Capture positions before damage can remove the target from the wave.
	var end := target.global_position
	for victim in victims:
		if not mortar_visual:
			tower.prepare_shot(victim)
			combat.visuals.add_beam(tower.muzzle_position(),victim.global_position+Vector3.UP*0.24,color,0.035,0.16)
		AttackPayload.new(tower,victim,self).apply(victim)
	if mortar_visual:
		combat.projectiles.append({"visual_only":true,"start":tower.muzzle_position(),"end":end,"cell":combat._index.cell_for(end),"age":0.0,"duration":0.16,"radius":splash_radius,"arc":1.1,"visual_size":0.13,"color":color})
