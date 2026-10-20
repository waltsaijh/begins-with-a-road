class_name AttackPayload
extends RefCounted
## Snapshot damage/effect values at launch; deleting a tower does not erase a shot.
var damage := 0.0
var effects: Array[HitEffect] = []
var _source: WeakRef

func _init(tower: Node3D, target: Node3D, attack: TowerAttack) -> void:
	_source = weakref(tower)
	damage = tower.damage_against(target)*attack.damage_multiplier
	for effect in attack.effects:
		if effect != null:
			effects.append(effect.duplicate(true))

func apply(target: Node3D) -> void:
	if not is_instance_valid(target) or not target.can_be_targeted():
		return
	target.take_damage(damage)
	if not target.can_be_targeted():
		return
	var source := _source.get_ref() as Node3D
	for effect in effects:
		effect.apply(target, source, damage)
