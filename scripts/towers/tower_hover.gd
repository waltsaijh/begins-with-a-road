extends Control
## One shared, transient speech bubble. No UI attached to every tower.
var tower_map: Node3D
var feedback_seconds := 0.0
var feedback_tower: DefenseTower
@onready var tower_name: Label = $Margin/Content/TowerName
@onready var tower_level: Label = $Margin/Content/Level

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()
	tower_map.tower_upgraded.connect(func(tower):
		feedback_tower = tower
		feedback_seconds = 1.0)
	hide()

func _process(delta: float) -> void:
	hide()
	# Keep the upper canvas empty while gameplay is paused or preparing to load.
	if get_tree().paused or not tower_map.can_process(): return
	feedback_seconds = maxf(0, feedback_seconds-delta)
	var cards := tower_map.get_node_or_null("../CardPlacement")
	if cards != null and (cards.input_suspended or cards.selected >= 0): return
	var tower: DefenseTower
	if feedback_seconds > 0 and is_instance_valid(feedback_tower): tower = feedback_tower
	elif get_viewport().gui_get_hovered_control() == null:
		tower = tower_map.upgrade_target(tower_map.placement.pick_cell(get_viewport().get_mouse_position()))
	if not is_instance_valid(tower) or tower.is_queued_for_deletion(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var anchor := tower.global_position+Vector3.UP*(1.6+feedback_seconds*0.15)
	if camera.is_position_behind(anchor): return
	var title := tower.definition.localized_name()
	var level_text := "Lv.%d" % tower.level
	if tower_name.text != title or tower_level.text != level_text:
		tower_name.text = title
		tower_level.text = level_text
		_update_size()
	position = camera.unproject_position(anchor)-Vector2(size.x*0.5,size.y)
	if not get_viewport_rect().intersects(get_rect()): return
	show()

func _update_size() -> void:
	var minimum: Vector2 = $Margin/Content.get_combined_minimum_size()
	custom_minimum_size = minimum+Vector2(24,24)
	size = custom_minimum_size
	$Shape.frame_size = size
