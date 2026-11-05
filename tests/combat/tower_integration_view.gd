extends Node3D
## Formal Frontier presentation + actual card commits. F6 for a repeatable review.
const Artifacts=preload("res://tests/fixtures/test_artifacts.gd")
const IDS=["sentry","ballista","mortar","crossfire","broadside","barracks"]
var level:Node3D
var placed:Array[DefenseTower]=[]
var labels:Array[Label]=[]
func _ready() -> void:run.call_deferred()
func run() -> void:
	level=load("res://scenes/level.tscn").instantiate();add_child(level)
	for i in 240:
		await get_tree().process_frame
		if not level.get_node("PortalMap").computing:break
	var manager:Node3D=level.get_node("TowerMap")
	var map:GridMap=level.get_node("TileMap")
	var camera:Camera3D=level.get_node("Camera3D")
	var placements:={}
	for i in IDS.size():
		var definition:TowerDefinition=load("res://assets/data/towers/"+IDS[i]+".tres")
		var preferred:=Vector2i(2+i*4,1)
		var positions:Array[Vector2i]=[]
		for z in range(-5,5):
			for x in range(0,24):positions.append(Vector2i(x,z))
		positions.sort_custom(func(a,b):return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
		var tower:DefenseTower
		for candidate in definition.preset_candidates():
			var card:=BuildCard.from_parts(definition,candidate.resolve_preset())
			for point in positions:
				var far:=true
				for other in placed:
					if Vector2(point-other.grid_cell).length()<(1.2 if IDS[i]=="barracks" else 2.2):far=false
				if not far:continue
				var at:=Vector3i(point.x,0,point.y)
				if manager.validate_card(card,at,0).is_empty():tower=manager.place_card(card,at,0);break
			if tower!=null:break
		if tower==null:
			push_error("Cannot place "+IDS[i]+" on actual Frontier")
			get_tree().quit(1);return
		placed.append(tower);placements[IDS[i]]=str(tower.grid_cell)
	# Original level camera, environment and HUD are left as authored.
	for i in 20:await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(Artifacts.path("combat/tower_integration_frontier.png"))==OK)
	var output:={"placements":placements,"formal_level":"frontier","camera_size":camera.size,"camera_elevation":camera.elevation,"renderer":RenderingServer.get_current_rendering_method(),"failures":0,"screenshot":DisplayServer.get_name()!="headless"}
	FileAccess.open(Artifacts.path("combat/tower_integration_view.json"),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("TOWER_INTEGRATION_VIEW:",JSON.stringify(output))
	if not "--stress" in OS.get_cmdline_user_args():get_tree().quit();return
	await stress(camera)
func stress(camera:Camera3D) -> void:
	# Additional isolated display copies, never registered in navigation/combat.
	# This test-only view fits the complete stress grid; formal scene settings stay saved.
	var holder:=Node3D.new();add_child(holder)
	var visuals:Array[Node3D]=[]
	for i in 192:
		var definition:TowerDefinition=load("res://assets/data/towers/"+IDS[i%6]+".tres")
		var body:=TowerBodyGeometry.local_cells(definition.first_tile_preset())
		var visual:Node3D=preload("res://scripts/towers/body_visual.gd").create(definition,body)
		holder.add_child(visual);visual.position=Vector3((i%16)*2.5,0,(i/16)*2.5)+Vector3(100,0,100)
		visuals.append(visual)
	camera.set_process(false);camera.size=38
	camera.look_at_from_position(Vector3(118,35,143),Vector3(118,0,114),Vector3.UP)
	var target:=Node3D.new();holder.add_child(target)
	var start:=Time.get_ticks_usec()
	for frame in 180:
		if frame%30==0:
			for visual in visuals:
				target.global_position=visual.global_position+Vector3(2,0,-2)
				visual.prepare_target(target)
				if visual.tower_kind=="barracks":visual.deploy()
				else:visual.fire_event(target,null,.5)
		await get_tree().process_frame
	var seconds:float=(Time.get_ticks_usec()-start)/1000000.0
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	var output:={"display_towers":192,"mean_frame_ms":seconds/180*1000,"seconds":seconds,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"active_visuals":visuals.filter(func(v):return not v._active.is_empty()).size(),"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(Artifacts.path("combat/tower_integration_stress.json"),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(Artifacts.path("combat/tower_integration_stress.png"))
	print("TOWER_INTEGRATION_STRESS:",JSON.stringify(output));get_tree().quit()
