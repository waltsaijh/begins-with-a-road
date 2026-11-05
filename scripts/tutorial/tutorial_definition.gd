@tool
class_name TutorialDefinition
extends Resource
## Authored teaching recipes; progression and input gates belong to the director.
@export var starting_cards: Array[BuildCard] = []
@export var guided_cells: Array[Vector3i] = []
@export var guided_turns := PackedInt32Array([0,1])
@export var upgrade_card: BuildCard
@export var new_card: BuildCard

func configuration_error() -> String:
	if starting_cards.size() != 3 or guided_cells.size() != 2 or guided_turns.size() != 2: return "Tutorial needs three cards and two guided placements"
	for card in starting_cards:
		if card == null or not card.configuration_error().is_empty() or card.tower == null: return "Invalid tutorial starting card"
	if upgrade_card == null or new_card == null: return "Tutorial shop cards are missing"
	if not upgrade_card.configuration_error().is_empty() or not new_card.configuration_error().is_empty(): return "Invalid tutorial shop card"
	if upgrade_card.tower == null or new_card.tower == null: return "Tutorial purchases must be tower cards"
	var has_upgrade_tower := false
	for card in starting_cards:
		if card.tower == upgrade_card.tower: has_upgrade_tower = true
		if card.tower == new_card.tower: return "New tutorial tower must not appear in the starting hand"
	if not has_upgrade_tower: return "Upgrade tower must appear in the starting hand"
	return ""
