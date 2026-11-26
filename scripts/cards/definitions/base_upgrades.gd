extends RefCounted

const TIERS := [
	["heavy", "wizard", "marksman", "station", "supply"],
	["mixed", "flank", "garrison", "united", "response"],
	["double", "rally", "snipe", "last"]
]
const SPELLS := {
	"heavy": preload("res://assets/data/spells/cannon.tres"),
	"wizard": preload("res://assets/data/spells/lightning.tres"),
	"station": preload("res://assets/data/spells/reinforce.tres"),
	"supply": preload("res://assets/data/spells/support.tres"),
	"mixed": preload("res://assets/data/spells/delayed.tres"),
	"flank": preload("res://assets/data/spells/volley.tres"),
	"garrison": preload("res://assets/data/spells/fortify.tres"),
	"united": preload("res://assets/data/spells/bind.tres"),
	"response": preload("res://assets/data/spells/reinforce.tres"),
	"double": preload("res://assets/data/spells/double.tres"),
	"rally": preload("res://assets/data/spells/rally.tres"),
	"snipe": preload("res://assets/data/spells/snipe.tres"),
	"last": preload("res://assets/data/spells/last.tres"),
}

static func counts(tower_map: Node) -> Dictionary:
	var result := {}
	for tower: DefenseTower in tower_map.towers.values():
		if tower.definition == null or tower.health <= 0 or tower.is_queued_for_deletion(): continue
		var id := tower.definition.name_key.get_slice(".", 1)
		result[id] = result.get(id, 0) + 1
	return result

static func eligible(id: String, counts_by_type: Dictionary) -> bool:
	var mortar := int(counts_by_type.get("mortar", 0))
	var cross := int(counts_by_type.get("crossfire", 0))
	var sentry := int(counts_by_type.get("sentry", 0))
	var bow := int(counts_by_type.get("ballista", 0))
	var barracks := int(counts_by_type.get("barracks", 0))
	match id:
		"heavy": return mortar + cross >= 2
		"wizard": return counts_by_type.size() >= 5
		"marksman": return bow + sentry >= 4
		"station": return barracks >= 2
		"mixed": return mortar >= 2 and cross >= 2
		"flank": return counts_by_type.get("broadside", 0) >= 2 and sentry + bow >= 2
		"garrison": return barracks >= 3
		"united": return counts_by_type.size() >= 5 and counts_by_type.values().filter(func(n): return n >= 2).size() >= 3
		"double": return mortar + cross >= 6 and mini(mortar, cross) >= 2
		"rally": return counts_by_type.size() >= 6
		"snipe": return sentry + bow >= 7 and mini(sentry, bow) >= 2
		"supply", "response", "last": return true
	return false
