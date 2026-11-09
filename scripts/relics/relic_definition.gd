@tool
class_name RelicDefinition
extends Resource
## Authored reward and composable rule parameters; never stores run state.
@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
## Generic icon palette; tower relics share the corresponding tower card color.
@export var accent_color := Color("798c86")
@export var tower: TowerDefinition
@export var parameters: Dictionary = {}
@export var repeatable := false
@export_range(1, 20) var max_stacks := 1

func presentation_color() -> Color:
	return tower.accent_color if tower != null else accent_color

## Darkened like the tower icons, so it stays readable on pale cards.
func icon_color() -> Color:
	return presentation_color().darkened(0.45)

## Where the relic applies: a tower, or any build.
func usage_text() -> String:
	return TranslationServer.translate(tower.name_key if tower != null else "ui.relic.usage.generic")

## One formatted source for rewards, progress, tooltips and owned relic details.
func description_values() -> Dictionary:
	var values := {"max_stacks":str(max_stacks)}
	for key in parameters:
		var value: Variant = parameters[key]
		if value is float or value is int:
			values[key] = _number(float(value))
			values[String(key)+"_percent"] = _number(float(value)*100.0)
			values[String(key)+"_increase"] = _number((float(value)-1.0)*100.0)
			if float(value) > 0: values[String(key)+"_inverse_percent"] = _number(100.0/float(value))
	if parameters.has("strength") and float(parameters.get("maximum_slow",0)) > 0:
		var cap := float(parameters.maximum_slow)
		values["single_slow_percent"] = _number(100.0*cap*(1.0-exp(-float(parameters.strength)/cap)))
	if tower != null:
		if tower.deployment != null: values["unit_count"] = str(tower.deployment.count+int(parameters.get("extra_units",0)))
		if tower.growth != null:
			values["level_cap"] = str(tower.growth.max_level)
			values["growth_damage"] = _number(tower.growth.damage)
			values["growth_interval"] = _number(tower.growth.interval)
	if parameters.has("width"): values["full_width"] = _number(float(parameters.width)*2.0)
	return values

func localized_description() -> String:
	return TranslationServer.translate(description_key).format(description_values())

static func _number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value,roundf(value)) else str(snappedf(value,0.01))

func configuration_error() -> String:
	if id.is_empty() or name_key.is_empty() or description_key.is_empty() or icon == null: return "遺物資料不完整"
	if max_stacks < 1 or (not repeatable and max_stacks != 1): return "遺物持有上限無效"
	if id == &"reroll_discount" and (not parameters.get("paid_rerolls") is int or int(parameters.paid_rerolls) < 1): return "熟客優惠的付費刷新次數必須是正整數"
	for value in parameters.values():
		if (value is float or value is int) and not is_finite(float(value)): return "遺物參數必須有限"
	return ""
