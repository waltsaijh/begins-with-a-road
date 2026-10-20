class_name TileConstants
extends RefCounted
## Shared tile IDs and local ports for placement and physical graph extraction.
## The MeshLibrary contract and tile placement sentinel, directly accessible.

const INVALID_CELL := Vector3i(2147483647, 0, 0)
const DIRECTIONS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
# MeshLibrary IDs: stone, straight, corner, isolated, end, tee, cross.
# Port bits in order: north, east, south, west.
const BASE_MASKS := [0, 5, 3, 0, 1, 11, 15]

enum Appearance { STONE, PILLAR, WOOD }
const BASE_NAMES := ["stone", "road_straight", "road_corner", "road_isolated", "road_end", "road_tee", "road_cross"]
const PILLAR_OFFSET := 6 # Base road IDs 1..6 become 7..12; stone ID 0 stays unchanged.
const WOOD_STRAIGHT := 13
const ITEM_COUNT := 14

static func base_item(item: int) -> int:
	if item == WOOD_STRAIGHT:
		return 1
	return item - PILLAR_OFFSET if item >= 7 and item <= 12 else item

static func appearance_of(item: int) -> Appearance:
	if item == WOOD_STRAIGHT:
		return Appearance.WOOD
	return Appearance.PILLAR if item >= 7 and item <= 12 else Appearance.STONE

static func item_for(base: int, appearance: Appearance) -> int:
	base = base_item(base)
	if base >= 1 and base <= 6:
		if appearance == Appearance.PILLAR:
			return base + PILLAR_OFFSET
		if appearance == Appearance.WOOD and base == 1:
			return WOOD_STRAIGHT
	return base
