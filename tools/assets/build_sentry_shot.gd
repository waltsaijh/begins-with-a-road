extends SceneTree
## Deterministic bow-string pluck + short arrow air transient. No external samples.
const OUTPUT := "res://assets/audio/towers/sentry_shot.wav"
const RATE := 48000
const SECONDS := 0.22

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	var delay := PackedFloat64Array()
	delay.resize(173)
	for i in delay.size(): delay[i] = rng.randf_range(-1.0, 1.0)
	var samples := PackedFloat64Array()
	samples.resize(int(RATE*SECONDS))
	var low := 0.0
	var previous := 0.0
	var peak := 0.0
	for i in samples.size():
		var time := float(i)/RATE
		var at := i%delay.size()
		var string := delay[at]
		delay[at] = (string+delay[(at+1)%delay.size()])*0.485
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.24)
		var air := low-previous
		previous = low
		var release := sin(TAU*850.0*time)*exp(-time/0.006)
		var attack := smoothstep(0.0, 0.0015, time)
		var tail := 1.0-smoothstep(0.13, SECONDS, time)
		var value := (string*0.65*exp(-time/0.075)+air*1.7*exp(-time/0.026)+release*0.15)*attack*tail
		samples[i] = value
		peak = maxf(peak, absf(value))
	var pcm := PackedByteArray()
	pcm.resize(samples.size()*2)
	for i in samples.size():
		pcm.encode_s16(i*2, int(clampf(samples[i]/peak*0.8, -1.0, 1.0)*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.stereo = false
	sound.data = pcm
	var error := sound.save_to_wav(OUTPUT)
	print("SENTRY_SHOT_BUILD: ", error_string(error), " / ", SECONDS, "s mono 48kHz")
	quit(0 if error == OK else 1)
