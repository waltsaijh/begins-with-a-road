@tool
class_name WaveDefinition
extends Resource
## A wave contains overlapping spawn groups; runtime progress belongs to EnemyWave.
@export var groups: Array[WaveSpawnGroup] = []
@export_range(0.1, 20.0, 0.1, "or_greater") var move_speed := EnemyConstants.MOVE_SPEED
@export_range(0, 100, 1, "or_greater") var reward := ShopConstants.WAVE_REWARD

func configuration_error() -> String:
	if groups.is_empty(): return "每波至少需要一個出生群組"
	for group in groups:
		if group == null: return "缺少出生群組"
		var error := group.configuration_error()
		if not error.is_empty(): return error
	if not is_finite(move_speed) or move_speed <= 0: return "Invalid move speed"
	if reward < 0: return "Invalid wave reward"
	return ""

func total_count() -> int:
	var result := 0
	for group in groups:
		if group != null: result += group.enemy_count
	return result

func last_spawn_tick() -> int:
	var result := 0
	for group in groups:
		if group != null: result = maxi(result, group.end_tick())
	return result
