extends Control
## Bounded presentation pool. Accounting belongs exclusively to CardShop.
const LIMIT := 6
const LIFETIME := 0.6
const MERGE_SECONDS := 0.25
const MERGE_DISTANCE := 70.0
@export var popup_scene: PackedScene
var entries: Array[Dictionary] = []
var wallet: Label
var _wallet_motion: Tween
var _wallet_ready_at := 0.0
var _clock := 0.0
var _last_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	for i in LIMIT:
		var view: Control = popup_scene.instantiate()
		add_child(view)
		entries.append({"view":view,"amount":0,"age":LIFETIME,"world":Vector3.ZERO,"motion":null,"pulse":null})

func setup(shop: Node, amount_label: Label) -> void:
	wallet = amount_label
	shop.gold_granted.connect(_on_gold_granted)
	get_parent().get_parent().run_finished.connect(func(_won): clear())

func _on_gold_granted(amount: int, _reason: String, world: Variant) -> void:
	if amount <= 0: return
	_wallet_feedback()
	if world is Vector3:
		show_gain(world, amount)
		GameAudio.play_gold()

func _wallet_feedback() -> void:
	if not is_instance_valid(wallet) or _clock < _wallet_ready_at: return
	_wallet_ready_at = _clock+MERGE_SECONDS
	if _wallet_motion: _wallet_motion.kill()
	wallet.pivot_offset = wallet.size*0.5
	_wallet_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_wallet_motion.tween_property(wallet,"scale",Vector2.ONE*1.055,0.08)
	_wallet_motion.tween_property(wallet,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_SINE)

func show_gain(world: Vector3, amount: int) -> void:
	if amount <= 0 or get_tree().paused: return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world): return
	var point := _project(camera,world)
	if not Rect2(Vector2.ZERO,size).has_point(point): return
	var chosen: Dictionary = {}
	var nearest := MERGE_DISTANCE
	for entry in entries:
		if entry.age > MERGE_SECONDS: continue
		if camera.is_position_behind(entry.world): continue
		var distance := point.distance_to(_project(camera,entry.world))
		if distance <= nearest:
			chosen = entry
			nearest = distance
	if not chosen.is_empty():
		chosen.amount += amount
		_pulse(chosen)
		return
	for entry in entries:
		if entry.age < LIFETIME: continue
		entry.amount = amount
		entry.world = world
		entry.age = 0.0
		entry.view.modulate.a = 0.0
		entry.motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		entry.motion.tween_method(func(value: float): entry.age = value,0.0,LIFETIME,LIFETIME)
		_pulse(entry)
		_position(entry,camera)
		return
	# All six occupied: omission affects neither the wallet nor the sound budget.

func _pulse(entry: Dictionary) -> void:
	if entry.pulse: entry.pulse.kill()
	entry.view.scale = Vector2.ONE*0.94
	entry.pulse = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	entry.pulse.tween_property(entry.view,"scale",Vector2.ONE*1.08,0.07)
	entry.pulse.tween_property(entry.view,"scale",Vector2.ONE,0.13).set_trans(Tween.TRANS_SINE)

func _project(camera: Camera3D, world: Vector3) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(world)

func _position(entry: Dictionary, camera: Camera3D) -> void:
	var view: Control = entry.view
	view.visible = not camera.is_position_behind(entry.world)
	if not view.visible: return
	var point := _project(camera,entry.world)
	view.visible = Rect2(Vector2.ZERO,size).has_point(point)
	var t: float = entry.age/LIFETIME
	# Foreshorten around the vertical diameter: face, edge, reverse, face.
	var coin: Control = view.get_node("Coin")
	var face := cos(TAU*t)
	coin.pivot_offset = coin.size*0.5
	coin.scale.x = signf(face)*maxf(absf(face),0.09)
	coin.self_modulate = Color.WHITE*(0.84+0.16*absf(face))
	coin.self_modulate.a = 1.0
	var rise := 8.0*(1.0-pow(1.0-minf(t/0.25,1.0),2.0))+12.0*t
	view.pivot_offset = view.size*0.5
	var margin := Vector2.ONE*5.0+view.size*0.04
	view.position = (point-view.size*0.5-Vector2(0,rise)).clamp(margin,(size-view.size-margin).max(margin))
	view.modulate.a = minf(entry.age/0.05,1.0)*(1.0-smoothstep(0.32,LIFETIME,entry.age))

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if not get_tree().paused: _clock += (now-_last_usec)/1000000.0
	_last_usec = now
	var camera := get_viewport().get_camera_3d()
	for entry in entries:
		if entry.age >= LIFETIME or camera == null:
			entry.view.hide()
		else: _position(entry,camera)

func clear() -> void:
	for entry in entries:
		if entry.motion: entry.motion.kill()
		if entry.pulse: entry.pulse.kill()
		entry.motion = null
		entry.pulse = null
		entry.age = LIFETIME
		entry.view.hide()
	if _wallet_motion: _wallet_motion.kill()
	if is_instance_valid(wallet): wallet.scale = Vector2.ONE
	GameAudio.stop_gold()

func _exit_tree() -> void:
	clear()
