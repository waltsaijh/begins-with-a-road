class_name TileAppearanceConstants
extends RefCounted
## Shared visual defaults, directly accessible without loading a Resource.
## Placement distances use the XZ grid; the radius boundary is excluded.

const SEED_VALUE := 1729
const PILLAR_RADIUS := 3.0
const TILES_PER_WOOD_BRIDGE := 16
const WOOD_SPACING := 2.0

const ANIMATE := true
const ANIMATION_DURATION := 0.5
const RISE_DEPTH := 0.75

static func drop_offset(progress: float, height: float) -> float:
	var t := clampf(progress,0.0,1.0)
	if t <= 0.72: return height*(1.0-pow(t/0.72,2))
	var rebound := (t-0.72)/0.28
	return height*0.13*4.0*rebound*(1.0-rebound)
