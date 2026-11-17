extends Node3D
## Art Slice G visual review. Places all six towers on Frontier and saves screenshots to
## .godot/test-results/art_slice_g/ : field.png, zoom.png, <tower>.png, <tower>_fire.png
## Run: godot --path . res://tools/assets/review/art_slice_g_review.tscn
const IDS=["sentry","ballista","mortar","crossfire","broadside","barracks"]
const OUT:="res://.godot/test-results/art_slice_g/"
var level:Node3D
var camera:Camera3D
func _ready() -> void:run.call_deferred()
func shot(name:String) -> void:
	for i in 3:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func aim(focus:Vector3,size:float) -> void:
	camera.size=size
	var a:float=camera.azimuth;var e:float=camera.elevation
	camera.look_at_from_position(focus+Vector3(sin(a)*cos(e),sin(e),cos(a)*cos(e))*camera.distance,focus,Vector3.UP)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(5026)
	level=load("res://scenes/level.tscn").instantiate();add_child(level)
	for i in 240:
		await get_tree().process_frame
		if not level.get_node("PortalMap").computing:break
	camera=level.get_node("Camera3D")
	var manager:Node3D=level.get_node("TowerMap")
	var placed:Array[DefenseTower]=[]
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
		placed.append(tower)
	for i in 90:await get_tree().process_frame
	var hud:=level.get_node_or_null("LevelHUD")
	await shot("field")
	if hud!=null:hud.hide()
	var all_focus:=Vector3.ZERO
	for t in placed:all_focus+=t.global_position
	aim(all_focus/placed.size()+Vector3(0,.4,0),9.5)
	await shot("zoom")
	for i in placed.size():
		var t:=placed[i]
		var visual:=t.get_node_or_null("Visual")
		var focus:=t.global_position
		if visual!=null:
			var box:=AABB();var first:=true
			for mesh:MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
				var b:=mesh.global_transform*mesh.get_aabb()
				box=b if first else box.merge(b);first=false
			focus=box.get_center()
		aim(focus,3.4)
		await shot(IDS[i])
		if visual!=null and visual.has_method("fire_event"):
			visual.prepare_target(t)
			if IDS[i]=="barracks":visual.deploy()
			else:visual.fire_event(t,null,2.0)
			var wait:int={"ballista":10,"barracks":20,"mortar":4,"sentry":3,"crossfire":3,"broadside":4}[IDS[i]]
			for f in wait:await get_tree().process_frame
			await shot(IDS[i]+"_fire")
	print("ART_SLICE_G_REVIEW_DONE")
	get_tree().quit()
