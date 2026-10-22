class_name AttackPayload
extends RefCounted
## Snapshot damage/effect values at launch; deleting a tower does not erase a shot.
var damage := 0.0
var effects: Array[HitEffect] = []
var _source: WeakRef
var small_multiplier := 1.0
var frost := {}
var knockback := 0.0

func _init(tower: Node3D, target: Node3D, attack: TowerAttack) -> void:
	_source = weakref(tower)
	damage = tower.damage_against(target)*attack.damage_multiplier
	if tower is DefenseTower:
		small_multiplier = tower.relic_value(&"small_fry", &"damage_multiplier", 1.0)
		frost = tower.effect(&"frost_ray").duplicate(true)
		knockback = tower.relic_value(&"heavy_bolts", &"distance")
	for effect in attack.effects:
		if effect != null:
			effects.append(effect.duplicate(true))

func apply(target: Node3D) -> void:
	if not is_instance_valid(target) or not target.can_be_targeted():
		return
	var actual := damage
	if target.troop != null and target.troop.has_tag(&"small"): actual *= small_multiplier
	target.take_damage(actual)
	if not target.can_be_targeted():
		return
	var source := _source.get_ref() as Node3D
	if not frost.is_empty(): target.apply_frost(float(frost.strength), float(frost.duration), float(frost.maximum_slow))
	if knockback > 0: target.knock_back(knockback)
	for effect in effects:
		effect.apply(target, source, damage)
