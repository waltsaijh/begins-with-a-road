@tool
class_name WaveSpawnGroup
extends Resource
## Authored times are integer quarter-second ticks, relative to wave start.
const TICK_SECONDS := 0.25
## File reference lets a deleted troop be replaced without breaking the level file.
@export_file("*.tres") var troop_path := "":
	set(value):
		if troop_path != value:
			troop_path = value
			_inline_troop = null
			emit_changed()
## Inline profiles are supported for custom runtime/test recipes.
@export_storage var _inline_troop: Troop
var troop: Troop:
	get:
		return TroopCatalog.load_path(troop_path) if not troop_path.is_empty() else _inline_troop
	set(value):
		if value != null and not value.resource_path.is_empty() and not "::" in value.resource_path:
			troop_path = value.resource_path
			_inline_troop = null
		else:
			troop_path = ""
			_inline_troop = value
		emit_changed()
@export_range(0, 14400, 1, "or_greater") var start_tick := 0
@export_range(1, 500, 1, "or_greater") var enemy_count := 10
@export_range(1, 100, 1, "or_greater") var batch_size := 1
@export_range(0, 240, 1, "or_greater") var interval_ticks := 1
@export_range(0, 32, 1) var start_index := 0

@warning_ignore("integer_division")
func spawn_tick(index: int) -> int:
	return start_tick+(index/batch_size)*interval_ticks

func end_tick() -> int:
	return spawn_tick(enemy_count-1) if enemy_count > 0 and batch_size > 0 else start_tick

func count_at(tick: int) -> int:
	if tick < start_tick or batch_size < 1: return 0
	if interval_ticks == 0: return enemy_count
	@warning_ignore("integer_division")
	var batches := (tick-start_tick)/interval_ticks+1
	return mini(enemy_count, batches*batch_size)

func configuration_error() -> String:
	if troop == null: return "出生群組缺少兵種："+troop_path
	var error := troop.configuration_error()
	if not error.is_empty(): return error
	if start_tick < 0 or interval_ticks < 0: return "開始刻度與間隔不可小於 0"
	if enemy_count < 1 or batch_size < 1: return "出生數量與批次大小必須大於 0"
	if start_index < 0: return "入口索引不可小於 0"
	return ""
