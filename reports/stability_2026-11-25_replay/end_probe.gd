extends Node

const Fixture = preload("res://tests/synergy/fixture.gd")
const DIR := "res://.godot/stability-20261125/"
var finishes := 0
var waves := 0

func _ready() -> void: investigate.call_deferred()

func stop(reason: String) -> void:
	print("FINAL_KILL_PROBE STOP ", reason)
	get_tree().quit(2)

func investigate() -> void:
	var species := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-enemy="): species = arg.trim_prefix("--probe-enemy=")
	if DisplayServer.get_name() != "headless" or not species in ["soldier", "ravager"]:
		stop("requires headless and explicit species")
		return
	seed(17391)
	Engine.time_scale = 1.0
	var saved := DIR+"probe-progress-"+species+"-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())+".cfg"
	LevelProgress.save_path = saved
	LevelProgress._completed.clear()
	LevelProgress._encountered.clear()
	var level := Fixture.definition(0)
	level.level_id = "stability_probe_final_kill"
	level.opening_shop = true
	level.starting_gold = 9
	level.base_health = 20
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.find(species)
	group.enemy_count = 1
	var recipe := WaveDefinition.new()
	recipe.reward = 0
	recipe.groups = [group]
	var act := ActDefinition.new()
	act.waves = [recipe]
	level.acts = [act]
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	scene.get_node("CardPlacement").initial_card_count = 0
	scene.get_node("CardPlacement").cards.clear()
	add_child(scene)
	var wave: Node = scene.get_node("EnemyWave")
	for i in 120:
		if not scene.get_node("PortalMap").computing and wave.start_allowed: break
		await get_tree().process_frame
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var gold: int = shop.coins
	scene.run_finished.connect(func(_won): finishes += 1)
	wave.wave_finished.connect(func(): waves += 1)
	wave.controls.spawn_requested.emit()
	for i in 300:
		if wave.active and wave.living_enemies().size() == 1: break
		await get_tree().process_frame
	if not wave.active or wave.living_enemies().size() != 1: 
		stop("wave did not start or spawn exactly one enemy")
		return
	var enemy: Node3D = wave.living_enemies()[0]
	# Give both cohorts the identical 60 simulation frames before the fatal hit.
	for frame in 60: await get_tree().process_frame
	if not is_instance_valid(enemy) or not enemy.can_be_targeted():
		stop("enemy unavailable before intended hit")
		return
	enemy.take_damage(999999)
	for frame in 90: await get_tree().process_frame
	var value := {"profile":species, "wave_finished":waves, "run_finished":finishes,
		"victory":scene.victory, "finished":scene.finished, "kills":scene.total_kills,
		"wave":scene.current_wave, "alive":wave.alive, "active":wave.active,
		"gold_delta":shop.coins-gold, "result_visible":scene.run_status.get_node("ResultLayer/Result").is_visible_in_tree(),
		"saved":LevelProgress.snapshot().has(level.level_id)}
	var ok: bool = waves == 1 and finishes == 1 and scene.finished and scene.victory and scene.total_kills == 1 and scene.current_wave == 1 and wave.alive == 0 and not wave.active and value.gold_delta == 1 and value.result_visible and value.saved
	print("FINAL_KILL_PROBE ", JSON.stringify(value), " pass=",ok)
	scene.queue_free()
	for frame in 6: await get_tree().process_frame
	get_tree().quit(0 if ok else 1)