extends RefCounted
## Read-only presentation of live instance values, never a second stat calculator.
static func number(value: float) -> String:
	return str(snappedf(value,0.01))

static func tower(t: DefenseTower, catalog: RelicCatalog) -> Dictionary:
	var en := TranslationServer.get_locale().begins_with("en")
	var stats := PackedStringArray()
	var notes := PackedStringArray()
	if t.deployment != null:
		stats.append((GameText.text("text.unit_inspection_data.1",{},en)) % number(t.deployment.damage))
		stats.append((GameText.text("text.unit_inspection_data.2",{},en)) % number(t.deployment.interval))
		stats.append((GameText.text("text.unit_inspection_data.3",{},en)) % number(t.deployment.engage_radius))
		notes.append((GameText.text("text.unit_inspection_data.4",{},en)) % [t.deployment.count,number(t.deployment.health),number(t.deployment.respawn_seconds)])
		if t.has_relic(&"sharpshooter"): notes.append((GameText.text("text.unit_inspection_data.5",{},en)) % number(t.relic_value(&"sharpshooter",&"range")))
	elif t.attack != null:
		stats.append((GameText.text("text.unit_inspection_data.6",{},en)) % number(t.damage*t.attack.damage_multiplier))
		stats.append((GameText.text("text.unit_inspection_data.7",{},en)) % number(t.attack_interval))
		var circular: bool = t.attack is VolleyAttack and t.attack.circular_range
		if t.attack is VolleyAttack and t.attack.gun_lines:
			stats.append((GameText.text("text.unit_inspection_data.8",{},en)) % number(t.attack.gun_reach*t.range_multiplier))
		elif circular: stats.append((GameText.text("text.unit_inspection_data.9",{},en)) % number(t.attack_radius*t.range_multiplier))
		if t.attack is ProjectileAttack or t.attack is VolleyAttack and t.attack.mode == VolleyAttack.Mode.SPLASH:
			notes.append((GameText.text("text.unit_inspection_data.10",{},en)) % number(t.attack.splash_radius))
		for effect in t.attack.effects:
			if effect is SlowEffect: notes.append((GameText.text("text.unit_inspection_data.11",{},en)) % [number(effect.speed_multiplier*100),number(effect.duration)])
	else:
		stats.append((GameText.text("text.unit_inspection_data.12",{},en)) % [number(t.health),number(t.max_health)])
	if t.has_relic(&"small_fry"): notes.append((GameText.text("text.unit_inspection_data.13",{},en)) % number(t.relic_value(&"small_fry",&"damage_multiplier",1)))
	for relic_id: StringName in t.relic_effects:
		var relic := catalog.find(relic_id)
		if relic != null: notes.append(TranslationServer.translate(relic.name_key))
	if t.support_bonus > 0: notes.append((GameText.text("text.unit_inspection_data.14",{},en)) % number(t.support_bonus*100))
	if t.geometry_damage_bonus > 0: notes.append((GameText.text("text.unit_inspection_data.15",{},en)) % number(t.geometry_damage_bonus*100))
	if t.is_disabled(): notes.append(GameText.text("text.unit_inspection_data.16",{},en))
	return {"name":t.definition.localized_name()+"  ·  Lv.%d" % t.level,"kind":"","stats":stats,"notes":" · ".join(notes),"icon":t.definition.icon,"color":t.definition.accent_color.darkened(0.45),"health":-1.0}

static func enemy(e: Node3D) -> Dictionary:
	var en := TranslationServer.get_locale().begins_with("en")
	var stats := PackedStringArray(["HP  %s / %s" % [number(e.health),number(e.max_health)]])
	stats.append((GameText.text("text.unit_inspection_data.17",{},en)) % e.base_damage)
	if e.max_shield > 0: stats.append((GameText.text("text.unit_inspection_data.18",{},en)) % [number(e.shield),number(e.max_shield)])
	var types := PackedStringArray([TranslationServer.translate("ui.progress.size.%s" % e.troop.body_size)])
	for tag: StringName in e.troop.tags:
		types.append((GameText.text("text.unit_inspection_data.19",{},en)) if tag == &"ground" else TranslationServer.translate("ui.progress.tag.%s" % tag))
	var notes := PackedStringArray()
	var description: String = e.troop.localized_ability_text()
	description = description.replace("多盾衛依優先級、距離、出生順序選定。", "").replace("; priority, distance, then spawn order break ties.", ".").strip_edges()
	if not description.is_empty(): notes.append(description)
	var reduction: float = e.damage_reduction
	if reduction > 0 and not ("減傷" in description or "damage reduction" in description.to_lower()): notes.append((GameText.text("text.unit_inspection_data.20",{},en)) % number(reduction*100))
	if e.troop.has_tag(&"boss"): notes.append(GameText.text("text.unit_inspection_data.21",{},en))
	return {"name":e.troop.localized_name(),"kind":" · ".join(types),"stats":stats,"notes":" · ".join(notes),"icon":e.troop.icon,"color":e.troop.icon_color(),"health":100.0*e.health/e.max_health}
