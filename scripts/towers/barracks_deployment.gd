@tool
class_name BarracksDeployment
extends Resource
## Source: prototype SoldierUnit / SoldierManager. Distances are in road cells.
@export var unit_model: PackedScene
@export var count := 2
@export var health := 40.0
@export var damage := 4.0
@export var interval := 1.0
@export var respawn_seconds := 5.0
@export var speed := 64.0/48.0
@export var engage_radius := 1.5
@export var melee_distance := 16.0/48.0
@export var local_radius := 2.1

func configuration_error() -> String:
	if unit_model == null or count <= 0: return "兵營缺少友軍模型或部署數量"
	for value: float in [health,interval,respawn_seconds,speed,engage_radius,melee_distance,local_radius]:
		if not is_finite(value) or value <= 0: return "兵營參數必須為正有限數值"
	return "兵營傷害無效" if not is_finite(damage) or damage < 0 else ""
