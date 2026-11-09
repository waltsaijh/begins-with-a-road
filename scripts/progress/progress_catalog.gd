class_name ProgressCatalog
extends RefCounted
## Reads tower, enemy and relic entries from their Resources for the progress page.
## Same towers and order as card_shop.tscn; tests/menus/progress_page.gd keeps them in step.
const TOWERS: Array[TowerDefinition] = [
	preload("res://assets/data/towers/sentry.tres"),
	preload("res://assets/data/towers/mortar.tres"),
	preload("res://assets/data/towers/ballista.tres"),
	preload("res://assets/data/towers/broadside.tres"),
	preload("res://assets/data/towers/crossfire.tres"),
	preload("res://assets/data/towers/barracks.tres"),
]
const CodexText = preload("res://scripts/enemies/presentation/enemy_codex_text.gd")
const BodyVisual = preload("res://scripts/towers/body_visual.gd")
## Tower art is an alpha mask, tinted like the hand and shop icons.
const TOWER_ICON_DARKENING := 0.45
const RELICS: RelicCatalog = preload("res://assets/data/relics/catalog.tres")

static func sections() -> Array[Dictionary]:
	return [
		{"label": "ui.progress.towers", "entries": towers()},
		{"label": "ui.progress.enemies", "entries": enemies()},
		{"label": "ui.progress.relics", "entries": relics()},
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

static func relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic in RELICS.entries: result.append(_relic_entry(relic))
	return result

## The tower as it first appears on the map, for a preview in its own world.
static func tower_model(definition: TowerDefinition) -> Node3D:
	var preset := definition.first_tile_preset()
	var body: Array[Vector2i] = definition.footprint
	if preset != null and not preset.tower_footprint.is_empty(): body = preset.tower_footprint
	var model := BodyVisual.create(definition, body)
	BodyVisual.set_level(model, 1)
	return model

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
		"tower": definition, "description": TranslationServer.translate("tower.%s.description" % id), "stats": stats,
		"traits": TranslationServer.translate("tower.%s.traits" % id).split("|", false)}

static func _enemy_entry(profile: Troop) -> Dictionary:
	var progress := (Engine.get_main_loop() as SceneTree).root.get_node("LevelProgress")
	if not progress.enemy_unlocked(profile.troop_name):
		return {"id": profile.troop_name, "name": "???", "icon": null, "tile": Color.TRANSPARENT,
			"description": GameText.text("text.progress_catalog.global_1"),
			"stats": PackedStringArray(), "traits": PackedStringArray()}
	var stats := PackedStringArray([_stat("health", profile.max_health)])
	if profile.max_shield > 0.0: stats.append(_stat("shield", profile.max_shield))
	stats.append(_stat("speed", profile.speed_multiplier))
	stats.append(TranslationServer.translate("ui.progress.size.%s" % profile.body_size))
	var traits := PackedStringArray()
	for tag in profile.tags:
		if tag != &"ground": traits.append(TranslationServer.translate("ui.progress.tag.%s" % tag))
	if profile.damage_reduction > 0.0: traits.append(_stat("reduction", profile.damage_reduction*100.0))
	var detail := CodexText.description(profile)
	return {"id": profile.troop_name, "name": profile.localized_name(), "icon": profile.icon, "tile": Color.TRANSPARENT, "tint": profile.icon_color(),
		"troop": profile, "detail": detail,
		"description": detail, "stats": stats, "traits": traits}

## Generic relics keep their icon's own colors, as they do in a run.
static func _relic_entry(relic: RelicDefinition) -> Dictionary:
	var stats := PackedStringArray()
	if relic.repeatable: stats.append(_stat("stacks", relic.max_stacks))
	var entry := {"id": String(relic.id), "name": TranslationServer.translate(relic.name_key), "icon": relic.icon, "tile": Color.TRANSPARENT,
		"usage": relic.usage_text(), "usage_color": relic.icon_color(),
		"description": relic.localized_description(), "stats": stats, "traits": PackedStringArray()}
	if relic.tower != null: entry.tint = relic.icon_color()
	return entry

static func _stat(key: String, value: float) -> String:
	return TranslationServer.translate("ui.progress.stat.%s" % key).format({"value": str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))})
