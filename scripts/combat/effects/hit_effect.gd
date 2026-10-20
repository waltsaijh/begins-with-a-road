@tool
class_name HitEffect
extends Resource
func configuration_error() -> String:
	return ""

## Override for additional on-hit behavior. Base damage is applied beforehand.
func apply(_target: Node3D, _source: Node3D, _damage: float) -> void:
	pass
