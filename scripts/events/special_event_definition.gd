@tool
class_name SpecialEventDefinition
extends Resource
## Two editable effect lists. Prose is in the common bilingual text catalog.
@export var id: StringName
@export var option_a: Array[Dictionary] = []
@export var option_b: Array[Dictionary] = []

func effects(index: int) -> Array[Dictionary]:
	return option_a if index == 0 else option_b

func text(suffix: String) -> String:
	var values := {}
	for index in 2:
		for effect in effects(index):
			for key in effect:
				if key != "type": values[("a_" if index == 0 else "b_")+key] = effect[key]
			if effect.type == "card":
				var card: SpecialCardDefinition = load("res://assets/data/events/cards/%s.tres" % effect.id)
				var prefix := "a_" if index == 0 else "b_"
				values[prefix+"damage_percent"] = roundi(card.damage_bonus*100)
				values[prefix+"penalty_percent"] = roundi((1.0-card.incomplete_damage_multiplier)*100)
				values[prefix+"wave_gold"] = card.wave_gold
	return GameText.text("event.%s.%s" % [id, suffix], values)
