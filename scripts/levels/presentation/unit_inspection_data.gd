extends RefCounted
## Read-only presentation of live instance values, never a second stat calculator.
static func number(value: float) -> String:
	return str(snappedf(value,0.01))

static func tower(t: DefenseTower, catalog: RelicCatalog) -> Dictionary:
	var en := TranslationServer.get_locale().begins_with("en")
	var stats := PackedStringArray()
	var notes := PackedStringArray()
	if t.deployment != null:
		stats.append(("Soldier damage  %s" if en else "士兵傷害  %s") % number(t.deployment.damage))
		stats.append(("Melee interval  %s s" if en else "近戰間隔  %s 秒") % number(t.deployment.interval))
		stats.append(("Engage radius  %s" if en else "接戰距離  %s 格") % number(t.deployment.engage_radius))
		notes.append(("%d soldiers · %s HP each · respawn %s s" if en else "%d 名士兵 · 每名生命 %s · 重生 %s 秒") % [t.deployment.count,number(t.deployment.health),number(t.deployment.respawn_seconds)])
		if t.has_relic(&"sharpshooter"): notes.append(("Soldier ranged support  %s tiles" if en else "士兵遠程支援  %s 格") % number(t.relic_value(&"sharpshooter",&"range")))
	elif t.attack != null:
		stats.append(("Damage  %s" if en else "傷害  %s") % number(t.damage*t.attack.damage_multiplier))
		stats.append(("Interval  %s s" if en else "攻擊間隔  %s 秒") % number(t.attack_interval))
		var circular: bool = t.attack is VolleyAttack and t.attack.circular_range
		if circular: stats.append(("Range  %s tiles" if en else "射程  %s 格") % number(t.attack_radius*t.range_multiplier))
		if t.attack is ProjectileAttack or t.attack is VolleyAttack and t.attack.mode == VolleyAttack.Mode.SPLASH:
			notes.append(("Blast radius  %s tiles" if en else "爆炸半徑  %s 格") % number(t.attack.splash_radius))
		for effect in t.attack.effects:
			if effect is SlowEffect: notes.append(("Slow to %s%% for %s s" if en else "減速至 %s%%，持續 %s 秒") % [number(effect.speed_multiplier*100),number(effect.duration)])
	else:
		stats.append(("Durability  %s / %s" if en else "耐久  %s / %s") % [number(t.health),number(t.max_health)])
	if t.has_relic(&"small_fry"): notes.append(("Small-target damage ×%s" if en else "對小型單位傷害 ×%s") % number(t.relic_value(&"small_fry",&"damage_multiplier",1)))
	for relic_id: StringName in t.relic_effects:
		var relic := catalog.find(relic_id)
		if relic != null: notes.append(TranslationServer.translate(relic.name_key))
	if t.support_bonus > 0: notes.append(("Support damage +%s%%" if en else "支援傷害 +%s%%") % number(t.support_bonus*100))
	if t.geometry_damage_bonus > 0: notes.append(("Geometry damage +%s%%" if en else "配置傷害 +%s%%") % number(t.geometry_damage_bonus*100))
	if t.is_disabled(): notes.append("Temporarily disabled" if en else "暫時失能")
	return {"name":t.definition.localized_name()+"  ·  Lv.%d" % t.level,"kind":"","stats":stats,"notes":" · ".join(notes),"icon":t.definition.icon,"color":t.definition.accent_color.darkened(0.45),"health":-1.0}

static func enemy(e: Node3D) -> Dictionary:
	var en := TranslationServer.get_locale().begins_with("en")
	var stats := PackedStringArray(["HP  %s / %s" % [number(e.health),number(e.max_health)]])
	stats.append(("Base damage  %d" if en else "主堡傷害  %d") % int(e.abilities.get("base_damage",1)))
	if e.max_shield > 0: stats.append(("Shield  %s / %s" if en else "護盾  %s / %s") % [number(e.shield),number(e.max_shield)])
	var types := PackedStringArray([TranslationServer.translate("ui.progress.size.%s" % e.troop.body_size)])
	for tag: StringName in e.troop.tags:
		types.append(("Ground" if en else "地面") if tag == &"ground" else TranslationServer.translate("ui.progress.tag.%s" % tag))
	var notes := PackedStringArray()
	var description: String = e.troop.ability_text_en if en else e.troop.ability_text
	description = description.replace("多盾衛依優先級、距離、出生順序選定。", "").replace("; priority, distance, then spawn order break ties.", ".").strip_edges()
	if not description.is_empty(): notes.append(description)
	var reduction := float(e.abilities.get("damage_reduction",0.0))
	if reduction > 0 and not ("減傷" in description or "damage reduction" in description.to_lower()): notes.append(("Damage reduction %s%%" if en else "傷害減免 %s%%") % number(reduction*100))
	if e.troop.has_tag(&"boss"): notes.append("Ends the run if it reaches the base" if en else "抵達主堡即戰敗")
	return {"name":e.troop.localized_name(),"kind":" · ".join(types),"stats":stats,"notes":" · ".join(notes),"icon":e.troop.icon,"color":e.troop.icon_color(),"health":100.0*e.health/e.max_health}
