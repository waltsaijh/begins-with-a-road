extends Node3D
## Explicit presentation-only startup scene, before the interactive main menu.
@onready var renderer: MultiMeshInstance3D = $EnemyDisplay
@onready var display: Control = $Interface/Loading
var completed := 0
var total := 0
var prepared := false

func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	display.report(0, 0, &"ui.loading.catalog")
	await _present()
	var profiles := DisplayWarmup.representatives(TroopCatalog.all(), renderer)
	total = profiles.size()+1
	# Same material as enemies, but exercise the ordinary MeshInstance path too.
	# Geometry type/render flags can still produce different engine programs.
	display.report(0,total,&"ui.loading.materials")
	await _present()
	DisplayWarmup.retain_resources([$CommonGeometry.mesh])
	if DisplayServer.get_name() != "headless":
		$CommonGeometry.show()
		await _present()
		await get_tree().process_frame
		$CommonGeometry.hide()
	completed += 1
	display.report(completed, total, &"ui.loading.visuals")
	await _present()
	var error: int = await DisplayWarmup.prepare(renderer, profiles, func():
		completed += 1
		display.report(completed, total, &"ui.loading.visuals"))
	prepared = error == OK
	# A failed warmup is retried by the level; do not strand startup behind a cover.
	if error != OK: push_warning("Startup display preparation failed: "+error_string(error))
	await _present()
	if ScreenTransition.change_scene("res://scenes/menus/main_menu.tscn", &"", &"ui.loading.menu"):
		display.hide()

func _present() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
