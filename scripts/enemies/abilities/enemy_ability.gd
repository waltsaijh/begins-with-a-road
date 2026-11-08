@tool
class_name EnemyAbility
extends Resource
## One enemy ability. The Troop keeps the authored copy (inline or a shared
## .tres); every spawned enemy gets its own duplicate() of it. Exported fields
## are the settings and are copied; plain vars are per-enemy state and start
## from their initial values on each copy.

## The enemy owning this copy; set at spawn, never on the authored resource.
var enemy: Node3D

## At spawn, after the trip is fixed.
func start() -> void:
	pass

## Once per frame while the wave runs. host is the shared EnemyAbilities pass.
func update(_host: Node, _delta: float) -> void:
	pass

## Wave end or cleanup: release targets and visuals; no lasting effect remains.
func stop() -> void:
	pass

## Single-target attacks prefer the highest rank; -1 takes no part.
func taunt_rank(_distance: float) -> int:
	return -1

## Whether a visible cast is in progress (boss status line).
func is_casting() -> bool:
	return false

## One short player-facing line for the codex and progress page.
func describe(_english: bool) -> String:
	return ""

## Empty when the settings are usable.
func configuration_error() -> String:
	return ""
