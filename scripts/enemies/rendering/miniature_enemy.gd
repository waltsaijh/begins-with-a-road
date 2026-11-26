@tool
extends Node3D
## Lightweight procedural motion for the editable miniature enemies.
## Legacy scenes (no "Rig" child) keep the original leg/wing swing.
## Art Slice G scenes put the upper body under "Rig" and choose a style:
##   walk   humanoid stride: legs swing + lift, arms counter-swing, body bob / sway / lean
##   glide  robe drifts: slow bob and sway, no legs
##   hop    small quadruped bounding: body hops and pitches, front/back legs together, tail wags
##   gallop horse trot: diagonal leg pairs, body bob + pitch, tail and cape
##   fly    wings flap, body rises on the down-stroke, tail wags
## Part meta: gait (leg phase sign), arm (counter-swing amount, signed by side),
## wing (flap sign), wing_tip (outer wing panel, lags the flap), tail, cape.
@export var flying := false
@export var style := ""
@export var rate := 12.0          ## radians of cycle per second at full walk blend
@export var bob := 0.03           ## metres
@export var sway := 0.05          ## radians, side roll
@export var lean := 0.06          ## radians, forward lean while moving
@export var pitch := 0.0          ## radians, nose up/down per stride (hop / gallop / fly)
@export var swing := 0.45         ## radians, leg swing
@export var lift := 0.04          ## metres a leg rises as it swings forward
@export var flap := 0.5           ## radians, wing beat
@export var wag := 0.3            ## radians, tail
var phase := 0.0
var parts: Array[Node3D] = []
var _rig: Node3D
var _rest := {}

func _ready() -> void:
	_rig = get_node_or_null("Rig") as Node3D
	for child in find_children("*","Node3D",true,false):
		if child.has_meta("gait") or child.has_meta("wing") or child.has_meta("wing_tip") or child.has_meta("arm") or child.has_meta("tail") or child.has_meta("cape"):
			parts.append(child)
			_rest[child] = child.transform
	if _rig != null: _rest[_rig] = _rig.transform

func advance_motion(delta: float, blend: float) -> void:
	if _rig == null or style.is_empty():
		_legacy(delta, blend)
		return
	var always := style == "fly" or style == "glide"
	var drive := maxf(blend, 0.45 if always else 0.0)
	phase = fposmod(phase+delta*rate*drive, TAU*16.0)
	var s := sin(phase)
	var c := cos(phase)
	var rig_rest: Transform3D = _rest[_rig]
	var offset := Vector3.ZERO
	var rot := Vector3.ZERO
	match style:
		"walk":
			offset.y = bob*absf(c)*blend
			rot = Vector3(-lean*blend, s*sway*0.4*blend, s*sway*blend)
		"glide":
			offset.y = bob*(0.5+0.5*sin(phase*0.5))
			rot = Vector3(-lean*blend, sin(phase*0.5)*sway*0.5, sin(phase*0.5+0.7)*sway)
		"hop":
			offset.y = bob*absf(s)*blend
			rot = Vector3(c*pitch*blend, 0, 0)
		"gallop":
			offset.y = bob*absf(c)*blend
			rot = Vector3(s*pitch*blend-lean*blend, 0, s*sway*blend)
		"fly":
			offset.y = -s*bob
			rot = Vector3(c*pitch, 0, sin(phase*0.5)*sway)
	_rig.transform = Transform3D(Basis.from_euler(rot), offset)*rig_rest
	for part in parts:
		var rest: Transform3D = _rest[part]
		var r := Vector3.ZERO
		var p := Vector3.ZERO
		if part.has_meta("gait"):
			var stride := s*float(part.get_meta("gait"))
			r.x = stride*swing*blend
			p.y = maxf(0.0, stride)*lift*blend
		elif part.has_meta("arm"):
			var amount := float(part.get_meta("arm"))
			r.x = -sin(phase*0.5)*absf(amount) if style == "glide" else -s*amount*blend
		elif part.has_meta("wing"):
			r.z = s*flap*float(part.get_meta("wing"))
		elif part.has_meta("wing_tip"):
			# Outer panel trails the inner wing, so the wing bends at the wrist like a whip.
			r.z = sin(phase-1.1)*flap*0.85*float(part.get_meta("wing_tip"))
		elif part.has_meta("tail"):
			r.y = sin(phase*(0.5 if style == "fly" else 1.0))*wag*maxf(blend, 0.4)
		elif part.has_meta("cape"):
			r.x = (0.06+0.06*sin(phase+1.0))*maxf(blend, 0.3)
		part.transform = Transform3D(rest.basis*Basis.from_euler(r), rest.origin+p)

func _legacy(delta: float, blend: float) -> void:
	phase += delta*(9.0 if flying else 12.0)*maxf(blend,0.4 if flying else 0.0)
	for part in parts:
		if part.has_meta("wing"):
			part.rotation.z = sin(phase)*0.38*float(part.get_meta("wing"))
		else:
			part.rotation.x = sin(phase)*0.42*float(part.get_meta("gait"))*blend
