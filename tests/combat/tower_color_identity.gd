extends Node3D
## A/B visual review only. F6: A/B changes color, 1/2/3 switches review views.
const Artifacts=preload("res://tests/fixtures/test_artifacts.gd")
const IDS=["sentry","ballista","mortar","crossfire","broadside","barracks"]
var palette:Resource=preload("res://assets/data/rendering/tower_color_identity.tres")
var level:Node3D
var camera:Camera3D
var holder:Node3D
var original_camera:Transform3D
var original_size:float
var dense_focus:Vector3
var current_view:="field"
var report:={}
var failures:Array[String]=[]
class DisplayLayout extends Node:
	signal graph_changed
	var computing:=false
	var blocked_cells:={}
	func terminal_cells() -> Array[Vector2i]:return []
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)
func _ready() -> void:run.call_deferred()
func run() -> void:
	seed(5026)
	validate_meshes()
	level=load("res://scenes/level.tscn").instantiate();add_child(level)
	for i in 240:
		await get_tree().process_frame
		if not level.get_node("PortalMap").computing:break
	camera=level.get_node("Camera3D")
	var manager:Node3D=level.get_node("TowerMap")
	var placed:Array[DefenseTower]=[]
	var positions_report:={}
	for i in IDS.size():
		var definition:TowerDefinition=load("res://assets/data/towers/"+IDS[i]+".tres")
		var preferred:=Vector2i(2+i*4,1)
		var positions:Array[Vector2i]=[]
		for z in range(-5,5):
			for x in range(24):positions.append(Vector2i(x,z))
		positions.sort_custom(func(a,b):return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
		var tower:DefenseTower
		for candidate in definition.preset_candidates():
			var card:=BuildCard.from_parts(definition,candidate.resolve_preset())
			for point in positions:
				if placed.any(func(other):return Vector2(point-other.grid_cell).length()<(1.2 if IDS[i]=="barracks" else 2.2)):continue
				var at:=Vector3i(point.x,0,point.y)
				if manager.validate_card(card,at,0).is_empty():tower=manager.place_card(card,at,0);break
			if tower!=null:break
		check(tower!=null,"Cannot place "+IDS[i]+" on Frontier")
		if tower==null:get_tree().quit(1);return
		placed.append(tower);positions_report[IDS[i]]=str(tower.grid_cell)
	# Settle the existing tile rise and hand animations before freezing the review.
	for i in 90:await get_tree().process_frame
	original_camera=camera.global_transform;original_size=camera.size
	make_dense()
	for node in [level]+level.find_children("*","",true,false):node.process_mode=Node.PROCESS_MODE_DISABLED
	holder.hide()
	Engine.time_scale=0.0
	report["placements"]=positions_report
	report["renderer"]=RenderingServer.get_current_rendering_method()
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()!="headless":
			for view in ["field","dense","far"]:
				select_view(view)
				await capture_pair(view)
		report["failures"]=failures
		FileAccess.open(Artifacts.path("modeling/art_slice_f/check.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("TOWER_COLOR_IDENTITY:",JSON.stringify(report))
		get_tree().quit(0 if failures.is_empty() else 1)
	else:
		select_view("field");set_variant("B")
		print("Tower Color Identity: A/B = palette; 1 = Frontier, 2 = 192 towers, 3 = farthest zoom")
func make_dense() -> void:
	holder=Node3D.new();holder.name="DenseReview";holder.position=Vector3(-50,0,-40);add_child(holder)
	var map:=GridMap.new();map.name="TileMap";map.mesh_library=load("res://assets/models/mesh_library.tres");map.cell_size=Vector3.ONE;map.cell_center_y=false;holder.add_child(map)
	var layout:=DisplayLayout.new();layout.name="PortalMap";holder.add_child(layout)
	# Repeat the same 192 display assets in 2x2 blocks, with their real footprint
	# cells filled as stone pads and the remaining cells as the maze's roads.
	for z in 24:
		for x in 32:map.set_cell_item(Vector3i(x,0,z),6)
	for i in 192:
		var definition:TowerDefinition=load("res://assets/data/towers/"+IDS[i%6]+".tres")
		var body:=TowerBodyGeometry.local_cells(definition.first_tile_preset())
		if body.is_empty():body=definition.footprint
		var bounds:=TowerBodyGeometry.bounds(body)
		var anchor:=Vector2i((i%16)*2,(i/16)*2)-bounds.position
		for cell in body:map.set_cell_item(Vector3i(anchor.x+cell.x,0,anchor.y+cell.y),0)
		var visual:Node3D=preload("res://scripts/towers/body_visual.gd").create(definition,body)
		holder.add_child(visual);visual.position=map.map_to_local(Vector3i(anchor.x,0,anchor.y))+Vector3.UP*TowerConstants.GROUND_OFFSET;visual.process_mode=Node.PROCESS_MODE_DISABLED
	var display:Node3D=preload("res://scripts/map/tile/appearance/tile_visuals.gd").new();display.name="TileVisuals";display.animate=false;holder.add_child(display)
	dense_focus=holder.to_global(Vector3(16,0,12))
func set_variant(selected:String) -> void:
	palette.variant=selected;palette.apply_to(level,selected);palette.apply_to(holder,selected)
func select_view(view:String) -> void:
	current_view=view
	for path in ["TowerMap","Start","Goal","LevelHUD/WorldActions"]:
		var node:=level.get_node_or_null(NodePath(path))
		if node!=null:node.visible=view!="dense"
	if view=="dense":
		holder.show();level.get_node("TileVisuals").hide()
		camera.size=30.833333
		var a:float=camera.azimuth;var e:float=camera.elevation
		camera.look_at_from_position(dense_focus+Vector3(sin(a)*cos(e),sin(e),cos(a)*cos(e))*camera.distance,dense_focus,Vector3.UP)
	else:
		holder.hide();level.get_node("TileVisuals").show();camera.global_transform=original_camera
		camera.size=original_size if view=="field" else minf(camera.maximum_size,original_size/camera.minimum_zoom_scale)
func capture_pair(view:String) -> void:
	var snapshots:Array[Image]=[]
	var transform_before:=camera.global_transform
	var size_before:=camera.size
	for selected in ["A","B"]:
		set_variant(selected)
		for i in 3:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		check(image.save_png(Artifacts.path("modeling/art_slice_f/"+view+"_"+selected.to_lower()+".png"))==OK,"Screenshot write failed")
		snapshots.append(image)
	check(camera.global_transform==transform_before and camera.size==size_before,"A/B camera drift")
	# Check that background/UI pixels outside tower bounds are identical too.
	var mask:=Image.create(snapshots[0].get_width(),snapshots[0].get_height(),false,Image.FORMAT_L8)
	var projection_scale:=Vector2(mask.get_size())/get_viewport().get_visible_rect().size
	for node:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree() or node.mesh==null:continue
		if not node.mesh.resource_path.get_file() in palette.baseline_meshes:continue
		var lo:=Vector2.INF;var hi:=-Vector2.INF
		for i in 8:
			var p:=camera.unproject_position(node.to_global(node.get_aabb().get_endpoint(i)))*projection_scale
			lo=lo.min(p);hi=hi.max(p)
		var rect:=Rect2i(Vector2i(lo.floor())-Vector2i(3,3),Vector2i((hi-lo).ceil())+Vector2i(7,7))
		rect=rect.intersection(Rect2i(Vector2i.ZERO,mask.get_size()))
		if rect.has_area():mask.fill_rect(rect,Color.WHITE)
	var ma:PackedByteArray=mask.get_data();var a:PackedByteArray=snapshots[0].get_data();var b:PackedByteArray=snapshots[1].get_data()
	var channels:=4 if snapshots[0].get_format()==Image.FORMAT_RGBA8 else 3
	var outside_differences:=0;var changed_pixels:=0
	var difference_image:=Image.create(mask.get_width(),mask.get_height(),false,Image.FORMAT_RGB8)
	for pixel in ma.size():
		var changed:=false
		for channel in channels:
			if a[pixel*channels+channel]!=b[pixel*channels+channel]:changed=true;break
		if changed:
			changed_pixels+=1
			if ma[pixel]==0:outside_differences+=1
			difference_image.set_pixel(pixel%mask.get_width(),pixel/mask.get_width(),Color.RED if ma[pixel]==0 else Color.WHITE)
	mask.save_png(Artifacts.path("modeling/art_slice_f/"+view+"_mask.png"))
	difference_image.save_png(Artifacts.path("modeling/art_slice_f/"+view+"_diff.png"))
	check(outside_differences==0,view+" background/UI drift "+str(outside_differences))
	check(changed_pixels>0,view+" B color not visible")
	var pair:=Image.create(snapshots[0].get_width()*2,snapshots[0].get_height(),false,snapshots[0].get_format())
	pair.blit_rect(snapshots[0],Rect2i(Vector2i.ZERO,snapshots[0].get_size()),Vector2i.ZERO)
	pair.blit_rect(snapshots[1],Rect2i(Vector2i.ZERO,snapshots[1].get_size()),Vector2i(snapshots[0].get_width(),0))
	check(pair.save_png(Artifacts.path("modeling/art_slice_f/"+view+"_comparison.png"))==OK,"Comparison write failed")
	report[view]={"camera_size":camera.size,"elevation":camera.elevation,"azimuth":camera.azimuth,"camera_identical":true,"same_scene_nodes":true,"towers":192 if view=="dense" else 6,"changed_pixels":changed_pixels,"outside_tower_differences":outside_differences}
func validate_meshes() -> void:
	var areas:={}
	var maximum_normal_error:=0.0
	for filename in palette.baseline_meshes:
		var a:Mesh=palette.baseline_meshes[filename];var b:Mesh=palette.colored_meshes[filename]
		check(a.get_surface_count()==b.get_surface_count(),filename+" surface count")
		var kind:String=filename.get_slice("_part_",0)
		if not areas.has(kind):areas[kind]={"all":0.0,"identity":0.0,"dark_changed":0,"surfaces":0}
		for s in a.get_surface_count():
			var aa:=a.surface_get_arrays(s);var bb:=b.surface_get_arrays(s)
			for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1]:check(aa[slot]==bb[slot],filename+" non-color data changed "+str(slot))
			var normals_a:PackedVector3Array=aa[Mesh.ARRAY_NORMAL];var normals_b:PackedVector3Array=bb[Mesh.ARRAY_NORMAL]
			for i in normals_a.size():maximum_normal_error=maxf(maximum_normal_error,normals_a[i].distance_to(normals_b[i]))
			check(a.surface_get_material(s)==b.surface_get_material(s),filename+" material changed")
			var ca:PackedColorArray=aa[Mesh.ARRAY_COLOR];var cb:PackedColorArray=bb[Mesh.ARRAY_COLOR]
			for i in ca.size():
				if maxf(ca[i].r,maxf(ca[i].g,ca[i].b))<.5 and ca[i]!=cb[i]:areas[kind].dark_changed+=1
			var points:PackedVector3Array=aa[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=aa[Mesh.ARRAY_INDEX]
			for t in range(0,indices.size(),3):
				var i:int=indices[t];var j:int=indices[t+1];var k:int=indices[t+2]
				var area:float=(points[j]-points[i]).cross(points[k]-points[i]).length()*.5
				areas[kind].all+=area
				if ca[i]!=cb[i] or ca[j]!=cb[j] or ca[k]!=cb[k]:areas[kind].identity+=area
			areas[kind].surfaces+=1
	for kind in areas:
		areas[kind]["identity_fraction"]=areas[kind].identity/areas[kind].all
		check(areas[kind].identity>0,kind+" has no identification color")
		check(areas[kind].identity_fraction<.5,kind+" identity color dominates surface area")
		check(areas[kind].dark_changed==0,kind+" dark mechanical color changed")
	check(maximum_normal_error==0.0,"Normals changed")
	report["surface_areas"]=areas;report["maximum_normal_error"]=maximum_normal_error
func _unhandled_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_A:set_variant("A")
		KEY_B:set_variant("B")
		KEY_1:select_view("field")
		KEY_2:select_view("dense")
		KEY_3:select_view("far")
