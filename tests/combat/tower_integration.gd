extends Node3D
const Fixture=preload("res://tests/fixtures/portal_fixture.gd")
const Artifacts=preload("res://tests/fixtures/test_artifacts.gd")
const Enemy=preload("res://scripts/enemies/enemy.gd")
const Body=preload("res://scripts/towers/body_visual.gd")
const IDS=["sentry","ballista","barracks","mortar","crossfire","broadside"]
var failures: Array[String]=[]
var placements:=0
var report:={}
var stage:Node3D
var map:GridMap
var towers:Node3D
var wave:Node
var combat:Node
var enemies:Array[Node3D]=[]
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)
func _ready() -> void:
	var palette:Resource=load("res://assets/data/rendering/tower_color_identity.tres")
	if "--palette-a" in OS.get_cmdline_user_args():palette.variant="A"
	report["palette"]=palette.variant
	run.call_deferred()
func meshes(node:Node) -> Dictionary:
	var result:={}
	for n:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		result[String(node.get_path_to(n))]={"transform":n.global_transform,"mesh":n.mesh,"visible":n.visible}
	return result
func difference(a:Transform3D,b:Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func compare(a:Dictionary,b:Dictionary,label:String) -> void:
	check(a.size()==b.size(),label+" mesh count")
	for path in a:
		check(b.has(path),label+" missing "+path)
		if b.has(path):check(difference(a[path].transform,b[path].transform)<.0001 and a[path].mesh==b[path].mesh and a[path].visible==b[path].visible,label+" transform/mesh "+path)
func clear_enemies() -> void:
	for e in enemies:wave._living.erase(e);e.free()
	enemies.clear();wave.alive=0
func enemy(at:Vector3) -> Node3D:
	var e:=Enemy.new();e.troop=load("res://assets/data/troops/soldier.tres");stage.add_child(e)
	e.enemy_id=enemies.size();e.global_position=at;e.health=10000;e.max_health=10000;e.set_process(false)
	wave._living[e]=true;enemies.append(e);wave.alive=enemies.size();return e
func run() -> void:
	var cells:Array[Vector2i]=[]
	for z in 15:
		for x in 15:cells.append(Vector2i(x,z))
	stage=Fixture.scene_for(cells,Vector2i(0,0),Vector2i(14,14));stage.get_node("EnemyWave").auto_start=false;add_child(stage)
	for i in 120:
		await get_tree().process_frame
		if not stage.get_node("PortalMap").computing:break
	map=stage.get_node("TileMap");towers=stage.get_node("TowerMap");wave=stage.get_node("EnemyWave");combat=towers.combat
	wave.set_process(false);combat.set_process(false);combat.barracks.set_process(false)
	var preview:Node3D=preload("res://scenes/cards/components/card_preview.tscn").instantiate();stage.add_child(preview)
	for id in IDS:
		var definition:TowerDefinition=load("res://assets/data/towers/"+id+".tres")
		var count:=0
		for candidate in definition.preset_candidates():
			var preset:TilePreset=candidate.resolve_preset()
			for turns in 4:
				var card:=BuildCard.from_parts(definition,preset)
				var at:=Vector3i(7,0,7)
				var error:String=towers.validate_card(card,at,turns)
				check(error.is_empty(),id+" placement "+error)
				if not error.is_empty():continue
				preview.show_at(map,card,at,turns,true)
				var tower:DefenseTower=towers.place_card(card,at,turns)
				check(tower!=null,id+" actual place failed")
				if tower==null:continue
				var visual:Node3D=tower._visual
				check(visual.has_method("fire_event"),id+" fell back unexpectedly")
				compare(meshes(visual),meshes(preview.ghost),id+" preview rotation "+str(turns))
				for n:MeshInstance3D in preview.ghost.find_children("*","MeshInstance3D",true,false):check(n.material_override==null,id+" palette overwritten")
				var before:=meshes(preview.ghost)
				preview.show_at(map,card,at,turns,false)
				compare(before,meshes(preview.ghost),id+" invalid preview")
				# All at-rest vertices remain inside the real logical occupied union.
				var body:=TowerBodyGeometry.local_cells(preset)
				if body.is_empty():body=definition.footprint
				var outside:=0
				for n:MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
					for surface in n.mesh.get_surface_count():
						var vertices:PackedVector3Array=n.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
						for v in vertices:
							var q:Vector3=tower.to_local(n.to_global(v))
							var inside:=false
							for cell in body:
								if absf(q.x-cell.x)<=.5001 and absf(q.z-cell.y)<=.5001:inside=true;break
							if not inside:outside+=1
				check(outside==0,id+" outside footprint "+str(outside))
				check(tower.combat_origin().distance_to(tower.to_global(Vector3(TowerBodyGeometry.origin(definition,body).x,0,TowerBodyGeometry.origin(definition,body).y)))<.0001,id+" combat center changed")
				count+=1;placements+=1
				towers.remove_tower(Vector3i(tower.grid_cell.x,0,tower.grid_cell.y))
				await get_tree().process_frame
		report[id]={"preset_rotations":count}
	preview.hide()
	await events()
	var fallback:Node3D=Body.create(load("res://assets/data/towers/mortar.tres"),[Vector2i.ZERO,Vector2i.RIGHT])
	check(not fallback.has_method("fire_event"),"unsupported footprint has no legacy fallback");fallback.free()
	report["placements"]=placements;report["failures"]=failures;report["platform"]=OS.get_name()
	FileAccess.open(Artifacts.path("combat/tower_integration.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TOWER_INTEGRATION:"+JSON.stringify(report))
	stage.queue_free()
	await get_tree().process_frame
	stage=null;map=null;towers=null;wave=null;combat=null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
func events() -> void:
	for id in IDS:
		var definition:TowerDefinition=load("res://assets/data/towers/"+id+".tres")
		var card:=BuildCard.from_parts(definition,definition.first_tile_preset())
		var tower:DefenseTower=towers.place_card(card,Vector3i(7,0,7))
		check(tower!=null,id+" event placement");if tower==null:continue
		var visual:Node3D=tower._visual;visual.set_process(false)
		if id=="sentry":
			check(visual.shot_sound != null and visual.shot_sound.resource_path == "res://assets/audio/towers/sentry_shot.wav", "Sentry must retain its authored bow release sound after configuration")
		# This regression checks visuals and combat, not Dummy audio-driver playback.
		if DisplayServer.get_name()=="headless":visual.shot_sound=null
		if id=="barracks":
			combat.barracks._process(0)
			check(visual.deployment_count==2 and visual.last_clips==["open_close"],"initial deployment did not open doors")
			visual._process(10)
			var unit:Node3D=combat.barracks.units.back();unit.take_damage(100000);unit.advance(unit.settings.respawn_seconds)
			check(not unit.dead and visual.deployment_count==3,"respawn did not open doors")
		else:
			var offset:Vector2i=tower.attack_offsets().filter(func(c):return c!=Vector2i.ZERO)[0]
			var target:=enemy(map.to_global(map.map_to_local(Vector3i(tower.grid_cell.x+offset.x,0,tower.grid_cell.y+offset.y))))
			# Smooth aim is still authoritative; align by advancing its existing limit.
			tower.aim_at(combat.aim_position(target,tower.attack),10)
			if id=="sentry":
				var limits:Vector2=visual.aim_pitch_limits()
				check(visual.aim_pivot().rotation.x>=limits.x-.001 and visual.aim_pivot().rotation.x<=limits.y+.001,"sentry pitch left its limits")
			if id=="mortar":
				var flat:Vector3=tower.to_local(target.global_position)-visual._center;flat.y=0
				var facing:Vector3=visual.to_local(visual._rotor.to_global(Vector3.FORWARD))-visual._rotor.position
				check(facing.normalized().dot(flat.normalized())>.99,"mortar disc does not face its target")
				check(visual._aim.rotation.x>0,"mortar barrel ignores the shell arc")
				var stops:MeshInstance3D=visual.get_node("BedStops")
				check(stops.get_parent()==visual and stops.mesh.get_aabb().size.x>1.5,"mortar bed stops must stay off the rotor")
			var interval:=tower.attack_interval
			var damage:=tower.damage
			var shots:int=combat.shots_fired
			combat.friendly_index_ready=false
			combat._process(.01)
			var fired:int=combat.shots_fired-shots
			check(fired>=1 and visual.shot_count==fired and (fired==1 or id=="broadside"),id+" attack event not delivered")
			if id=="broadside":
				check(tower.attack_interval==interval and tower.damage==damage and tower.next_attack_time==0.0,"broadside balance/cooldown changed")
				# The opposite guns keep their own timers while this side reloads.
				var opposite:=enemy(tower.combat_origin()*2.0-target.global_position)
				var after:int=combat.shots_fired
				combat.friendly_index_ready=false;combat._process(.01)
				check(combat.shots_fired>after,"guns share one attack timer")
				var waiting:int=combat.shots_fired
				combat.friendly_index_ready=false;combat._process(.01)
				check(combat.shots_fired==waiting,"a gun ignored its own interval")
				wave._living.erase(opposite);enemies.erase(opposite);opposite.free();wave.alive=enemies.size()
				visual._process(10)
				check(visual._gun_kick.all(func(kick):return is_zero_approx(kick)),"gun recoil did not settle")
			else:
				check(not visual.last_clips.is_empty(),id+" missing animation")
				report[id]["event_clips"]=visual.last_clips.duplicate()
				check(tower.attack_interval==interval and tower.damage==damage and is_equal_approx(tower.next_attack_time,combat.elapsed+interval),id+" balance/cooldown changed")
			if id=="ballista":
				check(not visual._bolt.visible,"the clip's flying bolt is still visible")
				check(combat.projectiles.size()==1 and target.health==target.max_health,"bolt must fly before it hits")
				combat.friendly_index_ready=false;combat._process(1.0)
				check(combat.projectiles.is_empty() and target.health<target.max_health,"bolt must end on its target")
			if id=="crossfire":
				check(visual.last_clips.size()==4,"shockwave must drive all four launchers")
				var bursts:Array=combat.visuals.restored_bursts.bursts
				check(bursts.any(func(burst):return burst.get("kind")=="mortar_impact"),"shockwave ring missing")
				var rest:Basis=visual._rotor.basis
				visual._process(.1);check(visual._rotor.basis.is_equal_approx(rest),"crossfire must rest between waves")
				combat.set_wave_motion(true)
				for step in 40:visual._process(.05)
				check(not visual._rotor.basis.is_equal_approx(rest) and visual.is_processing(),"crossfire must spin during a wave")
				var streams:Node=combat.visuals.streams
				streams._process(.016)
				var live:int=streams.multimesh.visible_instance_count
				check(live>0,"barrels must stream tracers")
				var hp_before:float=target.health
				streams._process(.016)
				check(target.health==hp_before,"tracers must stay cosmetic")
				combat.set_wave_motion(false)
				check(streams.multimesh.visible_instance_count==0,"tracers must stop with the wave")
				for step in 40:visual._process(.05)
				check(is_zero_approx(visual._spin_speed) and not visual.is_processing(),"crossfire must stop after a wave")
			if id=="sentry" and DisplayServer.get_name()!="headless":
				var effects:Node = combat.visuals
				var sounding := false
				for voice:AudioStreamPlayer in effects._shot_players:
					if voice.playing and voice.stream == visual.shot_sound and voice.bus == &"Combat": sounding = true
				check(sounding,"Sentry firing must play its bow release through the combat bus")
			visual._process(10);check(visual._active.is_empty(),id+" animation did not finish")
			if id=="broadside":directions(tower)
			# Repeated events at a faster instance interval cannot get stuck.
			for i in 12:
				tower.prepare_shot(target);tower.attack_interval=.16;tower.present_shot(target)
				visual._process(.16)
			visual._process(10);check(visual._active.is_empty(),id+" rapid fire stuck")
			tower.attack_interval=interval
			if id=="crossfire":
				visual._players.clear();tower.prepare_shot(target)
				var hp:float=target.health;tower.attack.fire(combat,tower,target);tower.present_shot(target)
				check(target.health==hp-damage,"missing animation affected damage")
			clear_enemies();combat.projectiles.clear()
		if id=="broadside":
			tower.relic_effects[&"departure"]={}
			var initial:=tower.combat_origin();var base:Node3D=visual.get_node("BWAR_D_broadside_airship__FixedBase");var base_at:=base.global_position
			tower.set_patrol_offset(.3)
			check(tower.combat_origin().distance_to(initial+tower.global_basis*Vector3(.3,0,0))<.0001 and base.global_position==base_at,"airship patrol origin/base changed")
		towers.remove_tower(Vector3i(tower.grid_cell.x,0,tower.grid_cell.y));await get_tree().process_frame
func directions(tower:DefenseTower) -> void:
	var v:Node3D=tower._visual
	var center:Vector3=tower.combat_origin()
	var names:Array=["fire_port","fire_starboard"]
	var vectors:=[Vector3.LEFT,Vector3.RIGHT]
	for i in names.size():
		var target:=enemy(center+tower.global_basis*vectors[i]*2)
		tower.prepare_shot(target)
		var muzzle:Vector3=tower.to_local(tower.muzzle_position())-v._center
		check(muzzle.dot(vectors[i])>.3,"wrong directional muzzle "+names[i])
		tower.present_shot(target)
		check(v.last_clips==[names[i]],"wrong direction clip "+names[i]+str(v.last_clips))
		v._process(10)
	# Two disjoint channels must remain active together; one must not reset the other.
	for i in 2:
		var target:=enemy(center+tower.global_basis*vectors[i]*2)
		tower.prepare_shot(target);tower.present_shot(target);v._process(.02)
	check(v._active.has(names[0]) and v._active.has(names[1]),"direction channels cannot overlap")
	v._process(10)
	report[v.tower_kind]["independent_clips"]=names
