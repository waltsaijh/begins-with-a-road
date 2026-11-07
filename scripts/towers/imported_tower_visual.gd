extends Node3D
const COLOR_IDENTITY = preload("res://assets/data/rendering/tower_color_identity.tres")
## Presentation-only adapter for the GLB-derived Art Slice D assets.
## Manual animation advance follows simulation delta; idle towers do no per-frame work.
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
var _directions := {}
var _players := {}
var _active := {}
var _preview := false
var _bolt_meshes: Array[MeshInstance3D] = []
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
	_aim=_part("AimPivot") if tower_kind=="sentry" else null
	for node in _art.find_children("*","Node3D",true,false):
		if node is Marker3D and ("Muzzle" in String(node.name) or "ArrowRelease" in String(node.name)):_muzzles.append(node)
		if node is MeshInstance3D and "ReadyBolt" in String(node.name):_bolt_meshes.append(node)
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

func aim_pivot() -> Node3D:return _aim
func motion_root() -> Node3D:return _motion if _motion!=null else self
func set_patrol_offset(offset: float) -> void:
	if _motion!=null:_motion.position=_motion_rest+Vector3(offset,0,0)
func set_preview() -> void:
	_preview=true
	set_process(false)
	for mesh in find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _direction(point: Vector3) -> int:
	var d:=to_local(point)-_center
	return (1 if d.x>0 else 3) if absf(d.x)>absf(d.z) else (2 if d.z>0 else 0)
func prepare_target(target: Node3D) -> void:
	_target=target.global_position
	if tower_kind=="crossfire":_directions[_direction(_target)]=true
	if tower_kind=="broadside":side=-1 if motion_root().to_local(_target).x<_center.x else 1
func _muzzle_direction(marker: Node3D) -> int:
	var n:=String(marker.name)
	return int(n.right(1)) if tower_kind=="crossfire" else 0
func _selected_muzzles() -> Array[Node3D]:
	if tower_kind=="broadside":
		return _muzzles.filter(func(n):return signf(motion_root().to_local(n.global_position).x-_center.x)==side)
	if tower_kind=="crossfire":return _muzzles.filter(func(n):return _muzzle_direction(n)==_direction(_target))
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
			if _directions.is_empty():_directions[_direction(_target)]=true
			for direction in _directions:_play(["fire_north","fire_east","fire_south","fire_west"][direction],interval,4.0/24.0)
			firing=_muzzles.filter(func(n):return _directions.has(_muzzle_direction(n)))
		"broadside":_play("fire_port" if side<0 else "fire_starboard",interval,4.0/24.0)
	_directions.clear()
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
	var visible_bolt:=not _active.has("attack") or player.current_animation_position>=58.0/24.0
	# The actual combat projectile is authoritative; suppress the preview flying bolt.
	for mesh in _bolt_meshes:mesh.visible=visible_bolt
func _process(delta: float) -> void:
	for clip in _active.keys():
		var player: AnimationPlayer=_players[clip]
		player.advance(maxf(0,delta))
		if not player.is_playing():_active.erase(clip)
	_update_bolt()
	if _active.is_empty():set_process(false)
