class_name EnemyConstants
extends RefCounted
## Shared defaults. Wave exports remain editable per scene in the Inspector.

const WAVE_SIZE := 64
const BATCH_SIZE := 1
const SPAWN_INTERVAL := 0.2
const MOVE_SPEED := 2.5
const GROUND_OFFSET := 0.025
const MAX_HEALTH := 100.0
# Finite local representatives for all troops, never all simple paths.
const CANDIDATE_LOCAL_SAMPLES := 4
