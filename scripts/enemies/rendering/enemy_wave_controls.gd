extends CanvasLayer
## One start action. Troop and route distribution are authored in wave resources.
signal spawn_requested
var spawn_button: Button
var start_pending := false:
	set(value):
		start_pending = value
		if value and is_instance_valid(spawn_button):
			spawn_button.disabled = true
var _scene_action := false

func set_shop_present(value: bool) -> void:
	if _scene_action or not is_instance_valid(spawn_button): return
	var right := -16.0-(ShopConstants.CARD_SIZE.x*CardFanLayout.CARD_SCALE+24 if value else 0.0)
	spawn_button.offset_left = right-40
	spawn_button.offset_right = right

func configure(_troops: Array[Troop], button: Button = null) -> void:
	if button != null:
		_scene_action = true
		$Root.hide()
		spawn_button = button
		spawn_button.pressed.connect(func(): spawn_requested.emit())
		return
	spawn_button = $Root/Start
	spawn_button.pressed.connect(func(): spawn_requested.emit())
	set_shop_present(false)

func refresh(wave: Node, _selected: Troop, ready: bool) -> void:
	if not is_instance_valid(spawn_button): return
	spawn_button.disabled = start_pending or wave.active or not ready
