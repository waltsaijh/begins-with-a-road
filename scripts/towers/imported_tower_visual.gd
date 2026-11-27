extends Node3D
const COLOR_IDENTITY = preload("res://assets/data/rendering/tower_color_identity.tres")
## Presentation-only adapter for the GLB-derived Art Slice D assets.
## Manual animation advance follows simulation delta; idle towers do no per-frame work.
const SENTRY_PITCH := Vector2(-0.14,0.21)
const MORTAR_REST_ELEVATION := deg_to_rad(48.5)
const MORTAR_ELEVATION := Vector2(deg_to_rad(35.0),deg_to_rad(80.0))
const SPIN_SPEED := deg_to_rad(300.0)
const SPIN_ACCELERATION := deg_to_rad(720.0)
const GUN_KICK := 0.06
const GUN_RECOVERY := 5.0
const MESH_FLAGS := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
## Art-space distance from the mortar's center beyond which a block is a bed stop.
const MORTAR_DISC_REACH := 0.65
static var _mortar_stops := {}
@export_enum("ballista","sentry","barracks","mortar","crossfire","broadside") var tower_kind := "sentry"
@export var shot_sound: AudioStream
var shot_count := 0
var deployment_count := 0
var side := 1
var last_clips: Array[String] = []
var _center := Vector3.ZERO
var _motion: Node3D
var _art: Node3D
var _motion_rest := Vector3.ZERO
var _aim: Node3D
var _muzzles: Array[Node3D] = []
var _target := Vector3.ZERO
var _players := {}
var _active := {}
var _preview := false
var _bolt: Node3D
var _rotor: Node3D
var _spin_speed := 0.0
var _spin_target := 0.0
var _yaw := 0.0
var _barrels := PackedVector3Array()
var _mortar_elevation := MORTAR_REST_ELEVATION
var _guns: Array[Node3D] = []
var _gun_rest: Array[Vector3] = []
var _gun_kick: Array[float] = []
var _configured := false

func supports_body(body: Array[Vector2i]) -> bool:
	if tower_kind in ["sentry","barracks"]: return body.is_empty() or body.size()==1 and body[0]==Vector2i.ZERO
	if body.is_empty(): return false
	var rect := TowerBodyGeometry.bounds(body)
	if tower_kind=="broadside": return body.size()==2 and rect.size==Vector2i(1,2)
	if tower_kind in ["mortar","crossfire"]: return body.size()==4 and rect.size==Vector2i(2,2)
	if tower_kind=="ballista":
		var lane := TowerBodyGeometry.weapon_lane(body)
		var main := body.filter(func(c):return c.x==lane)
		return body.size()==3 and main.size()==2 and absi(main[0].y-main[1].y)==1 and rect.size==Vector2i(2,2)
	return false

func configure(definition: TowerDefinition, body: Array[Vector2i]) -> void:
	COLOR_IDENTITY.apply_to(self)
	_center = Vector3.ZERO
	var c := TowerBodyGeometry.origin(definition,body)
	_center=Vector3(c.x,0,c.y)
	var art: Node3D=$Art
	var source_center := {"ballista":Vector3(0,0,.5),"mortar":Vector3(-.5,0,.5),"crossfire":Vector3(.5,0,-.5),"broadside":Vector3(0,0,.5)}
	art.position=_center-source_center.get(tower_kind,Vector3.ZERO)
	# Visual contact correction only: TowerMap's logical root offset stays 0.025.
	art.position.y=-TowerConstants.GROUND_OFFSET
	if tower_kind=="ballista":
		var lane := TowerBodyGeometry.weapon_lane(body)
		for cell in body:
			if cell.x==lane: continue
			var bay := _part("LoadingBay")
			bay.position+=Vector3(cell.x,0,cell.y)-(_center+Vector3(1,0,.5))
	if definition.model!=null:
		var state:=definition.model.get_state()
		for index in state.get_node_property_count(0):
			if state.get_node_property_name(0,index)==&"shot_sound":shot_sound=state.get_node_property_value(0,index)
	_configured=true

func _part(function: String) -> Node3D:
	var art: Node3D=_art if _art!=null else get_node("Art")
	for node in art.find_children("*","Node3D",true,false):
		if String(node.name).ends_with("__"+function):return node
	return null

func _ready() -> void:
	_art=$Art
	_motion=self
	if tower_kind=="broadside":
		# Keep the navigation/patrol origin at the logical anchor, not the hull's pivot.
		var base:=_part("FixedBase")
		if base!=null:base.reparent(self,true)
		_motion=Node3D.new();_motion.name="MotionRoot";add_child(_motion)
		_art.reparent(_motion,true)
	_motion_rest=_motion.position
	_aim=_part("AimPivot") if tower_kind in ["sentry","mortar"] else null
	if tower_kind=="ballista":_bolt=_part("BoltCarrier")
	for node in _art.find_children("*","Node3D",true,false):
		if node is Marker3D and ("Muzzle" in String(node.name) or "ArrowRelease" in String(node.name)):_muzzles.append(node)
	if tower_kind=="mortar":
		_fix_mortar_stops()
		_mount_rotor("LoadBearingBed")
	if tower_kind=="crossfire":_mount_rotor("FixedBase")
	var sources: Array[Node]=_art.find_children("*","AnimationPlayer",true,false)
	if not sources.is_empty():
		var source:=sources[0] as AnimationPlayer
		var animation_root:=source.get_node(source.root_node)
		for clip in source.get_animation_list():
			if clip=="RESET":continue
			var player:=AnimationPlayer.new()
			animation_root.add_child(player)
			player.root_node=NodePath("..")
			player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var library:=AnimationLibrary.new()
			library.add_animation(clip,source.get_animation(clip))
			player.add_animation_library(&"",library)
			_players[String(clip)]=player
		source.stop()
	set_process(false)
	if TimeOfDayPreset.lights_on: _light_lamps.call_deferred()

const LAMP_COLOR := Color(0.92, 0.95, 1.0)   ## tower lamps: cool white
const BEACON_COLOR := Color(1.0, 0.86, 0.5)
static var _flame_mesh: SphereMesh
static var _halo_mesh: SphereMesh
static var _beacon_mesh: SphereMesh
static var _beacon_halo: SphereMesh
## Dusk / night: a flame on every modelled torch / dock lamp ("...Lamp" nodes) and a
## few warm lights. Upgrades read at a glance in the dark: Lv.1 lights two torches,
## the Level2 group adds two more, and Level3 crowns the tower with a bright gold
## beacon ("...Beacon" nodes) on its standard. Lights and flames live inside their
## level group, so set_level() shows and hides them. Previews stay dark.
func _light_lamps() -> void:
	if _preview or not is_inside_tree(): return
	_make_lamp_meshes()
	var groups := {}
	for node in find_children("*", "Node3D", true, false):
		var title := String(node.name)
		if title.ends_with("Beacon"):
			_beacon(node)
		elif title.ends_with("Lamp"):
			var holder := _level_group(node)
			if not groups.has(holder): groups[holder] = []
			groups[holder].append(node)
	for holder: Node3D in groups:
		var lamps: Array = groups[holder]
		var centre := Vector3.ZERO
		for lamp: Node3D in lamps:
			lamp.add_child(_glow(_flame_mesh, "Flame")); lamp.add_child(_glow(_halo_mesh, "Halo"))
			centre += lamp.global_position
		centre /= lamps.size()
		# Two lights on opposite diagonals, so the wall faces in front of each get one.
		var halves := [[], []]
		for lamp: Node3D in lamps:
			var d: Vector3 = lamp.global_position-centre
			halves[0 if d.x+d.z >= 0.0 else 1].append(lamp.global_position)
		for half: Array in halves:
			if half.is_empty(): continue
			var at := Vector3.ZERO
			for p: Vector3 in half: at += p
			at /= half.size()
			var out := Vector3(at.x-centre.x, 0, at.z-centre.z)
			# Lifted above the torches and pushed out a little: the light falls on the
			# wall tops, merlons and weapons as well as the walls, so tops stay readable.
			var spot := at+out.normalized()*.22+Vector3.UP*.45 if out.length() > .01 else at+Vector3.UP*.45
			_add_light(holder, spot, LAMP_COLOR, 0.55, 1.7)   # soft, wide white wash

## The nearest Level<N> group above a node (or this visual when it has none).
func _level_group(node: Node) -> Node3D:
	var at := node.get_parent()
	while at != null and at != self:
		if String(at.name).begins_with("Level"): return at as Node3D
		at = at.get_parent()
	return self

func _beacon(node: Node3D) -> void:
	var fire := _glow(_beacon_mesh, "BeaconFire")
	node.add_child(fire)
	var halo := _glow(_beacon_halo, "BeaconHalo"); halo.scale = Vector3.ONE*1.9
	node.add_child(halo)
	_add_light(node, node.global_position, BEACON_COLOR, 2.4, 1.7)

func _add_light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new(); light.name = "TorchLight"
	light.light_color = color; light.light_energy = energy; light.omni_range = reach
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = at
	var flicker := light.create_tween().set_loops()
	flicker.tween_property(light, "light_energy", energy*.84, .23+randf()*.1).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(light, "light_energy", energy*1.09, .31+randf()*.1).set_trans(Tween.TRANS_SINE)

func _glow(mesh: Mesh, title: String) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = title; part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

static func _make_lamp_meshes() -> void:
	if _flame_mesh != null: return
	_flame_mesh = SphereMesh.new(); _flame_mesh.radius = .036; _flame_mesh.height = .08
	_flame_mesh.radial_segments = 6; _flame_mesh.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.86, 0.9, 0.98)
	_flame_mesh.material = glow
	_beacon_mesh = SphereMesh.new(); _beacon_mesh.radius = .06; _beacon_mesh.height = .13
	_beacon_mesh.radial_segments = 8; _beacon_mesh.rings = 4
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.93, 0.62)
	_beacon_mesh.material = gold
	_halo_mesh = SphereMesh.new(); _halo_mesh.radius = .09; _halo_mesh.height = .18
	_halo_mesh.radial_segments = 8; _halo_mesh.rings = 4
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.albedo_color = Color(0.7, 0.8, 1.0, 0.11)
	_halo_mesh.material = halo
	_beacon_halo = _halo_mesh.duplicate()
	var gold_halo := halo.duplicate() as StandardMaterial3D
	gold_halo.albedo_color = Color(1.0, 0.65, 0.25, 0.35)
	_beacon_halo.material = gold_halo

## The two bed stops were baked into the turning assembly's mesh; they stay on the bed.
func _fix_mortar_stops() -> void:
	var assembly: MeshInstance3D=_part("FixedBase").get_child(0)
	var source: Mesh=assembly.mesh
	if not _mortar_stops.has(source):_mortar_stops[source]=_split_blocks(source,Vector2(-.5,.5))
	assembly.mesh=_mortar_stops[source][0]
	var stops:=MeshInstance3D.new();stops.name="BedStops";stops.mesh=_mortar_stops[source][1]
	add_child(stops)
	stops.global_transform=assembly.global_transform

## Solid blocks centered beyond the reach go to the second mesh.
static func _split_blocks(source: Mesh, center: Vector2) -> Array[ArrayMesh]:
	var arrays:=source.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var owners:={}
	var weld:=func(index: int) -> String:return str(points[index].snappedf(.0005))
	var root:=func(key: String) -> String:
		while owners.get(key,key)!=key:key=owners[key]
		return key
	for t in range(0,indices.size(),3):
		for k in [1,2]:owners[root.call(weld.call(indices[t+k]))]=root.call(weld.call(indices[t]))
	var bounds:={}
	for index in points.size():
		var block: String=root.call(weld.call(index))
		bounds[block]=bounds[block].expand(points[index]) if bounds.has(block) else AABB(points[index],Vector3.ZERO)
	var kept:=PackedInt32Array();var moved:=PackedInt32Array()
	for t in range(0,indices.size(),3):
		var middle: Vector3=bounds[root.call(weld.call(indices[t]))].get_center()
		var triangle:=PackedInt32Array([indices[t],indices[t+1],indices[t+2]])
		if Vector2(middle.x,middle.z).distance_to(center)>MORTAR_DISC_REACH:moved.append_array(triangle)
		else:kept.append_array(triangle)
	var result: Array[ArrayMesh]=[]
	for part in [kept,moved]:
		var copy:=arrays.duplicate()
		copy[Mesh.ARRAY_INDEX]=part
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy,[],{},MESH_FLAGS)
		mesh.surface_set_material(0,source.surface_get_material(0))
		result.append(mesh)
	return result

## Turns everything but the named part around the body center. Art keeps its
## internal layout, so the baked animation paths stay valid.
func _mount_rotor(fixed: String) -> void:
	var part:=_part(fixed)
	if part!=null:part.reparent(self,true)
	_rotor=Node3D.new();_rotor.name="Rotor";_rotor.position=_center;add_child(_rotor)
	_art.reparent(_rotor,true)
	for marker in _muzzles:_barrels.append(_rotor.to_local(marker.global_position))

func aim_pivot() -> Node3D:return _aim if tower_kind=="sentry" else null
func aim_pitch_limits() -> Vector2:return SENTRY_PITCH
## Yaw follows the target; elevation is the launch angle of the shell's actual arc.
func aim_ballistic(point: Vector3, arc: float, delta: float) -> bool:
	if _rotor==null or _aim==null or _preview:return true
	var start:=muzzle_position()
	var offset:=point-start
	var flat:=Vector2(offset.x,offset.z).length()
	var elevation:=clampf(atan2(offset.y+4.0*arc,flat),MORTAR_ELEVATION.x,MORTAR_ELEVATION.y)
	var local:=to_local(point)-_center
	var yaw:=atan2(-local.x,-local.z) if Vector2(local.x,local.z).length_squared()>0.0001 else _yaw
	var turn:=TowerConstants.AIM_TURN_SPEED*maxf(0.0,delta)
	_yaw=rotate_toward(_yaw,yaw,turn)
	_mortar_elevation=move_toward(_mortar_elevation,elevation,turn)
	_rotor.rotation.y=_yaw
	_aim.rotation.x=_mortar_elevation-MORTAR_REST_ELEVATION
	return absf(angle_difference(_yaw,yaw))<=TowerConstants.AIM_TOLERANCE and absf(_mortar_elevation-elevation)<=TowerConstants.AIM_TOLERANCE
func set_wave_motion(active: bool) -> void:
	if tower_kind!="crossfire" or _preview or _rotor==null:return
	_spin_target=SPIN_SPEED if active else 0.0
	set_process(true)
func rotor() -> Node3D:return _rotor
func spin_speed() -> float:return _spin_speed
func stream_ready() -> bool:return _rotor!=null and _spin_target>0.0 and _spin_speed>SPIN_SPEED*.5
## Muzzles in the rotor's frame, read while it is at rest.
func stream_barrels() -> PackedVector3Array:return _barrels
func gun_count() -> int:return _muzzles.size() if tower_kind=="broadside" else 0
func gun_position(gun: int) -> Vector3:return _muzzles[gun].global_position
## Every muzzle faces straight out of its own side of the hull.
func gun_direction(gun: int) -> Vector3:
	var along:=motion_root().global_basis.x.normalized()
	return along*signf(motion_root().to_local(_muzzles[gun].global_position).x-_center.x)
func fire_gun(gun: int, effects: Node) -> void:
	if _preview:return
	shot_count+=1
	if _guns.is_empty():
		for marker in _muzzles:
			_guns.append(marker.get_parent_node_3d())
			_gun_rest.append(_guns[-1].position)
			_gun_kick.append(0.0)
	_gun_kick[gun]=1.0
	if effects!=null:
		effects.play_restored_shot(3,shot_sound)
		effects.restored_bursts.emit(_muzzles[gun].global_position,"broadside")
	set_process(true)
func motion_root() -> Node3D:return _motion if _motion!=null else self
func set_patrol_offset(offset: float) -> void:
	if _motion!=null:_motion.position=_motion_rest+Vector3(offset,0,0)
func set_preview() -> void:
	_preview=true
	set_process(false)
	for mesh in find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func prepare_target(target: Node3D) -> void:
	_target=target.global_position
	if tower_kind=="broadside":side=-1 if motion_root().to_local(_target).x<_center.x else 1
func _selected_muzzles() -> Array[Node3D]:
	if tower_kind=="broadside":
		return _muzzles.filter(func(n):return signf(motion_root().to_local(n.global_position).x-_center.x)==side)
	return _muzzles
func muzzles() -> Array[Node3D]:return _muzzles
func muzzle_position() -> Vector3:
	var markers:=_selected_muzzles()
	markers.sort_custom(func(a,b):return a.global_position.distance_squared_to(_target)<b.global_position.distance_squared_to(_target))
	return markers[0].global_position if not markers.is_empty() else to_global(_center+Vector3.UP*.7)

func _play(clip: String, interval: float, start: float) -> void:
	if _preview or not _players.has(clip):return
	var player: AnimationPlayer=_players[clip]
	var animation:=player.get_animation(clip)
	player.stop(true)
	# Recover within the current attack interval, leaving Ballista's last part for draw.
	var available:=maxf(.03,interval*(.5 if tower_kind=="ballista" else .85))
	player.speed_scale=maxf(1.0,(animation.length-start)/available)
	player.play(clip)
	player.seek(minf(start,animation.length),true)
	_active[clip]=true
	if not clip in last_clips:last_clips.append(clip)
	set_process(true)

func wind_up(remaining: float, interval: float) -> void:
	if tower_kind!="ballista" or _preview or not _active.is_empty() or not _players.has("attack"):return
	var window:=minf(.65,interval*.45)
	if remaining<=0 or remaining>window:return
	var player: AnimationPlayer=_players.attack
	player.play("attack")
	player.seek((1.0-remaining/window)*(28.0/24.0),true)
	player.stop(true)

func fire_event(_target_node: Node3D, effects: Node, interval: float) -> void:
	if _preview:return
	shot_count+=1
	last_clips.clear()
	var firing: Array[Node3D]=_selected_muzzles()
	match tower_kind:
		"ballista":_play("attack",interval,29.0/24.0)
		"sentry":_play("fire",interval,4.0/24.0)
		"mortar":_play("fire",interval,6.0/24.0)
		"crossfire":
			for clip in ["fire_north","fire_east","fire_south","fire_west"]:_play(clip,interval,4.0/24.0)
			firing=[]
		"broadside":_play("fire_port" if side<0 else "fire_starboard",interval,4.0/24.0)
	if effects!=null:
		var kind: int={"sentry":0,"mortar":1,"ballista":2,"broadside":3,"crossfire":4}.get(tower_kind,0)
		effects.play_restored_shot(kind,shot_sound)
		for marker in firing:effects.restored_bursts.emit(marker.global_position,["arrow","shell","bolt","broadside","radial"][kind])
	_update_bolt()

func deploy() -> void:
	if tower_kind!="barracks" or _preview:return
	deployment_count+=1
	# Two soldiers deployed in one pass share one door cycle.
	if not _active.has("open_close"):_play("open_close",4.0,0)

func _update_bolt() -> void:
	if tower_kind!="ballista" or not _players.has("attack"):return
	var player: AnimationPlayer=_players.attack
	# The combat projectile is authoritative; the clip's own flying bolt stays hidden.
	if _bolt!=null:_bolt.visible=not _active.has("attack") or player.current_animation_position>=58.0/24.0
func _process(delta: float) -> void:
	for clip in _active.keys():
		var player: AnimationPlayer=_players[clip]
		player.advance(maxf(0,delta))
		if not player.is_playing():_active.erase(clip)
	_update_bolt()
	_advance_rotor(delta)
	var recoiling:=_advance_guns(delta)
	if _active.is_empty() and not recoiling and is_zero_approx(_spin_speed) and is_zero_approx(_spin_target):set_process(false)

func _advance_rotor(delta: float) -> void:
	_spin_speed=move_toward(_spin_speed,_spin_target,SPIN_ACCELERATION*maxf(0,delta))
	if _rotor!=null and tower_kind=="crossfire":_rotor.rotate_y(_spin_speed*delta)

func _advance_guns(delta: float) -> bool:
	var moving:=false
	for gun in _guns.size():
		if is_zero_approx(_gun_kick[gun]):continue
		_gun_kick[gun]=move_toward(_gun_kick[gun],0.0,GUN_RECOVERY*maxf(0,delta))
		var inward:=-signf(motion_root().to_local(_muzzles[gun].global_position).x-_center.x)
		_guns[gun].position=_gun_rest[gun]+Vector3.RIGHT*inward*GUN_KICK*_gun_kick[gun]
		moving=true
	return moving
