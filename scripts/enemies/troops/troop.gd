@tool
class_name Troop
extends Resource
## Editable troop definition. Instances keep health, routes and visual state separately.
const TileRecord = preload("res://scripts/map/tile/tile_parameters.gd")
enum RouteSelection { UNIFORM, SOFTMAX }
enum RouteRule { COST, SHORTEST, NEWEST }
## Hard eligibility precedes Uniform/Softmax and traffic weights.
@export var route_rule: RouteRule = RouteRule.COST:
	set(value):
		route_rule = value
		emit_changed()
@export_group("Cohort")
@export_range(1, 64, 1) var cohort_size := 1
@export_range(1, 16, 1) var cohort_interval_ticks := 1
@export_group("Abilities")
@export_range(0.0, 0.9, 0.05) var damage_reduction := 0.0
@export_range(0.0, 10.0, 0.1) var taunt_radius := 0.0
@export_range(0, 10, 1) var taunt_priority := 1
@export_range(0.0, 1000.0, 1.0) var heal_amount := 0.0
@export_range(0.1, 20.0, 0.1) var heal_interval := 3.0
@export_range(0.0, 10.0, 0.1) var heal_radius := 2.0
@export_range(0.0, 10.0, 0.1) var sabotage_radius := 0.0
@export_range(0.1, 30.0, 0.1) var sabotage_interval := 6.0
@export_range(0.1, 5.0, 0.1) var sabotage_windup := 1.0
@export_range(0.1, 10.0, 0.1) var sabotage_duration := 2.5
@export_range(0.0, 5.0, 0.1) var flight_height := 0.0
@export_group("Intelligence")
@export_multiline var ability_text := ""
@export_multiline var ability_text_en := ""
@export_group("")
## One mutually exclusive size, plus composable movement/trait tags.
@export_enum("small", "standard", "large") var body_size := "standard":
	set(value):
		body_size = value
		emit_changed()
@export var tags: Array[StringName] = [&"ground"]:
	set(value):
		tags = value
		emit_changed()

func has_tag(tag: StringName) -> bool:
	return tag == StringName(body_size) or (tag not in [&"small", &"standard", &"large"] and tag in tags)

@export var troop_name := "new_troop"
@export var name_key := ""
@export var sort_order := 100
@export var icon: Texture2D
## Contact combat only. Zero means no authored melee damage for a new profile.
@export var melee_damage := 0.0
@export var melee_interval := 1.0
@export var debug_color := Color("40d9ff")
@export_range(1.0, 10000.0, 1.0, "or_greater") var max_health := EnemyConstants.MAX_HEALTH:
	set(value):
		if is_finite(value) and value > 0 and max_health != value:
			max_health = value
			emit_changed()
@export_range(0.1, 5.0, 0.1, "or_greater") var speed_multiplier := 1.0:
	set(value):
		if is_finite(value) and value > 0 and speed_multiplier != value:
			speed_multiplier = value
			emit_changed()
@export_range(0.0, 10000.0, 1.0, "or_greater") var max_shield := 0.0:
	set(value):
		if is_finite(value) and value >= 0 and max_shield != value:
			max_shield = value
			emit_changed()
## INF disables the score cutoff. A finite value can restore it for comparisons.
@export var score_threshold := INF:
	set(value):
		if score_threshold != value:
			score_threshold = value
			emit_changed()

## Select among complete candidates after the strict score threshold filter.
@export var route_selection: RouteSelection = RouteSelection.SOFTMAX:
	set(value):
		if route_selection != value:
			route_selection = value
			emit_changed()

## Used only by Softmax. INF also gives uniform sampling for compatibility.
@export_range(0.01, 100.0, 0.1, "or_greater") var route_temperature := 4.0:
	set(value):
		if route_temperature != value:
			route_temperature = value
			emit_changed()

## Cost added per physical step and previous search use; never affects true score.
@export_range(0.0, 10.0, 0.1, "or_greater") var overlap_penalty := 1.0:
	set(value):
		if overlap_penalty != value:
			overlap_penalty = value
			emit_changed()
## Search work limit, not a request for the best K routes.
@export_range(1, 256, 1) var search_budget := 64:
	set(value):
		if search_budget != value:
			search_budget = value
			emit_changed()

@export_group("Path Evaluation")
## Per-tile score = base cost + weighted tile properties. Negative weights are supported.
@export var path_base_cost := 1.0:
	set(value):
		if path_base_cost != value:
			path_base_cost = value
			emit_changed()
@export var threat_weight := 0.0:
	set(value):
		if threat_weight != value:
			threat_weight = value
			emit_changed()
@export var tower_count_weight := 0.0:
	set(value):
		if tower_count_weight != value:
			tower_count_weight = value
			emit_changed()
@export var movement_weight := 0.0:
	set(value):
		if movement_weight != value:
			movement_weight = value
			emit_changed()
@export var damage_weight := 0.0:
	set(value):
		if damage_weight != value:
			damage_weight = value
			emit_changed()
@export var cover_weight := 0.0:
	set(value):
		if cover_weight != value:
			cover_weight = value
			emit_changed()

@export_group("Model")
## Drag an imported .glb/.gltf scene or a local .tscn here. Empty uses the built-in grunt.
@export var model: PackedScene
@export var model_scale := Vector3.ONE
@export var model_offset := Vector3.ZERO
@export var model_rotation_degrees := Vector3.ZERO
## Empty auto-selects a walk/run animation, if present in the imported scene.
@export var walk_animation: StringName
@export_range(0.01, 10.0, 0.01, "or_greater") var animation_speed := 1.0
## 0 measures the model automatically. Positive values override its head height.
@export_range(0.0, 20.0, 0.01, "or_greater") var head_height := 0.0

func localized_name() -> String:
	if name_key.is_empty(): return troop_name
	var text := tr(name_key)
	# The editor may not load the project's translations into its own domain.
	return troop_name if text == name_key else text

func configuration_error() -> String:
	if cohort_size < 1 or cohort_interval_ticks < 1: return "群體大小與群內間隔必須為正整數"
	if route_rule not in [RouteRule.COST, RouteRule.SHORTEST, RouteRule.NEWEST]: return "未知的硬性選路規則"
	for value in [damage_reduction, taunt_radius, heal_amount, heal_radius, sabotage_radius, flight_height]:
		if not is_finite(value) or value < 0: return "敵軍能力數值必須非負且有限"
	if damage_reduction >= 1: return "防禦減傷不可達到 100%"
	for value in [heal_interval, sabotage_interval, sabotage_windup, sabotage_duration]:
		if not is_finite(value) or value <= 0: return "敵軍能力時間必須為正有限數值"
	if not is_finite(melee_damage) or melee_damage < 0 or not is_finite(melee_interval) or melee_interval <= 0: return "兵種近戰反擊設定無效"
	if troop_name.strip_edges().is_empty(): return "兵種缺少 ID"
	if not is_finite(max_health) or max_health <= 0 or not is_finite(speed_multiplier) or speed_multiplier <= 0: return "兵種血量與速度必須大於 0"
	if not is_finite(max_shield) or max_shield < 0: return "兵種護盾不可小於 0"
	for value in [path_base_cost, threat_weight, tower_count_weight, movement_weight, damage_weight, cover_weight]:
		if not is_finite(value): return "兵種尋路權重必須為有限數值"
	if not model_scale.is_finite() or model_scale.x <= 0 or model_scale.y <= 0 or model_scale.z <= 0: return "模型縮放必須大於 0"
	if not model_offset.is_finite() or not model_rotation_degrees.is_finite(): return "模型位置／旋轉設定無效"
	if not is_finite(animation_speed) or animation_speed <= 0 or not is_finite(head_height) or head_height < 0: return "模型動畫速度／頭頂高度設定無效"
	if model != null:
		if not ClassDB.is_parent_class(_model_root_type(), "Node3D"): return "兵種模型場景的根節點必須為 Node3D"
	return ""

func _model_root_type() -> StringName:
	var state := model.get_state()
	while state != null and state.get_node_count() > 0:
		var kind := state.get_node_type(0)
		if not kind.is_empty(): return kind
		var base := state.get_base_scene_state()
		if base != null:
			state = base
		else:
			var instance := state.get_node_instance(0)
			state = instance.get_state() if instance != null else null
	return &""

func evaluation(tile: TileRecord) -> float:
	var score := path_base_cost
	if threat_weight != 0: score += tile.threat*threat_weight
	if tower_count_weight != 0: score += tile.num_towers_around*tower_count_weight
	if movement_weight != 0: score += tile.movement_multiplier*movement_weight
	if damage_weight != 0: score += tile.damage_per_second*damage_weight
	if cover_weight != 0: score += tile.cover*cover_weight
	return score

func ability_snapshot() -> Dictionary:
	return {"damage_reduction":damage_reduction, "taunt_radius":taunt_radius, "taunt_priority":taunt_priority,
		"heal_amount":heal_amount, "heal_interval":heal_interval, "heal_radius":heal_radius,
		"sabotage_radius":sabotage_radius, "sabotage_interval":sabotage_interval,
		"sabotage_windup":sabotage_windup, "sabotage_duration":sabotage_duration}

func route_description() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	if route_rule == RouteRule.SHORTEST: return "Shortest roads only; ignores ground lures." if english else "只走實際最短道路；不受地面設施誘導。"
	if route_rule == RouteRule.NEWEST: return "Newest surviving routes only; lures apply within that set." if english else "只走最新一批仍有效的路線；設施只影響合格路線比例。"
	var text := "Uniform" if route_selection == RouteSelection.UNIFORM else "Softmax"
	if cohort_size > 1: text += (" · %d per cohort" if english else " · 每群 %d 隻同路") % cohort_size
	return text

func intelligence_text() -> String:
	var english := TranslationServer.get_locale().begins_with("en")
	return "%s · %s\n\n%s\n\n%s" % [body_size, ", ".join(tags), ability_text_en if english else ability_text, route_description()]
