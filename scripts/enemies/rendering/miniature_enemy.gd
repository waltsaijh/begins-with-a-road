@tool
extends Node3D
## Shared lightweight gait for the six editable Phase 4 miniatures.
@export var flying := false
var phase := 0.0
var parts: Array[Node3D] = []

func _ready() -> void:
	for child in find_children("*","Node3D",true,false):
		if child.has_meta("gait") or child.has_meta("wing"): parts.append(child)

func advance_motion(delta: float, blend: float) -> void:
	phase += delta*(9.0 if flying else 12.0)*maxf(blend,0.4 if flying else 0.0)
	for part in parts:
		if part.has_meta("wing"):
			part.rotation.z = sin(phase)*0.38*float(part.get_meta("wing"))
		else:
			part.rotation.x = sin(phase)*0.42*float(part.get_meta("gait"))*blend
