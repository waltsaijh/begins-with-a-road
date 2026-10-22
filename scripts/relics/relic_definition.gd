@tool
class_name RelicDefinition
extends Resource
## Authored reward and composable rule parameters; never stores run state.
@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var tower: TowerDefinition
@export var parameters: Dictionary = {}
@export var repeatable := false
@export_range(1, 20) var max_stacks := 1

func configuration_error() -> String:
	if id.is_empty() or name_key.is_empty() or description_key.is_empty() or icon == null: return "遺物資料不完整"
	if max_stacks < 1 or (not repeatable and max_stacks != 1): return "遺物持有上限無效"
	for value in parameters.values():
		if (value is float or value is int) and not is_finite(float(value)): return "遺物參數必須有限"
	return ""
