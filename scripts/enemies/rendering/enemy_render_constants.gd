class_name EnemyRenderConstants
extends RefCounted
## Shared rendering defaults: gait, smooth turns, batch capacity and visual spacing.

const TURN_SHARPNESS := 12.0
const WALK_PHASE_PER_UNIT := 13.0
const LEG_SWING := 0.3
const ARM_SWING := 0.2
const BODY_BOB := 0.026
const BODY_SWAY := 0.025
const INITIAL_CAPACITY := 64
const VISUAL_SPACING := 0.36
const VISUAL_MAX_OFFSET := 0.22
const VISUAL_SEPARATION_INTERVAL := 0.1
const VISUAL_SEPARATION_ITERATIONS := 2
const VISUAL_SAMPLES_PER_TILE := 2
## Critically damped response: about 0.8 seconds to settle, without a snap back.
const VISUAL_OFFSET_SMOOTH_TIME := 0.35
## Resume visual separation when the displayed heading is within this angle.
const VISUAL_TURN_TOLERANCE_DEGREES := 5.0
