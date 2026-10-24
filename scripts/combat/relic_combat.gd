extends RefCounted
## Mechanisms sharing the normal target queries, payloads and presentation.

static func advance(combat: Node, tower: DefenseTower, delta: float) -> void:
	if tower.has_relic(&"departure") and tower._visual != null:
		var reach := 0.0
		for offset in tower.definition.attack_cells_at(Vector2i.ZERO): reach = maxf(reach, absf(offset.x))
		if reach > 0:
			tower.patrol_distance += delta*tower.relic_value(&"departure", &"speed")
			var at := fposmod(tower.patrol_distance+reach,4.0*reach)
			tower.set_patrol_offset((at-reach if at < 2.0*reach else 3.0*reach-at)*combat.map.cell_size.x)
	if tower.has_relic(&"hunting"):
		var ready: float = tower.relic_clocks.get(&"hunting",combat.elapsed+tower.relic_value(&"hunting", &"period"))
		tower.relic_clocks[&"hunting"] = ready
		if combat.elapsed >= ready:
			var candidates: Array[Node3D] = combat.targets_for(tower)
			candidates = candidates.filter(func(enemy): return not tagged(enemy,&"boss"))
			candidates.sort_custom(func(a,b):
				if tagged(a,&"large") != tagged(b,&"large"): return tagged(a,&"large")
				return a.enemy_id < b.enemy_id)
			var preferred: Node3D = combat.enemy_abilities.preferred(tower,candidates)
			if preferred != null:
				candidates.erase(preferred)
				candidates.push_front(preferred)
			if not candidates.is_empty():
				var victim: Node3D = candidates[0]
				tower.prepare_shot(victim)
				combat.visuals.add_beam(tower.muzzle_position(),victim.global_position+Vector3.UP*0.3,Color("f7de80"),0.1,0.35)
				combat.visuals.restored_bursts.emit(victim.global_position,"respawn")
				victim.take_damage((victim.health+victim.shield)/maxf(0.000001,1.0-float(victim.abilities.get("damage_reduction",0.0))))
				tower.relic_clocks[&"hunting"] = combat.elapsed+tower.relic_value(&"hunting", &"period")
	if tower.has_relic(&"rapid_fire"):
		var ready: float = tower.relic_clocks.get(&"rapid_fire",combat.elapsed+tower.relic_value(&"rapid_fire", &"period"))
		tower.relic_clocks[&"rapid_fire"] = ready
		if combat.elapsed >= ready and tower.rapid_remaining == 0 and not combat.targets_for(tower).is_empty():
			tower.rapid_remaining = int(tower.relic_value(&"rapid_fire", &"shots"))
			tower.rapid_next = combat.elapsed
			tower.relic_clocks[&"rapid_fire"] = combat.elapsed+tower.relic_value(&"rapid_fire", &"period")
		# Bound work to the authored burst length even after a slow frame.
		while tower.rapid_remaining > 0 and combat.elapsed >= tower.rapid_next:
			var candidates: Array[Node3D] = combat.targets_for(tower)
			candidates.sort_custom(func(a,b): return a.enemy_id < b.enemy_id)
			for side in [-1,1]:
				if side < 0 and tower.has_relic(&"crew_concentration"): continue
				var side_targets: Array[Node3D] = candidates.filter(func(enemy): return signf(tower.patrol_visual().to_local(enemy.global_position).x) == side)
				var preferred: Node3D = combat.enemy_abilities.preferred(tower,side_targets)
				if preferred != null:
					side_targets.erase(preferred)
					side_targets.push_front(preferred)
				for victim in side_targets:
					tower.prepare_shot(victim)
					tower.attack.fire(combat,tower,victim)
					tower.present_shot(victim,combat.visuals)
					combat.shots_fired += 1
					break
			tower.rapid_remaining -= 1
			tower.rapid_next += tower.relic_value(&"rapid_fire", &"spacing")

static func tagged(enemy: Node3D, tag: StringName) -> bool:
	return enemy.troop != null and enemy.troop.has_tag(tag)
