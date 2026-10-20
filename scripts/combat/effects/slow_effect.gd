@tool
class_name SlowEffect
extends HitEffect
@export var icon: Texture2D = preload("res://assets/sprites/effects/slowness.png")
@export_range(0.05, 1.0, 0.05) var speed_multiplier := 0.5
@export_range(0.05, 30.0, 0.05) var duration := 2.0

func configuration_error() -> String:
	return "減速倍率與時間設定無效" if not is_finite(speed_multiplier) or speed_multiplier <= 0 or speed_multiplier > 1 or not is_finite(duration) or duration <= 0 else ""

func apply(target: Node3D, _source: Node3D, _damage: float) -> void:
	target.apply_slow(speed_multiplier, duration, icon)
