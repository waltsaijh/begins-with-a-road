@tool
class_name TrafficStructureDefinition
extends Resource
## An overlay is never a navigation obstacle. Each instance affects a trip once.
enum Placement { NEAR_ROAD, ON_ROAD }
@export var name_key := ""
@export var effect_key := ""
@export var model: PackedScene
@export var icon: Texture2D
@export var accent_color := Color("b6b88b")
@export_range(0, 100, 1, "or_greater") var card_price := 3
@export_range(1, 100, 1) var duration_waves := 3
@export var placement: Placement = Placement.ON_ROAD
## All tags must match. Empty matches every troop; no implicit flying exception.
@export var required_tags: Array[StringName] = []
## Any matching tag excludes the troop, even if all required tags match.
@export var excluded_tags: Array[StringName] = []
@export_range(0.0, 10.0, 0.05, "or_greater") var weight_multiplier := 0.5
@export var influence_offsets: Array[Vector2i] = [Vector2i.ZERO]
## These groups may coexist only if BOTH definitions explicitly permit it.
@export var occupancy_group: StringName = &"traffic"
@export var compatible_groups: Array[StringName] = []

func localized_name() -> String:
	return tr(name_key)

func configuration_error() -> String:
	if model == null or influence_offsets.is_empty(): return "輔助建築缺少模型或影響範圍"
	if not is_finite(weight_multiplier) or weight_multiplier < 0: return "選路倍率必須為有限非負值"
	if duration_waves < 1: return "持續波數必須大於零"
	return ""

func effect_at(at: Vector2i, turns: int) -> Dictionary:
	var cells := {}
	for offset in influence_offsets: cells[at+BuildCard.rotate_cell(offset, turns)] = true
	return {"cells": cells, "tags": required_tags.duplicate(), "excluded_tags": excluded_tags.duplicate(), "multiplier": weight_multiplier}

func can_share(other: TrafficStructureDefinition) -> bool:
	return other.occupancy_group in compatible_groups and occupancy_group in other.compatible_groups
