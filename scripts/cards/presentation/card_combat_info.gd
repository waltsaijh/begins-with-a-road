extends RefCounted
## Base card values come from combat resources, before placement bonuses.
static func data(definition: TowerDefinition) -> Dictionary:
	var en := TranslationServer.get_locale().begins_with("en")
	var deployment := definition.deployment
	var damage := deployment.damage if deployment != null else definition.default_damage*(definition.attack.damage_multiplier if definition.attack != null else 1.0)
	var interval := deployment.interval if deployment != null else definition.attack_interval
	var pace := "fast" if interval <= 0.6 else ("medium" if interval <= 1.2 else ("slow" if interval <= 2.0 else "very_slow"))
	var description_key := definition.name_key.trim_suffix(".name")+".description"
	var description := TranslationServer.translate(description_key)
	if description == description_key: description = GameText.text("text.card_combat_info.1",{},en)
	var range_key := "directional"
	if deployment != null: range_key = "garrison"
	elif definition.attack is VolleyAttack:
		if definition.attack.gun_lines: range_key = "guns"
		elif definition.attack.circular_range: range_key = "around"
	elif definition.attack_area == null: range_key = "around"
	return {"name":definition.localized_name(),"damage":roundi(damage),"pace":pace,
		"stats":(GameText.text("text.card_combat_info.2",{},en)) % roundi(damage) if deployment != null else (GameText.text("text.card_combat_info.3",{},en)) % roundi(damage),
		"speed":TranslationServer.translate("card.info.speed")+"  "+TranslationServer.translate("card.info.speed."+pace),
		"range":TranslationServer.translate("card.info.range")+"  "+TranslationServer.translate("card.info.range."+range_key),
		"description":description}
