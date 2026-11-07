extends Node
## Observes real actions; never places, purchases or upgrades on the player's behalf.
enum Stage { CAMERA, FIRST, ROTATED, FREE, START, COMBAT, BUY_SENTRY, UPGRADE, REROLL, BUY_NEW, PRACTICE, DONE }
const Overlay = preload("res://scenes/tutorial/tutorial_overlay.tscn")
const Ghost = preload("res://scenes/cards/components/card_preview.tscn")
var session: Node3D
var definition: TutorialDefinition
var stage := Stage.CAMERA
var camera_actions := [false,false,false]
var _camera_focus := Vector3.ZERO
var _camera_size := 0.0
var _camera_angle := 0.0
var camera: Camera3D
var cards: Node3D
var shop: Node
var overlay: CanvasLayer
var ghost: Node3D

func setup(host: Node3D, data: TutorialDefinition) -> void:
	session = host
	definition = data
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = session.get_node("Camera3D")
	cards = session.get_node("CardPlacement")
	shop = cards.get_node("Shop")
	_camera_focus = camera.focus
	_camera_size = camera.size
	_camera_angle = camera.azimuth
	cards.towers.manual_input_allowed = false
	cards.towers.placement_rule = placement_error
	cards.card_placed.connect(_on_card_placed)
	shop.deal_filter = filter_deal
	shop.purchase_rule = can_buy
	shop.reroll_rule = func(): return stage == Stage.REROLL
	shop.purchased.connect(_on_purchased)
	shop.rerolled.connect(func(): _set_stage(Stage.BUY_NEW))
	session.get_node("EnemyWave").wave_started.connect(func():
		if stage == Stage.START: _set_stage(Stage.COMBAT))
	session.level_finished.connect(func(): _set_stage(Stage.DONE))
	overlay = Overlay.instantiate()
	add_child(overlay)
	ghost = Ghost.instantiate()
	ghost.valid_color = Color(1.0,0.8,0.3,0.32)
	add_child(ghost)
	_set_stage(Stage.CAMERA)

func _process(_delta: float) -> void:
	if not is_instance_valid(session) or not is_instance_valid(overlay): return
	var active: bool = session.is_inside_tree() and session.can_process() and not get_tree().paused and not session._loading and not session.choosing_relic and not ScreenTransition.active
	overlay.visible = active
	ghost.visible = active and stage in [Stage.FIRST,Stage.ROTATED,Stage.UPGRADE]
	if not active: return
	if stage == Stage.CAMERA:
		camera_actions[0] = camera_actions[0] or camera.focus.distance_to(_camera_focus) > 0.1
		camera_actions[1] = camera_actions[1] or absf(camera.size-_camera_size) > 0.2
		camera_actions[2] = camera_actions[2] or absf(wrapf(camera.azimuth-_camera_angle,-PI,PI)) > deg_to_rad(5.0)
		_update_text()
		if not camera_actions.has(false): _set_stage(Stage.FIRST)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(overlay): _update_text()

func can_start_wave() -> bool:
	return stage in [Stage.START,Stage.PRACTICE]

func placement_error(card: BuildCard, cell: Vector3i, turns: int) -> String:
	var index := stage-Stage.FIRST
	if stage in [Stage.FIRST,Stage.ROTATED]:
		if card != definition.starting_cards[index] or cell != definition.guided_cells[index] or posmod(turns,4) != definition.guided_turns[index]: return tr("tutorial.match_ghost")
		return ""
	if stage == Stage.FREE and card == definition.starting_cards[2]: return ""
	if stage == Stage.UPGRADE and card.tower == definition.upgrade_card.tower:
		var tower: DefenseTower = cards.towers.upgrade_target(cell)
		if tower != null and tower.definition == definition.upgrade_card.tower: return ""
	return tr("tutorial.follow_step")

func filter_deal(next: Array[BuildCard]) -> Array[BuildCard]:
	var result := next.duplicate()
	var required := definition.new_card if stage == Stage.REROLL else definition.upgrade_card
	for i in result.size():
		if result[i] != null and result[i].tower == required.tower:
			result[i] = result[0]
			break
	if not result.is_empty(): result[0] = required
	return result

func can_buy(card: BuildCard) -> bool:
	return (stage == Stage.BUY_SENTRY and card.tower == definition.upgrade_card.tower) or (stage == Stage.BUY_NEW and card.tower == definition.new_card.tower)

func _on_card_placed(_card: BuildCard, _tower: Node3D, _cell: Vector3i, _turns: int) -> void:
	if stage in [Stage.FIRST,Stage.ROTATED,Stage.FREE]: _set_stage(stage+1)
	elif stage == Stage.UPGRADE: _set_stage(Stage.REROLL)

func _on_purchased(_card: BuildCard) -> void:
	if stage == Stage.BUY_SENTRY: _set_stage(Stage.UPGRADE)
	elif stage == Stage.BUY_NEW:
		cards.towers.placement_rule = Callable()
		shop.deal_filter = Callable()
		shop.purchase_rule = Callable()
		shop.reroll_rule = Callable()
		_set_stage(Stage.PRACTICE)
		shop.close_shop()

## LevelSession calls this after projectiles settle, before the ACT reward flow.
func after_wave() -> bool:
	if session.current_wave != 1 or stage != Stage.COMBAT: return false
	_set_stage(Stage.BUY_SENTRY)
	return true

func _set_stage(value: int) -> void:
	stage = value
	session.get_node("EnemyWave").start_allowed = can_start_wave()
	session.get_node("EnemyWave")._update_button()
	cards._dirty = true
	ghost.hide()
	if stage in [Stage.FIRST,Stage.ROTATED]:
		var index := stage-Stage.FIRST
		ghost.show_at(cards.placement.map,definition.starting_cards[index],definition.guided_cells[index],definition.guided_turns[index],true)
		ghost.attack_area.hide()
	elif stage == Stage.UPGRADE:
		for tower: DefenseTower in cards.towers.towers.values():
			if tower.definition == definition.upgrade_card.tower:
				ghost.show_upgrade(cards.placement.map,tower,"")
				break
	if stage == Stage.UPGRADE: shop.close_shop()
	if stage in [Stage.BUY_SENTRY,Stage.REROLL]: shop.open_shop.call_deferred()
	_update_text()
	session._update_start_callout()

func _update_text() -> void:
	var keys := ["camera","first","rotated","free","start","combat","buy_sentry","upgrade","reroll","buy_new","practice","done"]
	var numbers := [1,2,2,2,3,3,4,4,5,5,5,5]
	overlay.get_node("Panel/Margin/Rows/Title").text = tr("tutorial.step").format({"step":numbers[stage]})
	if stage == Stage.PRACTICE: overlay.get_node("Panel/Margin/Rows/Title").text = tr("tutorial.practice_title")
	elif stage == Stage.DONE: overlay.get_node("Panel/Margin/Rows/Title").text = tr("tutorial.complete_title")
	var names := {"first_tower":definition.starting_cards[0].tower.localized_name(),"second_tower":definition.starting_cards[1].tower.localized_name(),"third_tower":definition.starting_cards[2].tower.localized_name(),"upgrade_tower":definition.upgrade_card.tower.localized_name(),"new_tower":definition.new_card.tower.localized_name()}
	overlay.get_node("Panel/Margin/Rows/Body").text = tr("tutorial."+keys[stage]).format(names)
	var progress: Label = overlay.get_node("Panel/Margin/Rows/Progress")
	progress.visible = stage == Stage.CAMERA
	progress.text = tr("tutorial.camera_progress").format({"pan":"✓" if camera_actions[0] else "○","zoom":"✓" if camera_actions[1] else "○","orbit":"✓" if camera_actions[2] else "○"})
