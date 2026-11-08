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
			{"key": &"mute", "label": "ui.settings.mute", "kind": "checkbox"},
			{"key": &"master_volume", "label": "ui.settings.master_volume", "kind": "slider"},
			{"key": &"bgm_volume", "label": "ui.settings.bgm_volume", "kind": "slider"},
			{"key": &"combat_volume", "label": "ui.settings.combat_volume", "kind": "slider"}]},
	]

static func read(viewport: Viewport) -> Dictionary:
	return {&"language": "en" if TranslationServer.get_locale().begins_with("en") else "zh_TW",
		&"msaa": viewport.msaa_3d, &"mute": AudioServer.is_bus_mute(0),
		&"master_volume": _volume(&"Master"), &"bgm_volume": _volume(&"BGM"),
		&"combat_volume": _volume(&"Combat")}

static func _volume(bus: StringName) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))*100.0

static func apply(key: StringName, value: Variant, viewport: Viewport) -> void:
	match key:
		&"language": TranslationServer.set_locale(value)
		&"msaa": viewport.msaa_3d = value
		&"mute": AudioServer.set_bus_mute(0, value)
		&"master_volume": _set_volume(&"Master", value)
		&"bgm_volume": _set_volume(&"BGM", value)
		&"combat_volume": _set_volume(&"Combat", value)

static func _set_volume(bus: StringName, value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), clampf(value/100.0, 0.0, 1.0))
