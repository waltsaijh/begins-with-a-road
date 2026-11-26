extends RefCounted

const ATLAS = preload("res://assets/sprites/events/option_art.svg")
const TILE := Vector2(176, 106)
const SAGE := Color("e5ebe0")
const TEAL := Color("e0eae5")
const GOLD := Color("f0e9d8")
const CLAY := Color("ede5dd")
const FIRST_CELL := {
	&"scouts": 0, &"supplies": 2, &"merchant": 4,
	&"conscription": 6, &"storm": 8, &"altar": 10,
	&"strike": 12, &"payroll": 14, &"gem": 16,
}
const MATS := [
	TEAL, SAGE, SAGE, CLAY, GOLD, GOLD,
	TEAL, SAGE, TEAL, CLAY, CLAY, GOLD,
	GOLD, CLAY, GOLD, SAGE, TEAL, TEAL, SAGE,
]

static func illustration(event_id: StringName, option: int) -> AtlasTexture:
	var cell := _cell(event_id, option)
	var image := AtlasTexture.new()
	image.atlas = ATLAS
	image.region = Rect2(Vector2(cell % 6, floori(cell / 6.0)) * TILE, TILE)
	image.filter_clip = true
	return image

static func mat_color(event_id: StringName, option: int) -> Color:
	return MATS[_cell(event_id, option)]

static func _cell(event_id: StringName, option: int) -> int:
	return int(FIRST_CELL[event_id]) + option if FIRST_CELL.has(event_id) and option in [0, 1] else 18
