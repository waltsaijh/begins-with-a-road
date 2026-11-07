class_name ProgressCatalog
extends RefCounted
## Reads tower and enemy entries from their Resources for the progress page.
## Same towers and order as card_shop.tscn; tests/menus/progress_page.gd keeps them in step.
const TOWERS: Array[TowerDefinition] = [
	preload("res://assets/data/towers/sentry.tres"),
	preload("res://assets/data/towers/mortar.tres"),
	preload("res://assets/data/towers/ballista.tres"),
	preload("res://assets/data/towers/broadside.tres"),
	preload("res://assets/data/towers/crossfire.tres"),
	preload("res://assets/data/towers/barracks.tres"),
]
## Enemy art keeps its own colors, some of them white, so it needs a dark tile.
const ENEMY_TILE := Color(0.2, 0.36, 0.38)
## Tower art is an alpha mask, tinted like the hand and shop icons.
const TOWER_ICON_DARKENING := 0.45

static func sections() -> Array[Dictionary]:
	return [
		{"label": "ui.progress.towers", "entries": towers()},
		{"label": "ui.progress.enemies", "entries": enemies()},
	]

static func towers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in TOWERS: result.append(_tower_entry(definition))
	return result

static func enemies() -> Array[Dictionary]:
	var profiles := TroopCatalog.all()
	profiles.sort_custom(func(a: Troop, b: Troop) -> bool:
		return a.troop_name < b.troop_name if a.sort_order == b.sort_order else a.sort_order < b.sort_order)
	var result: Array[Dictionary] = []
	for profile in profiles: result.append(_enemy_entry(profile))
	return result

static func _tower_entry(definition: TowerDefinition) -> Dictionary:
	var id := definition.name_key.get_slice(".", 1)
	var deployment := definition.deployment
	var stats := PackedStringArray([
		_stat("damage", deployment.damage if deployment != null else definition.default_damage),
		_stat("interval", deployment.interval if deployment != null else definition.attack_interval),
		TranslationServer.translate("ui.progress.stat.range_shaped") if definition.attack_area != null else _stat("range", definition.attack_radius),
		_stat("price", definition.card_price),
	])
	return {"id": id, "name": TranslationServer.translate(definition.name_key), "icon": definition.icon, "tile": Color.TRANSPARENT, "tint": definition.accent_color.darkened(TOWER_ICON_DARKENING),
		"description": TranslationServer.translate("tower.%s.description" % id), "stats": stats,
		"traits": TranslationServer.translate("tower.%s.traits" % id).split("|", false)}

static func _enemy_entry(profile: Troop) -> Dictionary:
	var stats := PackedStringArray([_stat("health", profile.max_health)])
	if profile.max_shield > 0.0: stats.append(_stat("shield", profile.max_shield))
	stats.append(_stat("speed", profile.speed_multiplier))
	stats.append(TranslationServer.translate("ui.progress.size.%s" % profile.body_size))
	var traits := PackedStringArray()
	for tag in profile.tags:
		if tag != &"ground": traits.append(TranslationServer.translate("ui.progress.tag.%s" % tag))
	if profile.damage_reduction > 0.0: traits.append(_stat("reduction", profile.damage_reduction*100.0))
	if profile.route_rule != Troop.RouteRule.COST: traits.append(profile.route_description())
	var english := TranslationServer.get_locale().begins_with("en")
	return {"id": profile.troop_name, "name": profile.localized_name(), "icon": profile.icon, "tile": ENEMY_TILE,
		"description": profile.ability_text_en if english else profile.ability_text, "stats": stats, "traits": traits}

static func _stat(key: String, value: float) -> String:
	return TranslationServer.translate("ui.progress.stat.%s" % key).format({"value": str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))})
