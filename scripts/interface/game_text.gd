@tool
class_name GameText
extends RefCounted
## All player prose lives in the shared catalog; numeric arguments stay in code.
const ENGLISH = preload("res://assets/translations/card_names.en.translation")
const CHINESE = preload("res://assets/translations/card_names.zh_TW.translation")
static func text(key: String, values: Dictionary = {}, english: Variant = null) -> String:
	var result: String
	if english == null:
		result = TranslationServer.translate(key)
	else:
		var catalog: Translation = ENGLISH if english else CHINESE
		result = catalog.get_message(key)
		if result.is_empty(): result = key
	return result.format(values) if not values.is_empty() else result
