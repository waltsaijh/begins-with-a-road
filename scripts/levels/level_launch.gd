class_name LevelLaunch
extends RefCounted
## Single-use data handoff into the shared level scene. No Resource mutation.
static var _pending: LevelDefinition

static func select(level: LevelDefinition) -> void:
	_pending = level

static func take(fallback: LevelDefinition) -> LevelDefinition:
	var selected := _pending
	_pending = null
	return selected if selected != null else fallback

static func clear() -> void:
	_pending = null
