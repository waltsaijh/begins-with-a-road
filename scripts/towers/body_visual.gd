extends RefCounted
## Footprint-specific low-poly assemblies. Cached scenes share meshes/materials;
## each instance owns its recoil, markers and level visibility.
const MOTION = preload("res://scripts/towers/restored_tower_visual.gd")
const MATERIAL = preload("res://assets/materials/solid_color.tres")
const FLAGS = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const WOOD := Color("846b55")
const DECK := Color("c2aa80")
const IRON := Color("405763")
const LIGHT := Color("e8dcc0")
static var cache := {}

static func create(definition: TowerDefinition, body: Array[Vector2i]) -> Node3D:
	if definition.visual_model != null:
		var authored := definition.visual_model.instantiate()
		if authored.has_method("supports_body") and authored.supports_body(definition.footprint if body.is_empty() else body):
			authored.configure(definition,body)
			return authored
		authored.free()
	if body.is_empty() or definition.deployment != null: return definition.model.instantiate()
	var ordered := body.duplicate()
	ordered.sort()
	var key := str([definition.resource_path,definition.name_key,ordered])
	if not cache.has(key):
		var root := _build(definition,body)
		_merge_static(root)
		_own(root,root)
		var scene := PackedScene.new()
		scene.pack(root)
		root.free()
		cache[key] = scene
	return cache[key].instantiate()

static func _merge_static(parent: Node3D) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh != null: parts.append(child)
		elif child is Node3D: _merge_static(child)
	if parts.size() < 2: return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
	surface.set_custom_format(1,SurfaceTool.CUSTOM_RG_FLOAT)
	surface.set_material(MATERIAL)
	for instance in parts:
		for index in instance.mesh.get_surface_count(): surface.append_from(instance.mesh,index,instance.transform)
		instance.free()
	var merged := MeshInstance3D.new(); merged.name = "AssemblyMesh"; merged.mesh = surface.commit(); parent.add_child(merged)

static func _own(node: Node, root: Node) -> void:
	for child in node.get_children(): child.owner = root; _own(child,root)

static func set_level(root: Node3D, level: int) -> void:
	for node in root.find_children("Level*","Node3D",true,false):
		node.visible = level >= int(String(node.name).trim_prefix("Level"))

static func group(parent: Node3D, title: String, position := Vector3.ZERO) -> Node3D:
	var node := Node3D.new(); node.name = title; node.position = position; parent.add_child(node)
	return node

static func part(parent: Node3D, primitive: PrimitiveMesh, color: Color, position: Vector3, rotation := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var arrays := primitive.get_mesh_arrays()
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var colors := PackedColorArray(); colors.resize(count); colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var zeros := PackedFloat32Array(); zeros.resize(count*4); arrays[Mesh.ARRAY_CUSTOM0] = zeros
	var response := PackedFloat32Array()
	for i in count: response.append(0.98); response.append(0.12)
	arrays[Mesh.ARRAY_CUSTOM1] = response
	var uv := PackedVector2Array(); uv.resize(count); arrays[Mesh.ARRAY_TEX_UV2] = uv
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},FLAGS)
	mesh.surface_set_material(0,MATERIAL)
	var instance := MeshInstance3D.new(); instance.mesh = mesh
	instance.position = position; instance.rotation = rotation; instance.scale = scale; parent.add_child(instance)
	return instance

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new(); mesh.size = size; part(parent,mesh,color,at,rotation)

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, rotation := Vector3.ZERO, top := -1.0) -> void:
	var mesh := CylinderMesh.new(); mesh.bottom_radius = radius; mesh.top_radius = radius if top < 0 else top
	mesh.height = height; mesh.radial_segments = 8; mesh.rings = 1
	part(parent,mesh,color,at,rotation)

static func marker(root: Node3D, parent: Node3D, at: Vector3) -> void:
	var node := Marker3D.new(); node.name = "Muzzle%d" % root.get_meta("muzzle_paths",[]).size(); node.position = at; parent.add_child(node)
	var paths: Array = root.get_meta("muzzle_paths",[]); paths.append(root.get_path_to(node)); root.set_meta("muzzle_paths",paths)

static func _build(definition: TowerDefinition, body: Array[Vector2i]) -> Node3D:
	var key := definition.name_key.get_slice(".",1)
	var root := Node3D.new()
	var c := TowerBodyGeometry.origin(definition,body)
	var rect := TowerBodyGeometry.bounds(body)
	var center := Vector3(c.x,0,c.y)
	var accent := definition.accent_color
	if key == "sentry":
		root.free(); root = definition.model.instantiate()
		var upper := group(root,"Level2")
		for x in [-0.31,0.31]: box(upper,Vector3(x,0.6,0.22),Vector3(0.07,0.8,0.07),WOOD)
		box(upper,Vector3(0,0.87,0.22),Vector3(0.7,0.09,0.08),accent)
		var flag := group(root,"Level3")
		cylinder(flag,Vector3(-0.34,1.0,0.28),0.025,1.1,IRON)
		box(flag,Vector3(-0.18,1.42,0.28),Vector3(0.3,0.22,0.025),accent)
		box(flag,Vector3(0,0.18,0),Vector3(0.82,0.06,0.82),IRON)
		set_level(root,1); return root
	root.set_script(MOTION)
	root.set_meta("body_center",center)
	root.kind = {"mortar":1,"ballista":2,"broadside":3,"crossfire":4}.get(key,2)
	# Reuse the authored sound, while replacing the geometry and muzzle layout.
	var source := definition.model.instantiate()
	if source.get("shot_sound") != null: root.shot_sound = source.shot_sound
	source.free()
	var moving := root
	if key == "broadside":
		var base := group(root,"FixedBase")
		for cell in body:
			cylinder(base,Vector3(cell.x,0.1,cell.y),0.38,0.2,IRON)
			cylinder(base,Vector3(cell.x,0.29,cell.y),0.12,0.25,DECK)
		moving = group(root,"Airship"); root.moving_body_path = NodePath("Airship")
	# Ground belongs to TileVisuals. Do not stack one generic box per body cell
	# underneath the authored carriage / octagonal weapon base.
	var recoil := group(moving,"RecoilAssembly")
	var lv2 := group(moving,"Level2")
	var lv3 := group(moving,"Level3")
	match key:
		"ballista":
			var length := float(rect.size.y)
			for x in [-0.24,0.24]:
				box(root,center+Vector3(x,0.35,0),Vector3(0.11,0.25,length-0.15),IRON)
				for z in [-0.48,0.48]: cylinder(root,center+Vector3(x*1.5,0.27,z),0.22,0.12,IRON,Vector3(0,0,PI/2))
			box(recoil,center+Vector3(0,0.58,-0.1),Vector3(0.14,0.16,length-0.12),WOOD)
			var front := float(rect.position.y)-0.12
			for sign_x in [-1,1]:
				box(recoil,Vector3(c.x+sign_x*0.25,0.63,front+0.17),Vector3(0.5,0.09,0.11),IRON,Vector3(0,sign_x*0.4,0))
			box(recoil,center+Vector3(0,0.7,-0.23),Vector3(0.035,0.035,length-0.1),LIGHT)
			marker(root,recoil,Vector3(c.x,0.7,front-0.28))
			cylinder(root,center+Vector3(0,0.6,0.55),0.13,0.5,IRON,Vector3(0,0,PI/2))
			for cell in body:
				if cell.x == TowerBodyGeometry.weapon_lane(body): continue
				box(root,Vector3(cell.x,0.19,cell.y),Vector3(0.6,0.32,0.65),WOOD)
				for x in [-0.2,0,0.2]: box(root,Vector3(cell.x+x,0.4,cell.y),Vector3(0.045,0.045,0.7),LIGHT)
			box(lv2,center+Vector3(0,0.46,0.4),Vector3(0.65,0.12,0.25),accent)
			for sign_x in [-1,1]: box(lv2,center+Vector3(sign_x*0.31,0.63,0.4),Vector3(0.09,0.48,0.43),accent,Vector3(0,0,-sign_x*0.18))
			for sign_x in [-1,1]: box(lv3,Vector3(c.x+sign_x*0.24,0.79,front+0.15),Vector3(0.48,0.09,0.13),accent,Vector3(0,sign_x*0.4,0))
		"broadside":
			var hull := SphereMesh.new(); hull.radius = 0.48; hull.height = 0.96; hull.radial_segments = 8; hull.rings = 3
			part(moving,hull,WOOD,center+Vector3(0,0.56,0),Vector3.ZERO,Vector3(rect.size.x,0.65,rect.size.y))
			box(moving,center+Vector3(0,0.71,0),Vector3(rect.size.x*0.86,0.12,rect.size.y*0.9),DECK)
			for side in [-1,1]:
				var bank := group(recoil,"Port" if side < 0 else "Starboard"); bank.set_meta("side",side)
				for z in [-0.55,0,0.55]:
					var at := center+Vector3(side*rect.size.x*0.38,0.84,z*rect.size.y/2.0)
					cylinder(bank,at,0.085,0.38,IRON,Vector3(0,0,PI/2))
					marker(root,bank,at+Vector3(side*0.2,0,0))
				box(lv2,center+Vector3(side*0.39,0.9,0),Vector3(0.06,0.13,rect.size.y*0.86),accent)
			box(moving,center+Vector3(0,0.88,0.28),Vector3(0.4,0.26,0.42),WOOD)
			cylinder(moving,center+Vector3(0,1.17,0.3),0.08,0.4,IRON)
			cylinder(lv3,center+Vector3(0,1.15,-0.25),0.035,0.9,IRON)
			box(lv3,center+Vector3(0,1.48,-0.25),Vector3(0.64,0.37,0.035),accent)
		"mortar":
			cylinder(root,center+Vector3(0,0.31,0),0.73,0.2,IRON)
			for side in [-1,1]: box(root,center+Vector3(side*0.43,0.5,0),Vector3(0.14,0.48,0.42),accent)
			cylinder(recoil,center+Vector3(0,0.69,0),0.3,0.88,IRON,Vector3(-0.48,0,0))
			cylinder(recoil,center+Vector3(0,1.04,-0.18),0.33,0.13,DECK,Vector3(-0.48,0,0))
			cylinder(recoil,center+Vector3(0,1.105,-0.215),0.235,0.015,Color("1d303b"),Vector3(-0.48,0,0))
			marker(root,recoil,center+Vector3(0,1.12,-0.23))
			for x in [-0.65,0.65]:
				box(root,center+Vector3(x,0.32,0.65),Vector3(0.36,0.2,0.32),WOOD)
				for z in [0.55,0.73]: cylinder(root,center+Vector3(x,0.49,z),0.065,0.2,LIGHT,Vector3.ZERO,0.025)
			for x in [-0.7,0.7]: box(lv2,center+Vector3(x,0.49,-0.45),Vector3(0.12,0.5,0.65),accent,Vector3(0,0,-signf(x)*0.2))
			for z in [-0.65,0.65]: box(lv3,center+Vector3(0,0.32,z),Vector3(1.65,0.12,0.12),IRON)
			cylinder(lv3,center+Vector3(0,0.69,0),0.33,0.15,accent,Vector3(-0.48,0,0))
		"crossfire":
			cylinder(root,center+Vector3(0,0.32,0),0.74,0.22,IRON)
			cylinder(recoil,center+Vector3(0,0.58,0),0.4,0.42,accent,Vector3.ZERO,0.28)
			cylinder(recoil,center+Vector3(0,0.83,0),0.22,0.16,LIGHT,Vector3.ZERO,0.06)
			for x in [-0.62,0.62]:
				for z in [-0.62,0.62]: cylinder(lv2,center+Vector3(x,0.48,z),0.14,0.48,accent,Vector3.ZERO,0.1)
			cylinder(lv3,center+Vector3(0,1.05,0),0.17,0.55,LIGHT,Vector3.ZERO,0.02)
			for i in 4:
				var direction := Vector3(sin(i*PI/2),0,cos(i*PI/2))
				var arm := group(recoil,"Arm%d" % i,center); arm.rotation.y = i*PI/2
				box(arm,Vector3(0,0.51,0.55),Vector3(0.28,0.22,0.65),IRON)
				cylinder(arm,Vector3(0,0.55,0.81),0.12,0.24,DECK,Vector3(PI/2,0,0))
				marker(root,arm,Vector3(0,0.55,0.94))
				box(lv2,center+direction*0.65+Vector3.UP*0.69,Vector3(0.25,0.13,0.25),accent)
				cylinder(lv3,center+direction*0.65+Vector3.UP*0.83,0.11,0.22,LIGHT)
	# Reseat the existing machinery after removing the redundant 0.20 deck.
	# Only the art children move; anchor, attack origin and occupied cells do not.
	# These two assemblies' lowest structural surface was at 0.21.
	if key in ["mortar","crossfire"]:
		for child in root.get_children():
			if child is Node3D: child.position.y -= 0.20
	set_level(root,1)
	return root
