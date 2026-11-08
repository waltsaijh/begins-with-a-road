extends Control
## One quiet UI-only burst. Local RNG never affects the simulation or card draws.
const COUNT_PER_SIDE := 12
const DURATION := 1.4
const DRAG := 0.9
const COLORS := [Color(0.78,0.71,0.52),Color(0.54,0.67,0.7),Color(0.86,0.82,0.7),Color(0.57,0.73,0.7)]
var _started := false
var _elapsed := 0.0
var _last_usec := 0
var _content: Control
var _particles: Array[Dictionary] = []

func _ready() -> void:
	set_process(false)

func burst(content: Control) -> void:
	if _started: return
	_started = true
	_content = content
	_elapsed = 0.0
	_last_usec = Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261108
	for side in [-1,1]:
		for i in COUNT_PER_SIDE:
			_particles.append({"side":side,"delay":(0.08 if side < 0 else 0.13)+rng.randf_range(0,0.03),
				"life":rng.randf_range(0.95,1.13),"velocity":Vector2(side*rng.randf_range(100,210),rng.randf_range(-240,-80)),
				"x":rng.randf_range(-5,5),"y":rng.randf_range(-12,12),"angle":rng.randf_range(-PI,PI),"spin":rng.randf_range(-4,4),
				"kind":i%4,"color":COLORS[i%COLORS.size()]})
	set_process(true)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_elapsed += (now-_last_usec)/1000000.0
	_last_usec = now
	if _elapsed >= DURATION:
		_particles.clear()
		set_process(false)
	queue_redraw()

func content_rect() -> Rect2:
	var transform := get_global_transform_with_canvas().affine_inverse()*_content.get_global_transform_with_canvas()
	return transform*Rect2(Vector2.ZERO,_content.size)

func particle_pose(particle: Dictionary) -> Dictionary:
	var age: float = _elapsed-particle.delay
	if age < 0.0 or age >= particle.life or not is_instance_valid(_content): return {}
	var content := content_rect()
	var x := maxf(14.0,content.position.x-54.0) if particle.side < 0 else minf(size.x-14.0,content.end.x+54.0)
	var origin := Vector2(x+particle.x,content.position.y+content.size.y*0.43+particle.y)
	var travel := (1.0-exp(-DRAG*age))/DRAG
	var point := origin+Vector2(particle.velocity.x*travel,particle.velocity.y*age+175.0*age*age)
	# Keep all decorative paper outside the text/statistics/button composition.
	if content.grow(8.0).has_point(point): return {}
	return {"position":point,"rotation":particle.angle+particle.spin*travel,
		"alpha":0.82*smoothstep(0.0,0.035,age)*(1.0-smoothstep(0.55,particle.life,age)),
		"scale":1.0-0.12*age/particle.life}

func _draw() -> void:
	for particle in _particles:
		var pose := particle_pose(particle)
		if pose.is_empty(): continue
		draw_set_transform(pose.position,pose.rotation,Vector2.ONE*pose.scale)
		var color := Color(particle.color,pose.alpha)
		match particle.kind:
			0: draw_rect(Rect2(-4,-0.9,8,1.8),color)
			1: draw_rect(Rect2(-2.2,-1.4,4.4,2.8),color)
			2: draw_colored_polygon(PackedVector2Array([Vector2(0,-2.5),Vector2(1.8,0),Vector2(0,2.5),Vector2(-1.8,0)]),color)
			3: draw_colored_polygon(PackedVector2Array([Vector2(-2,1.8),Vector2(2,1.8),Vector2(0,-2)]),color)
	draw_set_transform(Vector2.ZERO)
