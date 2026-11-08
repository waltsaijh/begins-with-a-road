@tool
class_name TrailAbility
extends EnemyAbility
## Marks every road tile this enemy walks on until the wave ends. Other ground
## enemies standing on a marked tile move (1 + speed_bonus) times faster,
## refreshed each frame and lasting `seconds` after they step off; the marker
## itself never benefits from its own trail. The strip uses the troop's
## accent color at `opacity`; it fades out when the wave ends.
const RoadTrail = preload("res://scripts/enemies/abilities/road_trail.gd")
@export_range(0.0, 2.0, 0.05, "or_greater") var speed_bonus := 0.25
@export_range(0.05, 5.0, 0.05, "or_greater") var seconds := 0.5
## Strip width in tiles.
@export_range(0.05, 1.0, 0.01) var width := 0.16
@export_range(0.0, 1.0, 0.01) var opacity := 0.35
@export var icon: Texture2D = preload("res://assets/sprites/effects/agile.png")
var _last: Variant = null

func start() -> void:
	_last = null

func update(host: Node, _delta: float) -> void:
	var cell: Vector2i = host.cell_of(enemy)
	if _last is Vector2i and cell == _last: return
	var color: Color = enemy.troop.accent_color if enemy.troop != null else Color.WHITE
	color.a = opacity
	host.service(RoadTrail).mark(enemy, cell, _last, {"color": color, "width": width, "bonus": speed_bonus, "seconds": seconds, "icon": icon})
	_last = cell

func describe(english: bool) -> String:
	return "Leaves a trail; other ground enemies on it briefly move faster." if english else "沿途留下痕跡，其他地面敵軍走在上面會短暫加速。"

func configuration_error() -> String:
	if not is_finite(speed_bonus) or speed_bonus < 0: return "加速幅度必須非負且有限"
	if not is_finite(seconds) or seconds <= 0: return "加速持續時間必須為正有限數值"
	if not is_finite(width) or width <= 0 or width > 1: return "痕跡寬度必須在 0–1 格之間"
	return ""
