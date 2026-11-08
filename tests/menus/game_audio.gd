extends SceneTree
const Settings = preload("res://scripts/settings/game_settings.gd")
var failures := 0
var audio: Node

func _initialize() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func advance(seconds: float) -> void:
	audio._last_usec = Time.get_ticks_usec()-int(seconds*1000000.0)
	audio._process(0.0)

func verify() -> void:
	RenderingServer.set_default_clear_color(Color.WHITE)
	audio = root.get_node("GameAudio")
	check(is_equal_approx(Settings.read(root)[&"bgm_volume"], 50.0), "BGM slider should retain its 50 percent default")
	var button := Button.new()
	root.add_child(button)
	button.pressed.emit()
	check(audio._effects[&"click"].playing and audio._effects[&"click"].bus == &"Master", "Buttons must play the UI click through Master")
	button.mouse_entered.emit()
	check(audio._effects[&"hover"].playing, "Buttons must play their hover cue")
	for kind in [&"hover", &"card_hover"]:
		check(audio._effects[kind].volume_linear < audio._effects[&"click"].volume_linear and audio._effects[kind].bus == &"Master", "Hover cues must be quieter than clicks and controlled by Master")
	audio._effects[&"hover"].stop()
	button.disabled = true
	button.mouse_entered.emit()
	check(not audio._effects[&"hover"].playing, "Disabled buttons must not play hover audio")
	button.disabled = false
	button.add_to_group("audio_card_hover")
	button.mouse_entered.emit()
	check(audio._effects[&"card_hover"].playing and not audio._effects[&"hover"].playing, "Card choices must use only the card hover cue")
	button.queue_free()
	check(audio._desired == audio.DEFAULT, "Startup should use peaceful music")
	check(audio.DEFAULT is AudioStreamOggVorbis and audio.BATTLE is AudioStreamOggVorbis, "Both music tracks must use the supplied OGG versions")
	check(audio.DEFAULT.get_length() > 10.0 and audio.BATTLE.get_length() > 10.0, "Music imports must decode")
	check(not audio.DEFAULT.loop and not audio.BATTLE.loop and audio.BUGLE.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Native looping must remain disabled")
	advance(2.0)
	check(is_equal_approx(audio._voices[audio._active].volume_linear, 0.5), "Music source gain must be halved independently of the volume slider")
	audio.begin_wave()
	check(audio._bugle.playing and audio._battle_at > 0.0, "Opening must play a single cue before battle music")
	check(is_equal_approx(audio._bugle.volume_linear, 0.5), "Opening horn should use half gain")
	var deadline: float = audio._battle_at
	audio.begin_wave()
	check(audio._battle_at == deadline, "Wave signal must not restart the opening cue")
	advance(0.75)
	check(is_equal_approx(audio._voices[0].volume_linear, 0.25), "Outgoing music must fade during the horn")
	audio._battle_at = 0.001
	advance(0.1)
	check(audio._voices[audio._active].stream == audio.BATTLE, "Horn must lead into battle music")
	advance(2.0)
	var old_voice: AudioStreamPlayer = audio._voices[audio._active]
	old_voice.seek(old_voice.stream.get_length()-1.9)
	await create_timer(0.1, true, false, true).timeout
	check(audio._voices[audio._active] != old_voice and old_voice.playing, "Loop must overlap outgoing tail with a fresh head")
	advance(2.0)
	audio.play_default()
	check(audio._fade_seconds == 4.0, "Returning to peaceful music must use a slower four-second envelope")
	check(audio._battle_at == 0.0 and audio._desired == audio.DEFAULT, "Wave end must restore peaceful music")
	advance(0.3)
	check(not audio._bugle.playing, "Wave end must not play a horn")
	var gain: float = audio._voices[audio._active].volume_linear
	paused = true
	Engine.time_scale = 4.0
	await create_timer(0.2, true, false, true).timeout
	var increase: float = audio._voices[audio._active].volume_linear-gain
	check(increase > 0.005 and increase < 0.045, "Fades must use real time during pause and 4x speed")
	paused = false
	Engine.time_scale = 1.0
	audio.begin_wave()
	audio.play_default()
	advance(0.3)
	check(audio._battle_at == 0.0 and not audio._bugle.playing, "Interrupted opening must cancel delayed battle and fade its cue")
	audio.play_victory()
	check(audio._victory_pending and audio._victory.playing and audio._active == -1 and not audio.VICTORY.loop,"Victory must play one non-looping cue before resuming music")
	advance(0.35)
	check(audio._voices.all(func(voice): return not voice.playing),"Background music must fade out while the victory cue plays")
	var fade_age: float = audio._fade_age
	audio.play_victory()
	check(audio._fade_age == fade_age,"Duplicate victory requests must not restart the cue or music fade")
	audio._victory.stop()
	audio._victory.finished.emit()
	check(not audio._victory_pending and audio._active >= 0 and audio._voices[audio._active].stream == audio.DEFAULT,"Victory cue completion must fade back to peaceful music")
	advance(2.0)
	check(is_equal_approx(audio._voices[audio._active].volume_linear,audio.BGM_GAIN),"Music must regain its normal source gain after victory")
	audio.play_victory()
	audio.play_default()
	advance(0.25)
	check(not audio._victory_pending and not audio._victory.playing,"Leaving victory must fade out the cue and cancel its delayed music resume")
	print("VICTORY_CUE_SECONDS=",audio.VICTORY.get_length())
	for pair in [[&"master_volume", &"Master"], [&"bgm_volume", &"BGM"], [&"combat_volume", &"Combat"]]:
		Settings.apply(pair[0], 37.0, root)
		check(is_equal_approx(Settings.read(root)[pair[0]], 37.0), "Volume must round-trip through settings")
		Settings.apply(pair[0], 0.0, root)
		check(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(pair[1])) == 0.0, "Zero volume must silence the bus")
		Settings.apply(pair[0], 100.0, root)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"BGM")) == &"Master" and audio._bugle.bus == &"Combat", "Music and horn must route into separate Master-controlled buses")
	var page: Control = load("res://scenes/settings/settings_page.tscn").instantiate()
	root.add_child(page)
	page.configure(Settings.sections(), Settings.read(root))
	page.option_changed.connect(func(key, value): Settings.apply(key, value, root))
	page.open()
	page._select(2)
	await process_frame
	for i in range(1, 4):
		var slider: HSlider = page.rows.get_child(i).get_node("Value").get_child(0)
		slider.value = 42
		check(is_equal_approx(Settings.read(root)[[&"master_volume", &"bgm_volume", &"combat_volume"][i-1]], 42.0), "Visible sliders must apply immediately")
		slider.grab_focus()
		var event := InputEventAction.new()
		event.action = &"ui_left"
		event.pressed = true
		root.push_input(event, true)
		await process_frame
		check(slider.value == 41.0, "Volume sliders must support keyboard adjustment")
		var release := InputEventAction.new()
		release.action = &"ui_left"
		root.push_input(release, true)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/audio-settings.png")
	page.queue_free()
	await process_frame
	audio.queue_free()
	await create_timer(0.15, true, false, true).timeout
	print("GAME AUDIO failures=", failures)
	quit(0 if failures == 0 else 1)
