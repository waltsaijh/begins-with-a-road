extends Node3D
## F6 art comparison. The profiles supply the same mesh, material and gait as battle.
const IDS := ["soldier","winged","heavy","scout","rook","bloodmage","rats","quickfeet","bomber"]
const Library = preload("res://assets/models/mesh_library.tres")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var models: Array[MultiMeshInstance3D] = []
var labels: Array[Label] = []
var ground: Array[Vector3] = []
var periods: Array[float] = []
var elapsed := 0.0

func _ready() -> void:
	var right := Vector3(cos(PI/6),0,-sin(PI/6))
	var near := Vector3(sin(PI/6),0,cos(PI/6))
	$Camera.position = (near+Vector3.UP)*20
	$Camera.look_at(Vector3.ZERO)
	for i in IDS.size():
		var troop := TroopCatalog.find(IDS[i])
		var at := right*((i%3)-1)*2.25 + near*(floori(i/3.0)-1)*2.62
		at.y = -0.12
		ground.append(at)
		var tile := MeshInstance3D.new()
		tile.mesh = Library.get_item_mesh(3)
		tile.position = at
		add_child(tile)
		var view := MultiMeshInstance3D.new()
		view.multimesh = MultiMesh.new()
		view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		view.multimesh.use_colors = true
		view.multimesh.use_custom_data = true
		view.multimesh.mesh = troop.gpu_model.mesh
		var mice: bool = IDS[i] == "rats"
		var count := troop.cohort_size if mice else 1
		view.multimesh.instance_count = count
		view.material_override = troop.gpu_model.material()
		var yaw := -1.8 if IDS[i] in ["quickfeet","rats"] else PI
		if IDS[i] == "soldier": yaw = -2.0
		if IDS[i] == "quickfeet": yaw = -1.18
		if IDS[i] == "bomber": yaw = -0.45
		for member in count:
			var basis := Basis(Vector3.UP,yaw)
			var offset := Vector3.ZERO
			if mice:
				offset = Vector3((member%2-.5)*.25,0,(floori(member/2.0)-1)*.25)
				basis = basis.scaled(Vector3.ONE*(1.0+.09*sin(member*2.39996)))
			view.multimesh.set_instance_color(member,Color.WHITE)
			view.multimesh.set_instance_transform(member,Transform3D(basis,at+offset+Vector3.UP*troop.flight_height))
		add_child(view)
		models.append(view)
		periods.append(troop.gpu_model.clip_length)
		var label := Label.new()
		label.text = tr(troop.name_key)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_color",Color("#353e42"))
		$Labels.add_child(label)
		labels.append(label)
	get_viewport().size_changed.connect(layout)
	layout()
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()

func layout() -> void:
	for i in labels.size():
		var label := labels[i]
		label.reset_size()
		label.position = $Camera.unproject_position(ground[i]+Vector3.DOWN*1.14)-Vector2(label.size.x/2,0)

func _process(delta: float) -> void:
	elapsed += delta
	for i in models.size():
		var phase := fposmod(elapsed/periods[i]*TAU+i*2.39996,TAU)
		for member in models[i].multimesh.instance_count:
			models[i].multimesh.set_instance_custom_data(member,Color(fposmod(phase+member*2.39996,TAU),1,0,0))

func capture() -> void:
	await get_tree().create_timer(.35).timeout
	# A repeatable still with spread wings; the interactive gallery keeps playing.
	set_process(false)
	elapsed = 0.0
	_process(0.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("enemies/slice_a/gallery.png"))
	get_tree().quit()

