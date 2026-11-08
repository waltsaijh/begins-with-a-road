class_name LevelLaunch
extends RefCounted
## Single-use data handoff into the shared level scene. No Resource mutation.
static var _pending: LevelDefinition
static var _menu_map := ""

static func request_menu_map(id: String) -> void:
	_menu_map = id

static func take_menu_map() -> String:
	var id := _menu_map
	_menu_map = ""
	return id

static func select(level: LevelDefinition) -> void:
	_pending = level

static func take(fallback: LevelDefinition) -> LevelDefinition:
	var selected := _pending
	_pending = null
	return selected if selected != null else fallback

static func clear() -> void:
	_pending = null
