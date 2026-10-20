extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Overlay = preload("res://scripts/enemies/presentation/enemy_status_overlay.gd")
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
	verify_effect_merging()
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
	check(enemy.effect_icons.has(&"slow"), "Icon disappeared before the merged slow expired")
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
	check(batch.status_overlay.batch.multimesh.visible_instance_count == 0, "Last removal left stale status instances")
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
	var batch_render := {}
	if DisplayServer.get_name() != "headless": batch_render = await verify_batch_rendering(batch)
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
			picture.save_png(Artifacts.path("enemies/enemy_status.png"))
	var report := {"failures": failures, "shield_absorption": true, "effect_refresh_and_expiry": true, "strongest_effect_longest_remaining": true, "visual_offset_anchor": true, "slot_cleanup": true, "optional_skill": true, "shared_overlay": true, "batch_render": batch_render}
	print("ENEMY_STATUS_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		FileAccess.open(Artifacts.path("enemies/enemy_status_windows.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)

func check_slow_step(enemy: Node3D, delta: float, factor: float, message: String) -> void:
	var before: float = enemy.travelled_distance
	enemy._process(delta)
	check(is_equal_approx(enemy.travelled_distance-before, enemy.move_speed*delta*factor), message)

func verify_effect_merging() -> void:
	var strong_icon := GradientTexture2D.new()
	var weak_icon := GradientTexture2D.new()
	var points := PackedVector3Array([Vector3.ZERO, Vector3(1000, 0, 0)])
	for weak_first: bool in [false, true]:
		var enemy: Node3D = Enemy.instantiate()
		add_child(enemy)
		enemy.follow(0, {}, points)
		enemy.set_process(false)
		enemy.move_speed = 10
		enemy.set_effect_icon(&"independent", weak_icon)
		if weak_first:
			enemy.apply_slow(0.8, 3.0, weak_icon)
			enemy.apply_slow(0.4, 1.0, strong_icon)
		else:
			enemy.apply_slow(0.4, 1.0, strong_icon)
			enemy.apply_slow(0.8, 3.0, weak_icon)
		check(enemy.effect_icons.size() == 2 and enemy.effect_icons[&"slow"] == strong_icon, "Merged slow did not retain the strongest icon")
		check_slow_step(enemy, 1.0, 0.4, "Merged slow stacked its strength")
		check_slow_step(enemy, 1.0, 0.4, "Merged slow fell back to a weaker effect")
		check(enemy.effect_icons.has(&"slow"), "Merged slow lost its longest duration")
		check_slow_step(enemy, 1.0, 0.4, "Merged slow expired early")
		check(not enemy.effect_icons.has(&"slow") and enemy.effect_icons.has(&"independent"), "Slow expiry changed another effect")
		check_slow_step(enemy, 0.25, 1.0, "Merged slow added durations instead of taking the longest")
		# A fresh effect after expiry must not inherit the previous strength.
		enemy.apply_slow(0.8, 5.0, weak_icon)
		check_slow_step(enemy, 1.0, 0.8, "Fresh slow inherited an expired stronger effect")
		enemy.apply_slow(0.4, 1.0, strong_icon)
		check_slow_step(enemy, 3.0, 0.4, "Stronger slow failed to inherit existing remaining time")
		check_slow_step(enemy, 1.0, 0.4, "Merge compared total duration instead of remaining time")
		check_slow_step(enemy, 0.25, 1.0, "Merge restored elapsed time")
		# Equal-strength refreshes use max(remaining, incoming), never addition.
		enemy.apply_slow(0.5, 5.0, strong_icon)
		check_slow_step(enemy, 3.0, 0.5, "Initial equal-strength slow was incorrect")
		enemy.apply_slow(0.5, 0.5, strong_icon)
		check_slow_step(enemy, 1.0, 0.5, "Shorter refresh shortened remaining duration")
		check(enemy.effect_icons.has(&"slow"), "Shorter refresh ended the effect early")
		enemy.apply_slow(0.5, 3.0, strong_icon)
		check_slow_step(enemy, 3.0, 0.5, "Longer refresh did not extend the merged duration")
		check_slow_step(enemy, 0.25, 1.0, "Equal-strength refresh added durations")
		enemy.apply_slow(0.4, 10.0, strong_icon)
		enemy.follow(1, {}, points)
		enemy.set_process(false)
		check(enemy.effect_icons.is_empty(), "Reused enemy retained an effect icon")
		check_slow_step(enemy, 0.25, 1.0, "Reused enemy retained a merged effect")
		enemy.free()

func frame_image() -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func verify_batch_rendering(renderer: MultiMeshInstance3D) -> Dictionary:
	var overlay: Control = renderer.status_overlay
	check(overlay.batch is MultiMeshInstance2D and overlay._atlas_ready, "Status batch or appearance atlas was not initialized")
	var example: Node3D = renderer.units[-1]
	var textures: Array[Texture2D] = []
	for color in [Color.RED, Color.BLUE]:
		var pixels := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
		pixels.fill(color)
		textures.append(ImageTexture.create_from_image(pixels))
	example.set_effect_icon(&"red", textures[0])
	example.set_effect_icon(&"blue", textures[1])
	var reference_layer := load("res://scenes/enemies/components/enemy_status_overlay.tscn").instantiate() as CanvasLayer
	var reference: Control = reference_layer.get_node("EnemyStatusOverlay")
	reference.set_script(load("res://tests/fixtures/status_reference_overlay.gd"))
	reference.renderer = renderer
	add_child(reference_layer)
	reference.set_process(true)
	var compared := 0
	var mismatched := 0
	var worst := 0.0
	var second_position: Vector3 = renderer.units[1].global_position
	for overlap in [false, true]:
		if overlap:
			renderer.units[1].global_position = renderer.units[0].global_position
			renderer.update_enemy(renderer.units[1])
		overlay.hide()
		reference.show()
		var before := await frame_image()
		reference.hide()
		overlay.show()
		overlay._process(0.0)
		var after := await frame_image()
		if not OS.has_feature("web"):
			before.save_png("res://.godot/status_reference_%s.png" % overlap)
			after.save_png("res://.godot/status_batched_%s.png" % overlap)
		for y in after.get_height():
			for x in after.get_width():
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				var error := maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))
				worst = maxf(worst, error)
				if error > 2.0/255.0: mismatched += 1
		compared += after.get_width()*after.get_height()
	check(mismatched == 0, "Batched status differs from reference pixels: %d (max %.4f)" % [mismatched, worst])
	check(overlay._atlas.image.get_width() > 128, "Distinct icon test did not exercise atlas growth")
	# Capacity growth must preserve previous quads and effect removal must shrink it.
	var previous_count: int = overlay.batch.count
	for i in 64: example.set_effect_icon(StringName("extra_%d" % i), textures[i%2])
	overlay._process(0.0)
	check(overlay.batch.count == previous_count+128 and overlay.batch.multimesh.instance_count >= overlay.batch.count, "Status capacity growth lost quads")
	for i in 64: example.set_effect_icon(StringName("extra_%d" % i), null)
	example.set_effect_icon(&"red", null)
	example.set_effect_icon(&"blue", null)
	overlay._process(0.0)
	check(overlay.batch.count == previous_count-4, "Removed effect left stale quads")
	renderer.hide()
	overlay._process(0.0)
	check(overlay.batch.multimesh.visible_instance_count == 0, "Hidden renderer retained visible status instances")
	renderer.show()
	renderer.units[1].global_position = second_position
	renderer.update_enemy(renderer.units[1])
	overlay.clear()
	check(overlay._atlas._icons.is_empty() and overlay.batch.count == 0, "Clearing status retained icon resources or instances")
	overlay._process(0.0)
	check(overlay.batch.count == previous_count-4 and overlay._atlas._icons.size() == 1, "Reusing the batch after clearing did not restore active effects")
	reference_layer.queue_free()
	await verify_baked_appearance(renderer)
	return {"reference_pixels": compared, "mismatched_pixels": mismatched, "maximum_channel_error": worst, "overlap_order": true, "atlas_growth": true, "capacity_growth": true, "effect_removal": true, "baked_appearance": true}

func verify_baked_appearance(renderer: MultiMeshInstance3D) -> void:
	var layer := load("res://scenes/enemies/components/enemy_status_overlay.tscn").instantiate() as CanvasLayer
	var overlay: Control = layer.get_node("EnemyStatusOverlay")
	var panel: Panel = overlay.get_node("Appearance/Background")
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.set_corner_radius_all(2)
	style.set_expand_margin_all(3)
	style.set_border_width_all(2)
	style.shadow_size = 2
	style.bg_color = Color.RED
	style.border_color = Color.BLUE
	panel.add_theme_stylebox_override("panel", style)
	overlay.renderer = renderer
	renderer.status_overlay.hide()
	add_child(layer)
	overlay.set_process(true)
	var picture := await frame_image()
	if not OS.has_feature("web"): picture.save_png("res://.godot/status_baked_style.png")
	check(overlay._atlas_ready and overlay._frames.size() == 3 and not overlay._flat[0], "Rounded appearance did not finish baking")
	var red := 0
	var blue := 0
	for y in picture.get_height():
		for x in picture.get_width():
			var color := picture.get_pixel(x, y)
			if color.r > 0.95 and color.g < 0.05 and color.b < 0.05: red += 1
			if color.b > 0.95 and color.r < 0.05 and color.g < 0.05: blue += 1
	check(red > 20 and blue > 20, "Baked custom background or border was missing from the rendered frame (%d red, %d blue)" % [red, blue])
	renderer.status_overlay.show()
	layer.queue_free()
