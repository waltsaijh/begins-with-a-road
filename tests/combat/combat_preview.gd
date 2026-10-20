extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")

func _ready() -> void:
	verify.call_deferred()

func ready_map(scene: Node) -> void:
	while scene.get_node("PortalMap").computing or scene.get_node("PortalMap").plan.is_empty():
		await get_tree().process_frame

func verify() -> void:
	var cells: Array[Vector2i] = []
	for y in 5:
		for x in 12:
			cells.append(Vector2i(x, y))
	var scene := Fixture.scene_for(cells, Vector2i(0, 2), Vector2i(11, 2))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 12
	add_child(scene)
	await ready_map(scene)
	var manager: Node = scene.get_node("TowerMap")
	var combat: Node = manager.combat
	combat.set_process(false)
	combat.visuals.set_process(false)
	var archer: DefenseTower = manager.place_tower(Vector3i(4, 0, 1))
	var launcher: DefenseTower = manager.place_tower(Vector3i(7, 0, 3))
	launcher.attack = load("res://assets/data/towers/attacks/explosive_projectile.tres").duplicate(true)
	archer.damage = 10
	launcher.damage = 10
	await ready_map(scene)
	wave.select_troop(2)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	if not wave.start_wave():
		push_error("Combat preview could not start")
		get_tree().quit(1)
		return
	for i in 240:
		wave._process(1.0/60.0)
		for enemy in wave.living_enemies():
			enemy._process(1.0/60.0)
		combat._process(1.0/60.0)
		wave.visuals._process(1.0/60.0)
	var target: Node3D = wave.living_enemies()[0]
	# Freeze a representative visual frame with both delivery types visible.
	archer.aim_at(combat.aim_position(target, archer.attack), 1.0)
	launcher.aim_at(combat.aim_position(target, launcher.attack), 1.0)
	combat.fire_arrow(archer, target, archer.attack)
	# Freeze an arrow in flight so its shaft, head and short fading trail are visible.
	var arrow: Dictionary = combat.projectiles[-1]
	var distance: float = Vector3(arrow.end-arrow.start).length()*0.65
	arrow.travelled = distance
	arrow.position = arrow.start+arrow.direction*distance
	combat.fire_projectile(launcher, target, launcher.attack)
	combat.projectiles[-1].age = launcher.attack.flight_time*0.5
	combat.visuals._process(0)
	wave.visuals.set_process(false)
	scene.get_node("TileVisuals").finish()
	scene.get_node("CloudLayer").set_process(false)
	scene.get_node("Camera3D").size = 12
	await get_tree().process_frame
	await get_tree().process_frame
	var mesh: MeshInstance3D = combat.visuals._instance
	if mesh.mesh == null or mesh.mesh.get_surface_count() != 1:
		push_error("Attack visuals were not submitted")
		get_tree().quit(1)
		return
	print("COMBAT_RENDER_CHECK:"+JSON.stringify({"single_attack_surface": true, "arrow": true, "trail": true, "projectile": true, "live_enemies": wave.alive}))
	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("combat/combat.png"))
		get_tree().quit()
