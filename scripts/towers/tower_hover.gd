extends Label3D
## One shared, transient level readout. No labels attached to every tower.
var tower_map: Node3D
var feedback_seconds := 0.0
var feedback_tower: DefenseTower

func _ready() -> void:
	font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	font_size = 36
	pixel_size = 0.012
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	modulate = Color("f4e8cc")
	outline_modulate = Color("484334")
	tower_map.tower_upgraded.connect(func(tower):
		feedback_tower = tower
		feedback_seconds = 1.0)
	hide()

func _process(delta: float) -> void:
	hide()
	feedback_seconds = maxf(0, feedback_seconds-delta)
	var cards := tower_map.get_node_or_null("../CardPlacement")
	if cards != null and (cards.input_suspended or cards.selected >= 0): return
	var tower: DefenseTower
	if feedback_seconds > 0 and is_instance_valid(feedback_tower): tower = feedback_tower
	elif get_viewport().gui_get_hovered_control() == null:
		tower = tower_map.upgrade_target(tower_map.placement.pick_cell(get_viewport().get_mouse_position()))
	if not is_instance_valid(tower) or tower.is_queued_for_deletion(): return
	text = "%s · Lv.%d" % [tower.definition.localized_name(), tower.level]
	global_position = tower.global_position+Vector3.UP*(1.6+feedback_seconds*0.15)
	show()
