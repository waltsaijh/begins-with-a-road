extends MultiMeshInstance2D
## Ordered quads share one atlas, material and buffer submission.
const StatusShader = preload("res://assets/shaders/enemy_status.gdshader")
const STRIDE := 16 # 2D transform (8), color (4), atlas rect (4).
var _buffer := PackedFloat32Array()
var count := 0

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.5, 0.5, 0)
	multimesh.mesh = quad
	var shader_material := ShaderMaterial.new()
	shader_material.shader = StatusShader
	material = shader_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func begin() -> void:
	count = 0

func append(rect: Rect2, region: Rect2, color := Color.WHITE) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0: return
	if count == multimesh.instance_count:
		multimesh.instance_count = maxi(64, count*2)
		_buffer.resize(multimesh.instance_count*STRIDE)
	var offset := count*STRIDE
	_buffer[offset] = rect.size.x
	_buffer[offset+1] = 0.0
	_buffer[offset+2] = 0.0
	_buffer[offset+3] = rect.position.x
	_buffer[offset+4] = 0.0
	_buffer[offset+5] = rect.size.y
	_buffer[offset+6] = 0.0
	_buffer[offset+7] = rect.position.y
	_buffer[offset+8] = color.r
	_buffer[offset+9] = color.g
	_buffer[offset+10] = color.b
	_buffer[offset+11] = color.a
	_buffer[offset+12] = region.position.x
	_buffer[offset+13] = region.position.y
	_buffer[offset+14] = region.size.x
	_buffer[offset+15] = region.size.y
	count += 1

func submit() -> void:
	if count > 0: multimesh.buffer = _buffer
	multimesh.visible_instance_count = count
	visible = count > 0

func clear() -> void:
	count = 0
	multimesh.visible_instance_count = 0
	hide()
