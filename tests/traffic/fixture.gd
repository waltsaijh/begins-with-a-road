extends RefCounted
const Base = preload("res://tests/levels/road_flow_fixture.gd")
static func definition() -> LevelDefinition:
	var result := Base.level()
	result.expand_starts_after_act = false
	var wave := WaveDefinition.new()
	for origin in 2:
		for id in ["soldier","quickfeet","heavy"]:
			wave.groups.append(Base.group(TroopCatalog.find(id).duplicate(),30,origin))
	var first := ActDefinition.new()
	first.waves = [wave,wave]
	var second := ActDefinition.new()
	second.waves = [wave,wave]
	result.acts = [first,second]
	return result
static func session() -> Node3D:
	var result: Node3D = load("res://scenes/level.tscn").instantiate()
	result.level = definition()
	var cards: Node = result.get_node("CardPlacement")
	cards.cards.clear()
	for id in ["flag","barricade","narrow_passage"]:
		cards.cards.append(BuildCard.from_traffic(load("res://assets/data/traffic/"+id+".tres")))
	return result
