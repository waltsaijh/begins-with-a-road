extends SceneTree
## Offline GLB-derived rigid batching; preserves animation targets and function nodes.
const BASE="res://assets/models/towers/"
const IDS={"ballista":"great_ballista","sentry":"watchtower","barracks":"barracks","mortar":"mortar","crossfire":"crossfire","broadside":"broadside_airship"}
const MATERIAL=preload("res://assets/materials/solid_color.tres")
const Baker=preload("res://tools/assets/solid_mesh_baker.gd")
const Palette=preload("res://assets/data/rendering/tower_color_identity.tres")
var identity:=false
var output_directory:="integrated"
var protected: Array[Node]=[]
var mesh_index:=0
var asset: String
func _initialize() -> void:call_deferred("build")
func color_buffers_only(baseline:ArrayMesh,colored:ArrayMesh) -> ArrayMesh:
	# Keep original packed vertex/normal/index/custom buffers, avoiding another
	# normal quantization during the color experiment. This writes a new owned
	# ArrayMesh resource, never the imported GLB or the baseline resource.
	var surfaces:Array=baseline.get("_surfaces").duplicate(true)
	var colors:Array=colored.get("_surfaces")
	assert(surfaces.size()==colors.size())
	for index in surfaces.size():
		var a:Dictionary=surfaces[index];var b:Dictionary=colors[index]
		assert(a.format==b.format and a.vertex_count==b.vertex_count and a.index_data==b.index_data)
		var offset:=RenderingServer.mesh_surface_get_format_offset(a.format,a.vertex_count,Mesh.ARRAY_COLOR)
		var stride:=RenderingServer.mesh_surface_get_format_attribute_stride(a.format,a.vertex_count)
		var attributes:PackedByteArray=a.attribute_data.duplicate()
		var source:PackedByteArray=b.attribute_data
		for vertex in a.vertex_count:
			for channel in 4:attributes[offset+vertex*stride+channel]=source[offset+vertex*stride+channel]
		a.attribute_data=attributes
	var result:=ArrayMesh.new();result.set("_surfaces",surfaces)
	return result
func merge(parent: Node3D, root_model: Node) -> void:
	var parts: Array[MeshInstance3D]=[]
	for child in parent.get_children():
		if child is MeshInstance3D and not child in protected:parts.append(child)
		elif child is Node3D:merge(child,root_model)
	if parts.size()<2:return
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT);tool.set_custom_format(1,SurfaceTool.CUSTOM_RG_FLOAT)
	tool.set_material(MATERIAL)
	for part in parts:
		for surface in part.mesh.get_surface_count():tool.append_from(part.mesh,surface,part.transform)
		part.free()
	var result:=tool.commit()
	var mesh:=MeshInstance3D.new();mesh.name="StaticAssembly";mesh.mesh=result;parent.add_child(mesh);mesh.owner=root_model
func build() -> void:
	var palette:Resource=Palette
	identity="--identity" in OS.get_cmdline_user_args()
	if identity:output_directory="color_identity/b"
	DirAccess.make_dir_recursive_absolute(BASE+output_directory)
	var report:={}
	for kind in IDS:
		asset=kind;mesh_index=0;protected.clear()
		var model:Node3D=load(BASE+"art_slice_d/"+IDS[kind]+".glb").instantiate()
		root.add_child(model)
		for n in model.find_children("*","",true,false):
			if n is MeshInstance3D:
				for surface in n.mesh.get_surface_count():assert(Baker.supports(n.mesh.surface_get_material(surface)))
				n.mesh=Baker.mesh(n.mesh)
				assert(n.mesh!=null,"Unsupported rigid GLB mesh")
				if identity:
					var part:=String(n.name).get_slice("__",1)
					n.mesh=palette.colored_copy(n.mesh,kind,part)
			elif n is Node3D and ("Muzzle" in String(n.name) or "ArrowRelease" in String(n.name)):
				assert(n.get_child_count()==0)
				var marker:=Marker3D.new();marker.name=n.name;marker.transform=n.transform
				var parent:Node=n.get_parent();parent.remove_child(n);parent.add_child(marker);marker.owner=model;n.free()
		for player:AnimationPlayer in model.find_children("*","AnimationPlayer",true,false):
			var animation_root:=player.get_node(player.root_node)
			for clip in player.get_animation_list():
				var animation:=player.get_animation(clip)
				for track in animation.get_track_count():
					var node:=animation_root.get_node_or_null(NodePath(animation.track_get_path(track).get_concatenated_names()))
					if node!=null and not node in protected:protected.append(node)
		merge(model,model)
		for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var filename:String=kind+"_part_%02d.res"%mesh_index
			var path:String=BASE+output_directory+"/"+filename
			if identity:mesh.mesh=color_buffers_only(load(BASE+"integrated/"+filename),mesh.mesh)
			assert(ResourceSaver.save(mesh.mesh,path)==OK);mesh.mesh=load(path);mesh_index+=1
			if identity:
				palette.baseline_meshes[filename]=load(BASE+"integrated/"+filename)
				palette.colored_meshes[filename]=mesh.mesh
		for node in model.find_children("*","",true,false):node.owner=model;node.scene_file_path=""
		model.scene_file_path=""
		var packed:=PackedScene.new();assert(packed.pack(model)==OK)
		if not identity:assert(ResourceSaver.save(packed,BASE+"integrated/"+kind+"_art.tscn")==OK)
		report[kind]={"mesh_instances":model.find_children("*","MeshInstance3D",true,false).size(),"protected_targets":protected.size()}
		model.free()
		if identity:continue
		var text:='[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://scripts/towers/imported_tower_visual.gd" id="1"]\n[ext_resource type="PackedScene" path="res://assets/models/towers/integrated/%s_art.tscn" id="2"]\n\n[node name="TowerVisual" type="Node3D"]\nscript = ExtResource("1")\ntower_kind = "%s"\n\n[node name="Art" parent="." instance=ExtResource("2")]\n' % [kind,kind]
		FileAccess.open(BASE+"integrated/"+kind+".tscn",FileAccess.WRITE).store_string(text)
	if identity:assert(ResourceSaver.save(palette,"res://assets/data/rendering/tower_color_identity.tres")==OK)
	print("IDENTITY_ART_BUILT " if identity else "INTEGRATED_ART_BUILT ",JSON.stringify(report));quit()
