extends CanvasLayer
## Compact integrity/boss feedback and terminal result, authored in a shared scene.
var session: Node3D
var boss: WeakRef
func setup(value: Node3D) -> void:
	session = value
	$Result.hide()
	$Boss.hide()
	$Integrity.visible = session.level.base_health > 0
	session.get_node("EnemyWave").enemy_spawned.connect(func(enemy):
		if enemy.troop.has_tag(&"boss"):
			boss = weakref(enemy)
			$Boss.show())
	$Result/Center/Panel/Margin/Column/Restart.pressed.connect(restart)
	refresh()
func refresh() -> void:
	var english := TranslationServer.get_locale().begins_with("en")
	$Integrity.text = str(session.base_health)
	$Integrity.tooltip_text = ("Defense integrity: %d / %d\nEnemies reaching the goal damage the defense. A siege behemoth reaching it ends the run." if english else "防線生命：%d / %d\n敵人抵達終點會損傷防線；攻城巨獸抵達即失敗。") % [session.base_health,session.level.base_health]

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and session != null: refresh()
func _process(_delta: float) -> void:
	if boss == null: return
	var enemy: Node3D = boss.get_ref()
	if not is_instance_valid(enemy) or not enemy.can_be_targeted():
		$Boss.hide()
		boss = null
		return
	$Boss.text = "%s  %d / %d%s" % [enemy.troop.localized_name(),ceili(enemy.health),int(enemy.max_health),"  ⚡" if enemy.cast_remaining > 0 else ""]
func finish(won: bool) -> void:
	var english := TranslationServer.get_locale().begins_with("en")
	$Result/Center/Panel/Margin/Column/Title.text = ("Road defended" if won else "Defense broken") if english else ("守住了這條路" if won else "防線失守")
	$Result/Center/Panel/Margin/Column/Details.text = ("Waves %d / %d  ·  Leaks %d\nGold %d" if english else "完成 %d / %d 波　·　漏敵 %d\n剩餘金幣 %d") % [session.current_wave,session.level.wave_count(),session.total_leaks,session.get_node("CardPlacement/Shop").coins]
	$Result/Center/Panel/Margin/Column/Restart.text = "Play again" if english else "重新開始"
	$Result.show()
func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	session.restart_level()
