extends RefCounted
## Engine adapter; UI has no dependency on level nodes or engine settings.
static func sections() -> Array[Dictionary]:
	return [
		{"label": "ui.settings.general", "options": [
			{"key": &"language", "label": "ui.settings.language", "kind": "radio", "choices": [
				{"label": "繁體中文", "value": "zh_TW"}, {"label": "English", "value": "en"}]}]},
		{"label": "ui.settings.display", "options": [
			{"key": &"msaa", "label": "ui.settings.msaa", "kind": "radio", "choices": [
				{"label": "ui.settings.off", "value": 0}, {"label": "2×", "value": 1}, {"label": "4×", "value": 2}]}]},
		{"label": "ui.settings.audio", "options": [
			{"key": &"mute", "label": "ui.settings.mute", "kind": "checkbox"}]},
	]

static func read(viewport: Viewport) -> Dictionary:
	return {&"language": "en" if TranslationServer.get_locale().begins_with("en") else "zh_TW",
		&"msaa": viewport.msaa_3d, &"mute": AudioServer.is_bus_mute(0)}

static func apply(key: StringName, value: Variant, viewport: Viewport) -> void:
	match key:
		&"language": TranslationServer.set_locale(value)
		&"msaa": viewport.msaa_3d = value
		&"mute": AudioServer.set_bus_mute(0, value)
