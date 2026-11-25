class_name HudTextPalette
extends RefCounted
## Light text for the transparent top HUD row over dark (night) clouds. Only
## colour overrides on existing controls; no backdrop, theme swap or new nodes.
## Covers the timeline, gold, speed/pause, integrity/boss, held-relic counts and
## the new-enemy notification. Pause menu, cards and dialogs keep their own panels.
const TEXT := Color(0.9, 0.94, 0.96)
const MUTED := Color(0.72, 0.8, 0.86)
const HOVER := Color(1, 1, 1)
const BOSS := Color(1, 0.72, 0.66)
## Night wave dots read as hollow rings; the current one stays solid TEXT.
const DOT_FILL := Color(0.2, 0.25, 0.36)
## integrity.svg is stroked in #527b7d and Button icon colours multiply, so a
## plain light colour cannot brighten it; this >1 multiplier maps it to TEXT.
const INTEGRITY_ICON := Color(TEXT.r / 0.322, TEXT.g / 0.482, TEXT.b / 0.49)

static func apply_light(session: Node) -> void:
	var timeline := session.get_node_or_null("LevelHUD/Header/WaveTimeline") as WaveTimeline
	if timeline != null: timeline.set_palette(TEXT, MUTED, TEXT, DOT_FILL)
	_text(session.get_node_or_null("LevelHUD/Header/Balance/Amount"))
	for path in ["LevelHUD/Header/Actions/Speed", "LevelHUD/Header/Actions/Pause"]:
		_icons(session.get_node_or_null(path))
	var status: Node = session.get("run_status")
	if status != null:
		var integrity := status.get_node_or_null("Integrity") as Button
		_text(integrity)
		if integrity != null:
			for key in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color"]:
				integrity.add_theme_color_override(key, INTEGRITY_ICON)
		var boss := status.get_node_or_null("Boss") as Label
		if boss != null: boss.add_theme_color_override("font_color", BOSS)
	var relics: Node = session.get("relic_choice")
	if relics != null:
		relics.count_color = TEXT
		for count in relics.find_children("*", "Label", true, false):
			if count.get_parent().get_parent() == relics.get_node_or_null("RelicBar/Items"): count.add_theme_color_override("font_color", TEXT)
	var intel: Node = session.get("enemy_intelligence")
	if intel != null: _text(intel.get_node_or_null("Screen/Toggle"))

static func _text(control: Control) -> void:
	if control == null: return
	for key in ["font_color", "font_focus_color", "font_pressed_color"]:
		control.add_theme_color_override(key, TEXT)
	control.add_theme_color_override("font_hover_color", HOVER)

static func _icons(button: Button) -> void:
	if button == null: return
	button.add_theme_color_override("icon_normal_color", Color(TEXT, 0.85))
	button.add_theme_color_override("icon_focus_color", Color(TEXT, 0.85))
	button.add_theme_color_override("icon_hover_color", HOVER)
	button.add_theme_color_override("icon_pressed_color", Color(TEXT, 0.55))
	button.add_theme_color_override("icon_disabled_color", Color(MUTED, 0.3))
