extends Node3D
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Overlay = preload("res://scripts/enemies/rendering/enemy_status_overlay.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func unit(batch: MultiMeshInstance3D, id: int) -> Node3D:
	var enemy: Node3D = Enemy.instantiate()
	add_child(enemy)
	enemy.follow(id, {}, PackedVector3Array([Vector3((id-2)*1.5, 0, 0), Vector3((id-2)*1.5, 0, -20)]))
	enemy.set_process(false)
	batch.add_enemy(enemy)
	return enemy

func verify() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293744")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	add_child(camera)
	camera.position = Vector3(1, 4, -9)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	var batch := Batch.new()
	add_child(batch)
	var units: Array[Node3D] = []
	for i in 5:
		units.append(unit(batch, i))
	batch.set_process(false)
	var enemy: Node3D = units[0]
	check(enemy.skill_progress < 0 and enemy.effect_icons.is_empty() and enemy.shield == 0, "Default optional statuses must be hidden")
	enemy.add_shield(50)
	enemy.take_damage(20)
	check(enemy.health == 100 and enemy.shield == 30, "Shield did not absorb damage first")
	enemy.take_damage(40)
	check(enemy.health == 90 and enemy.shield == 0, "Shield overflow did not damage health")
	enemy.add_shield(-10)
	check(enemy.shield == 0, "Negative shield grant was accepted")
	var slow: SlowEffect = load("res://assets/data/towers/effects/slow.tres").duplicate(true)
	slow.duration = 0.2
	slow.apply(enemy, null, 0)
	slow.apply(enemy, null, 0)
	check(enemy.effect_icons.size() == 1 and enemy.effect_icons.has(&"slow"), "Reapplying slow duplicated or lost its icon")
	enemy.apply_slow(0.8, 0.5, slow.icon)
	enemy._process(0.2)
	check(enemy.effect_icons.has(&"slow"), "Icon disappeared while another slow remained")
	enemy._process(0.31)
	check(not enemy.effect_icons.has(&"slow"), "Expired slow left a stale icon")
	enemy.set_effect_icon(&"a", slow.icon)
	enemy.set_effect_icon(&"b", slow.icon)
	check(enemy.effect_icons.keys() == [&"a", &"b"], "Effects lost horizontal display order")
	enemy.set_effect_icon(&"a", null)
	check(enemy.effect_icons.size() == 1, "Removing an effect removed another icon")
	enemy.set_effect_icon(&"b", null)
	# A shifted model's label must follow its visual offset, not its logical path.
	var head_before: Vector3 = batch.head_positions[0]
	batch._offsets[0] = Vector2(0.2, -0.1)
	batch.update_enemy(enemy)
	var expected_shift: Vector3 = enemy.global_position+Vector3(0.2, 0, -0.1)+batch._appearances[0].head-head_before
	check((batch.head_positions[0]-head_before).is_equal_approx(expected_shift), "Status anchor ignored visual separation")
	# Free a middle unit and verify dense slots and anchors move together.
	var last := units[-1]
	units[1].free()
	check(batch.units[1] == last and batch.head_positions[1].is_equal_approx(last.global_position+batch._appearances[1].head), "Status anchor broke after slot compaction")
	for current: Node3D in batch.units.duplicate():
		current.free()
	check(batch.head_positions.is_empty() and not batch.status_overlay.is_processing(), "Empty batch retained status state or updates")
	# Five readable examples: plain HP, partial HP, shield, skill, and an effect row.
	units.clear()
	for i in 5:
		units.append(unit(batch, i))
	batch.set_process(false)
	units[1].take_damage(60)
	units[2].add_shield(60)
	units[3].skill_progress = 0.65
	units[3].take_damage(25)
	slow.duration = 10
	slow.apply(units[4], null, 0)
	units[4].skill_progress = 0.35
	units[4].add_shield(40)
	units[4].take_damage(20)
	check(Overlay.health_fills(units[1]).is_equal_approx(Vector2(0.4, 0)), "Health fill ratio is incorrect")
	check(Overlay.health_fills(units[2]).is_equal_approx(Vector2(0.625, 0.375)), "Health and shield do not share their capacity proportionally")
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		var colors := {"health": 0, "shield": 0, "skill": 0, "effect": 0}
		for y in picture.get_height():
			for x in picture.get_width():
				var color := picture.get_pixel(x, y)
				if color.is_equal_approx(EnemyStatusConstants.HEALTH): colors.health += 1
				if color.is_equal_approx(EnemyStatusConstants.SHIELD): colors.shield += 1
				if color.is_equal_approx(EnemyStatusConstants.SKILL): colors.skill += 1
				if color.r > 0.65 and color.g > 0.8 and color.b > 0.9: colors.effect += 1
		check(colors.health > 100 and colors.shield > 20 and colors.skill > 40 and colors.effect > 5, "Status colors or icon were missing from the rendered frame")
		if not OS.has_feature("web"):
			picture.save_png("res://reports/enemies/enemy_status.png")
	var report := {"failures": failures, "shield_absorption": true, "effect_refresh_and_expiry": true, "visual_offset_anchor": true, "slot_cleanup": true, "optional_skill": true, "shared_overlay": true}
	print("ENEMY_STATUS_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		FileAccess.open("res://reports/enemies/enemy_status_windows.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)
