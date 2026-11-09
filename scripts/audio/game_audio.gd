extends Node
## Real-time music envelopes stay independent of simulation speed and pause.
const DEFAULT = preload("res://assets/audio/music/bgm_default.ogg")
const BATTLE = preload("res://assets/audio/music/bgm_battle.ogg")
const BUGLE = preload("res://assets/audio/music/sfx_bugle_cue.wav")
const VICTORY = preload("res://assets/audio/music/victory.mp3")
const CLICK = preload("res://assets/audio/ui/click.wav")
const HOVER = preload("res://assets/audio/ui/hover.mp3")
const CARD_HOVER = preload("res://assets/audio/ui/card_hover.mp3")
const PLACEMENT = preload("res://assets/audio/placement/placement.wav")
const WRONG_PLACEMENT = preload("res://assets/audio/placement/wrong_placement.wav")
const GAIN_GOLD = preload("res://assets/audio/ui/gain_gold.mp3")
var _gold_ready_usec := 0

func play_gold() -> void:
	var now := Time.get_ticks_usec()
	if get_tree().paused or now < _gold_ready_usec: return
	var player: AudioStreamPlayer = _effects[&"gain_gold"]
	if player.playing: return
	_gold_ready_usec = now+250000
	player.play()

func stop_gold() -> void:
	if _effects.has(&"gain_gold"): _effects[&"gain_gold"].stop()
const FADE_SECONDS := 1.5
const RETURN_SECONDS := 4.0
const LOOP_SECONDS := 2.0
const DEFAULT_BGM_VOLUME := 0.5
const BGM_GAIN := 0.5
const BUGLE_GAIN := 0.5
const VICTORY_GAIN := 0.8
## Per-clip base volume. 0.0 = silent, 1.0 = original file volume.
const CLICK_GAIN := 0.55
const EFFECT_GAINS := {
	&"click": CLICK_GAIN*0.2,
	&"hover": CLICK_GAIN*0.25,
	&"card_hover": CLICK_GAIN*0.25,
	&"placement": 1.0,
	&"wrong_placement": 1.0,
	&"gain_gold": 0.35,
}
var _voices: Array[AudioStreamPlayer] = []
var _targets: Array[float] = [0.0, 0.0]
var _active := -1
var _desired: AudioStream
var _bugle: AudioStreamPlayer
var _battle_at := 0.0
var _last_usec := 0
var _fade_from: Array[float] = [0.0, 0.0]
var _fade_age := 0.0
var _fade_seconds := FADE_SECONDS
var _effects: Dictionary = {}
var _victory: AudioStreamPlayer
var _victory_pending := false
var _victory_target := 0.0

func play_effect(kind: StringName) -> void:
	if _effects.has(kind): _effects[kind].play()

func _watch_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_button_clicked):
		node.pressed.connect(_button_clicked)
		# Fan cards use their stable pointer picker, avoiding animation-triggered repeats.
		if not node is CardButton:
			node.mouse_entered.connect(_button_hovered.bind(node))

func _button_hovered(button: BaseButton) -> void:
	if button.disabled or not button.is_visible_in_tree() or not button.can_process() or button.mouse_filter == Control.MOUSE_FILTER_IGNORE: return
	play_effect(&"card_hover" if button.is_in_group("audio_card_hover") else &"hover")

func _button_clicked() -> void:
	play_effect(&"click")

func _fade_to(targets: Array[float], seconds: float) -> void:
	_fade_from.assign([_voices[0].volume_linear, _voices[1].volume_linear])
	_targets = targets
	_fade_age = 0.0
	_fade_seconds = seconds

func _exit_tree() -> void:
	for player in _voices:
		player.stop()
		player.stream = null
	_bugle.stop()
	_bugle.stream = null
	_victory.stop()
	_victory.stream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in [&"BGM", &"Combat"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			# Web Sample playback misorders buses when add_bus() appends (-1).
			# Growing the count preserves Master -> destination and bus indices.
			var index := AudioServer.bus_count
			AudioServer.bus_count = index+1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(&"BGM"), DEFAULT_BGM_VOLUME)
	var streams := {&"click": CLICK, &"hover": HOVER, &"card_hover": CARD_HOVER, &"placement": PLACEMENT, &"wrong_placement": WRONG_PLACEMENT, &"gain_gold": GAIN_GOLD}
	for kind in streams:
		var effect := AudioStreamPlayer.new()
		effect.bus = &"Combat" if kind in [&"placement", &"wrong_placement", &"gain_gold"] else &"Master"
		effect.stream = streams[kind]
		var hovering: bool = kind in [&"hover", &"card_hover"]
		effect.volume_linear = EFFECT_GAINS[kind]
		effect.max_polyphony = 1 if hovering else 4
		if kind == &"gain_gold":
			effect.max_polyphony = 1
			effect.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(effect)
		_effects[kind] = effect
	get_tree().node_added.connect(_watch_button)
	for node in get_tree().root.find_children("*", "BaseButton", true, false): _watch_button(node)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"BGM"
		player.volume_linear = 0.0
		add_child(player)
		_voices.append(player)
	_bugle = AudioStreamPlayer.new()
	_bugle.bus = &"Combat"
	add_child(_bugle)
	_bugle.stream = BUGLE
	_victory = AudioStreamPlayer.new()
	_victory.bus = &"BGM"
	_victory.stream = VICTORY
	_victory.volume_linear = 0.0
	add_child(_victory)
	_victory.finished.connect(_on_victory_finished)
	_last_usec = Time.get_ticks_usec()
	play_default()

func play_default() -> void:
	_victory_pending = false
	_victory_target = 0.0
	_battle_at = 0.0
	var returning := _desired == BATTLE
	_desired = DEFAULT
	# Cancel an interrupted opening cue gently, without playing an ending cue.
	_switch(DEFAULT, RETURN_SECONDS if returning else FADE_SECONDS)

func play_victory() -> void:
	if _victory_pending: return
	_battle_at = 0.0
	_desired = DEFAULT
	_victory_pending = true
	_victory_target = VICTORY_GAIN
	_victory.volume_linear = 0.0
	_fade_to([0.0,0.0],0.3)
	_active = -1
	_victory.play()

func _on_victory_finished() -> void:
	if not _victory_pending: return
	_victory_pending = false
	_victory_target = 0.0
	_switch(DEFAULT,FADE_SECONDS)

func begin_wave() -> void:
	if _desired == BATTLE: return
	_victory_pending = false
	_victory_target = 0.0
	_desired = BATTLE
	_fade_to([0.0, 0.0], FADE_SECONDS)
	_active = -1
	_bugle.volume_linear = BUGLE_GAIN
	_bugle.play()
	_battle_at = Time.get_ticks_usec()/1000000.0+maxf(0.0, BUGLE.get_length()-0.5)

func _switch(stream: AudioStream, seconds := FADE_SECONDS) -> void:
	if _active >= 0 and _voices[_active].stream == stream and _targets[_active] > 0.0: return
	# Reverse an in-flight fade from its current gain when returning quickly.
	for i in _voices.size():
		if _voices[i].stream == stream and _voices[i].playing:
			var targets: Array[float] = [0.0, 0.0]
			targets[i] = BGM_GAIN
			_fade_to(targets, seconds)
			_active = i
			return
	var next := 0 if _active < 0 else 1-_active
	if _active < 0 and _voices[0].volume_linear > _voices[1].volume_linear: next = 1
	var targets: Array[float] = [0.0, 0.0]
	targets[next] = BGM_GAIN
	var player := _voices[next]
	player.stop()
	player.stream = stream
	player.volume_linear = 0.0
	player.play()
	_active = next
	_fade_to(targets, seconds)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := maxf(0.0, (now-_last_usec)/1000000.0)
	_last_usec = now
	_victory.volume_linear = move_toward(_victory.volume_linear,_victory_target,elapsed*VICTORY_GAIN/(0.08 if _victory_pending else 0.2))
	if not _victory_pending and _victory.volume_linear <= 0.0 and _victory.playing: _victory.stop()
	if _battle_at > 0.0 and now/1000000.0 >= _battle_at:
		_battle_at = 0.0
		_switch(BATTLE)
	if _desired != BATTLE and _bugle.playing:
		_bugle.volume_linear = move_toward(_bugle.volume_linear, 0.0, elapsed*BUGLE_GAIN/0.25)
		if _bugle.volume_linear <= 0.0: _bugle.stop()
	_fade_age = minf(_fade_seconds, _fade_age+elapsed)
	var weight := smoothstep(0.0, _fade_seconds, _fade_age)
	for i in _voices.size():
		var player := _voices[i]
		player.volume_linear = lerpf(_fade_from[i], _targets[i], weight)
		if _targets[i] == 0.0 and player.volume_linear <= 0.0: player.stop()
	if _active < 0: return
	var current := _voices[_active]
	# Imported music has native looping disabled; overlap the tail and new head.
	if current.stream.get_length()-current.get_playback_position() <= LOOP_SECONDS:
		var stream := current.stream
		_active = 1-_active
		_targets[_active] = BGM_GAIN
		_targets[1-_active] = 0.0
		_voices[_active].stream = stream
		_voices[_active].volume_linear = 0.0
		_voices[_active].play()
		_fade_to(_targets.duplicate(), FADE_SECONDS)
