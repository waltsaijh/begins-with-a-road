extends SceneTree
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
var failures: Array[String] = []
var checks := 0
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	var soldier := TroopCatalog.find("soldier")
	var quick := TroopCatalog.find("quickfeet")
	var heavy := TroopCatalog.find("heavy")
	check(soldier.has_tag(&"standard") and soldier.has_tag(&"ground"), "soldier tags")
	check(quick.has_tag(&"small") and not quick.has_tag(&"large"), "quick tags")
	check(heavy.has_tag(&"large") and heavy.has_tag(&"armored"), "heavy tags")
	var legacy := Troop.new()
	check(legacy.has_tag(&"standard") and legacy.has_tag(&"ground"), "missing tags safe defaults")
	legacy.tags = [&"small", &"large", &"flying", &"uncontrollable"]
	check(not legacy.has_tag(&"small") and not legacy.has_tag(&"large") and legacy.has_tag(&"flying"),"size remains exclusive even with conflicting free tags")
	var routes := [{"entry": {"route": {"cells": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO])}}}, {"entry": {"route": {"cells": PackedVector2Array([Vector2.DOWN])}}}]
	var barricade: TrafficStructureDefinition = load("res://assets/data/traffic/barricade.tres")
	var effect := barricade.effect_at(Vector2i.ZERO,0)
	effect.cells[Vector2i.RIGHT] = true
	var logs := TrafficWeights.log_multipliers(routes, quick, [effect])
	check(is_equal_approx(exp(logs[0]), 0.5), "once per structure even repeated cells")
	check(TrafficWeights.log_multipliers(routes, soldier, [effect])[0] == 0.0, "barricade excludes standard units in Phase 4")
	check(TrafficWeights.log_multipliers(routes, heavy, [effect])[0] == 0.0, "barricade excludes large units")
	var armored_standard := Troop.new()
	armored_standard.tags = [&"ground", &"armored"]
	check(TrafficWeights.log_multipliers(routes, armored_standard, [effect])[0] == 0.0, "armored standard is neither small nor large")
	var explicit_filter := effect.duplicate(true)
	explicit_filter.tags = [&"ground"]
	check(TrafficWeights.log_multipliers(routes, legacy, [explicit_filter])[0] == 0.0,"required and excluded tag filters compose")
	check(is_equal_approx(exp(TrafficWeights.log_multipliers(routes, quick, [effect,effect])[0]), 0.25), "multiplicative stack")
	var flag := effect.duplicate(true)
	flag.tags = [&"ground"]
	flag.excluded_tags = []
	flag.multiplier = 1.5
	check(is_equal_approx(exp(TrafficWeights.log_multipliers(routes, quick, [effect,flag])[0]), 0.75), "mixed stack")
	check(TrafficWeights.log_multipliers(routes, legacy, [flag])[0] == 0.0,"flag excludes flying without ground tag")
	var narrow := effect.duplicate(true)
	narrow.tags = [&"large"]
	narrow.excluded_tags = []
	check(is_equal_approx(exp(TrafficWeights.log_multipliers(routes, heavy, [narrow])[0]), 0.5), "large only")
	for mode in [Troop.RouteSelection.UNIFORM, Troop.RouteSelection.SOFTMAX]:
		var result := Distribution.build(PackedFloat64Array([0,0]), 1.0, mode, logs)
		check(result.valid and is_equal_approx(result.probabilities[0], 1.0/3), "normalized weights")
		var counts := [0,0]
		for i in 30: counts[Distribution.allocate(result.cdf,i,30)] += 1
		check(counts == [10,20], "integer quotas")
	var soft := Distribution.build(PackedFloat64Array([0,1]),1.0,Troop.RouteSelection.SOFTMAX,logs)
	check(is_equal_approx(soft.probabilities[0], 0.5/(0.5+exp(-1.0))), "preserve softmax cost")
	var only := Distribution.build(PackedFloat64Array([0]),1.0,Troop.RouteSelection.UNIFORM,PackedFloat64Array([log(0.5)]))
	check(only.probabilities[0] == 1.0, "no invented route")
	var large := Distribution.build(PackedFloat64Array([0,0]),1.0,Troop.RouteSelection.UNIFORM,PackedFloat64Array([10000,9999]))
	check(large.valid and is_finite(large.probabilities[0]), "stable large products")
	check(not Distribution.build(PackedFloat64Array([0]),1.0,0,PackedFloat64Array([-INF])).valid, "zero mass is invalid")
	for id in ["flag","barricade","narrow_passage"]:
		var definition: TrafficStructureDefinition = load("res://assets/data/traffic/"+id+".tres")
		check(definition.duration_waves == 3 and definition.weight_multiplier == (1.5 if id == "flag" else 0.5),"authored MVP defaults "+id)
	var result := {"checks":checks,"failures":failures}
	FileAccess.open(Artifacts.path("traffic/weights.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PHASE2_WEIGHTS:",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
