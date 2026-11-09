extends CanvasLayer
## Compact integrity/boss feedback and terminal result, authored in a shared scene.
## Integrity/boss sit below the HUD pause veil (layer 5) so they fade with the
## header; only the result panel keeps its own layer above everything.
var session: Node3D
var boss: WeakRef
var _won := false
var _next_map_id := ""
var _leaving := false
var _entry_motion: Tween
var _presented := false
var next_map: MenuMapDefinition
@onready var column: VBoxContainer = $ResultLayer/Result/Center/Panel/Margin/Column
func setup(value: Node3D) -> void:
	session = value
	$ResultLayer/Result.hide()
	$Boss.hide()
	$Integrity.visible = session.level.base_health > 0
	session.get_node("EnemyWave").enemy_spawned.connect(func(enemy):
		if enemy.troop.has_tag(&"boss"):
			boss = weakref(enemy)
			$Boss.show())
	$ResultLayer/Result/Center/Panel/Margin/Column/Restart.pressed.connect(restart)
	$ResultLayer/Result/Center/Panel/Margin/Column/TutorialActions/Restart.pressed.connect(restart)
	$ResultLayer/Result/Center/Panel/Margin/Column/TutorialActions/Continue.pressed.connect(continue_next)
	ScreenTransition.finished.connect(_on_transition_finished)
	column.get_node("NextLevel").pressed.connect(next_level)
	column.get_node("Home").pressed.connect(return_home)
	refresh()
func refresh() -> void:
	var english := TranslationServer.get_locale().begins_with("en")
	$Integrity.text = str(session.base_health)
	$Integrity.tooltip_text = (GameText.text("text.run_status.1",{},english)) % [session.base_health,session.level.base_health]

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and session != null:
		refresh()
		if $ResultLayer/Result.visible: _update_result()
func _process(_delta: float) -> void:
	if boss == null: return
	var enemy: Node3D = boss.get_ref()
	if not is_instance_valid(enemy) or not enemy.can_be_targeted():
		$Boss.hide()
		boss = null
		return
	$Boss.text = "%s  %d / %d%s" % [enemy.troop.localized_name(),ceili(enemy.health),int(enemy.max_health),"  ⚡" if enemy.is_casting() else ""]
func finish(won: bool) -> void:
	if _presented: return
	_presented = true
	_won = won
	next_map = _following_map() if won else null
	_next_map_id = next_map.id if next_map != null else ""
	_update_result()
	$ResultLayer/Result.show()
	_present_result()
	if won:
		GameAudio.play_victory()
		$ResultLayer/Result/Confetti.burst($ResultLayer/Result/Center/Panel/Margin/Column)

func _present_result() -> void:
	if _entry_motion != null: _entry_motion.kill()
	_entry_motion = create_tween().set_parallel(true).set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	$ResultLayer/Result/Veil.modulate.a = 0.0
	_entry_motion.tween_property($ResultLayer/Result/Veil,"modulate:a",1.0,0.3)
	for entry in [["Crest",0.0],["Eyebrow",0.03],["Title",0.06],["Rule",0.08],["Details",0.1],["Completion",0.13],["Restart",0.15],["TutorialActions",0.15],["NextLevel",0.15],["Home",0.18]]:
		var item: Control = column.get_node(entry[0])
		item.modulate.a = 0.0
		_entry_motion.tween_property(item,"modulate:a",1.0,0.28).set_delay(entry[1]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_result() -> void:
	var english := TranslationServer.get_locale().begins_with("en")
	var tutorial_complete: bool = _won and session.level.tutorial != null
	$ResultLayer/Result/Center/Panel/Margin/Column/Title.text = GameText.text("result.victory_title" if _won else "result.defeat_title",{},english)
	$ResultLayer/Result/Center/Panel/Margin/Column/Eyebrow.text = tr("tutorial.complete_title") if tutorial_complete else tr("result.complete" if _won else "result.failed")
	var accent := Color(0.7,0.61,0.38,1) if _won else Color(0.58,0.37,0.33,1)
	$ResultLayer/Result/Center/Panel/Margin/Column/Crest/Diamond.default_color = accent
	$ResultLayer/Result/Center/Panel/Margin/Column/Rule.color = Color(accent,0.5)
	$ResultLayer/Result/Center/Panel/Margin/Column/Title.add_theme_color_override("font_color",Color(0.125,0.243,0.278,1) if _won else Color(0.37,0.25,0.24,1))
	$ResultLayer/Result/Center/Panel/Margin/Column/Details/Waves/Value.text = "%02d / %02d" % [session.current_wave,session.level.wave_count()]
	$ResultLayer/Result/Center/Panel/Margin/Column/Details/Leaks/Value.text = str(session.total_leaks)
	$ResultLayer/Result/Center/Panel/Margin/Column/Details/Gold/Value.text = str(session.get_node("CardPlacement/Shop").coins)
	$ResultLayer/Result/Center/Panel/Margin/Column/Restart.text = GameText.text("text.run_status.2",{},english)
	$ResultLayer/Result/Center/Panel/Margin/Column/Completion.visible = tutorial_complete
	$ResultLayer/Result/Center/Panel/Margin/Column/Completion.text = tr("tutorial.done")
	$ResultLayer/Result/Center/Panel/Margin/Column/Restart.visible = not tutorial_complete
	$ResultLayer/Result/Center/Panel/Margin/Column/TutorialActions.visible = tutorial_complete
	$ResultLayer/Result/Center/Panel/Margin/Column/TutorialActions/Continue.disabled = _next_map_id.is_empty()
	column.get_node("NextLevel").visible = next_map != null and not tutorial_complete

func continue_next() -> void:
	if _leaving or _next_map_id.is_empty() or ScreenTransition.active: return
	_leaving = true
	LevelLaunch.request_menu_map(_next_map_id)
	if not ScreenTransition.change_scene("res://scenes/menus/main_menu.tscn"):
		LevelLaunch.take_menu_map()
		_leaving = false

func _on_transition_finished(error: int) -> void:
	if error != OK and _leaving:
		LevelLaunch.take_menu_map()
		LevelLaunch.clear()
		_leaving = false
func restart() -> void:
	if _leaving or ScreenTransition.active: return
	_resume()
	session.restart_level()

## Tutorial continues through map selection; ordinary wins can launch directly.
func next_level() -> void:
	if _leaving or next_map == null or ScreenTransition.active: return
	if session.level.tutorial != null:
		continue_next()
		return
	_leaving = true
	_resume()
	LevelLaunch.select(next_map.level)
	if not ScreenTransition.change_scene(next_map.level_scene, &"prepare_for_play"):
		LevelLaunch.clear()
		_leaving = false

func return_home() -> void:
	if _leaving or ScreenTransition.active: return
	_leaving = true
	_resume()
	if not ScreenTransition.change_scene("res://scenes/menus/main_menu.tscn"):
		_leaving = false

func _resume() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0

## First playable level after this one in the catalog's prerequisite order.
func _following_map() -> MenuMapDefinition:
	var catalog := LevelCatalog.new()
	catalog.build(LevelCatalog.discover(), LevelProgress.snapshot())
	var found := false
	for entry in catalog.maps:
		if found and entry.unlocked and entry.level != null: return entry
		if entry.id == session.level.progress_id(): found = true
	return null
