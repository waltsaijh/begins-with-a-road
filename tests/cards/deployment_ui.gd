extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
var failures: Array[String] = []
var checks := 0
var session: Node3D
func _ready() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame
func move(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	get_viewport().push_input(event,true)
	await frames(2)
func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event,true)
func click(point: Vector2) -> void:
	await move(point)
	button(point,true)
	button(point,false)
	await frames(4)
func settle() -> void:
	session.get_node("CardPlacement").hand.finish_animation()
	session.get_node("CardPlacement/Shop/View").finish_animation()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("deployment/"+name+".png"))
func run() -> void:
	TranslationServer.set_locale("zh_TW")
	session = load("res://scenes/level.tscn").instantiate()
	add_child(session)
	await frames(12)
	for i in 180:
		if not session.get_node("PortalMap").computing: break
		await frames(1)
	var cards: Node = session.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var view: CanvasLayer = shop.view
	var hud: Node = session.get_node("LevelHUD")
	settle()
	check(shop.available and not view.opened and not view.get_node("Root").is_visible_in_tree(),"Preparation has no large shop deck")
	check(view.entry.is_visible_in_tree() and view.entry.size.x <= 38,"Small shop entry is available in the HUD")
	check(absf(view.entry.get_global_rect().get_center().y-hud.pause_button.get_global_rect().get_center().y) < 1,"Supply entry aligns vertically with existing actions")
	check(view.entry.get_global_rect().position.x >= hud.pause_button.get_global_rect().end.x,"Shop entry follows existing actions without moving speed/pause")
	var speed_position: Vector2 = hud.speed_button.global_position
	var pause_position: Vector2 = hud.pause_button.global_position
	var timeline_position: Vector2 = session.timeline.global_position
	check(cards.hand.views.front().rotation < 0 and cards.hand.views.back().rotation > 0,"Hand fans to both sides")
	for hand_card in cards.hand.views:
		check(hand_card.get_node("Visuals/Accent").self_modulate.a < 0.8,"Hand module has a subdued outline")
	await capture("closed_zh")
	await click(view.entry.get_global_rect().get_center())
	settle()
	check(view.opened and cards.input_suspended and view.get_node("Root").is_visible_in_tree(),"HUD button opens the existing four-offer shop")
	check(shop.offers.size() == 4 and view.slots.size() == 5,"Offer and reroll structure is unchanged")
	await capture("open_zh")
	await click(view.entry.get_global_rect().get_center())
	settle()
	check(not view.opened and not cards.input_suspended and not view.get_node("Root").visible,"HUD button closes without restoring a deck")
	check(hud.speed_button.global_position == speed_position and hud.pause_button.global_position == pause_position and session.timeline.global_position == timeline_position,"Shop toggling preserves HUD anchors")
	var camera: Camera3D = session.get_node("Camera3D")
	var goal: Node3D = session.get_node("Goal")
	var point := camera.unproject_position(goal.global_position+Vector3.UP*0.5)
	check(is_finite(Picker.hit_distance(camera.project_ray_origin(point),camera.project_ray_normal(point),Picker.mesh_parts(goal))),"Base click targets the visible model")
	var original_focus: Vector3 = camera.focus
	await move(point)
	button(point,true)
	await move(point+Vector2(40,0),MOUSE_BUTTON_MASK_LEFT)
	button(point+Vector2(40,0),false)
	await frames()
	check(not view.opened,"Dragging on the base remains camera navigation")
	camera.focus = original_focus
	camera.update_pose()
	point = camera.unproject_position(goal.global_position+Vector3.UP*0.5)
	await click(point)
	settle()
	check(view.opened and view.get_node("BasePage").visible and not view.get_node("Root").visible,"Clicking the base opens its upgrade page")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape,true)
	escape.pressed = false
	get_viewport().push_input(escape,true)
	settle()
	check(not view.opened and not get_tree().paused,"Escape closes an open shop before gameplay pause")
	cards.select_card(0)
	var inventory: int = cards.cards.size()
	await click(point)
	check(not view.opened and cards.selected == 0 and cards.cards.size() == inventory,"Held-card placement has priority over base shopping")
	cards.select_card(-1)
	hud.set_paused(true)
	check(not view.entry.visible and not shop.try_open_from_world(camera,point),"Pause hides the entry and blocks world opening")
	hud.set_paused(false)
	await get_tree().create_timer(0.4).timeout
	cards.set_entry_selection(true)
	check(not view.entry.is_visible_in_tree() and not shop.try_open_from_world(camera,point),"Entrance/relic/event lock blocks both shop entrances")
	cards.set_entry_selection(false)
	# A visible unit over the base keeps unit inspection priority.
	var towers: Node = session.get_node("TowerMap")
	var placement: Node = session.get_node("TilePlacement")
	var support: Array[Vector3i] = [Vector3i(8,0,3)]
	placement.add_cells(support)
	var tower: DefenseTower = towers.place_tower(Vector3i(8,0,3))
	check(tower != null,"Inspection-priority fixture tower exists")
	if tower != null:
		var saved := tower.global_position
		tower.global_position = goal.global_position
		var parts := Picker.mesh_parts(tower)
		var center: Vector3 = parts[0].transform*parts[0].bounds.get_center()
		var overlap := camera.unproject_position(center)
		check(not shop.try_open_from_world(camera,overlap),"Overlapping unit retains inspection priority")
		await click(overlap)
		check(session.unit_inspection.target == tower and not view.opened,"Actual overlapping-unit click selects inspection instead of shop")
		session.unit_inspection.cancel_selection(false)
		tower.global_position = saved
	# Inspecting a unit folds the hand. Reopen the exposed pile, then hover a card.
	settle()
	var first: Control = cards.hand.views[0]
	check(cards.hand.folded,"Clicking away folds the hand without blocking inspection")
	await move(first.get_global_rect().position + Vector2(32,16))
	settle()
	check(not cards.hand.folded,"Hover over exposed cards reopens the fan")
	# Synthetic mouse events may be delivered to a background test window.
	get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await move(first.get_global_rect().get_center())
	await get_tree().create_timer(0.8).timeout
	var notes: Node = cards.get_node("CardHoverNote")
	check(notes.target == first and notes.root.visible and notes.strips.size() == 3,"Hand hover still reveals damage, speed and effect bookmarks")
	await capture("bookmarks_zh")
	await move(Vector2(8,150))
	var window := get_tree().root
	var original_size := window.size
	var original_scale := window.content_scale_size
	window.content_scale_size = Vector2i(800,600)
	window.size = Vector2i(800,600)
	TranslationServer.set_locale("en")
	await frames(8)
	settle()
	check(view.entry.get_global_rect().end.x <= 800,"Small entry fits a narrow viewport")
	await capture("closed_en_800")
	await click(view.entry.get_global_rect().get_center())
	settle()
	await capture("open_en_800")
	shop.close_shop()
	window.content_scale_size = original_scale
	window.size = original_size
	await frames()
	# Repeated quick toggles converge without transactions or extra offers.
	var wallet: int = shop.coins
	var deals: int = shop.deals
	for i in 3:
		view.entry.pressed.emit()
		view.entry.pressed.emit()
	settle()
	check(not view.opened and shop.coins == wallet and shop.deals == deals,"Quick entry toggles neither spend gold nor redeal")
	session._on_start_requested()
	check(not view.entry.is_visible_in_tree() and not shop.try_open_from_world(camera,point),"Wave opening hides and blocks the supply entry")
	session.queue_free()
	await frames()
	var result := {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name() != "headless"}
	print("DEPLOYMENT_UI "+JSON.stringify(result))
	if not OS.has_feature("web"): get_tree().quit(0 if failures.is_empty() else 1)
