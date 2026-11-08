extends CanvasLayer
## Actual spawn discovery is run-local; only unlock IDs persist.
## The notice counts new enemies; clicking it opens the progress page on the first one.
var session: Node
var seen := {}
var read := {}
var pending: Array[Troop] = []
var _hud: Node
@onready var toggle: Button = $Screen/Toggle

func _ready() -> void:
	toggle.pressed.connect(open_notifications)

func setup(owner_session: Node) -> void:
	session = owner_session
	_hud = session.get_node("LevelHUD")
	session.get_node("EnemyWave").enemy_spawned.connect(_on_enemy_spawned)

func _on_enemy_spawned(enemy: Node3D) -> void:
	var profile: Troop = enemy.troop
	var id := profile.troop_name
	if seen.has(id): return
	seen[id] = true
	pending.append(profile)
	LevelProgress.encounter_enemy(id)
	_refresh_notice()

func _refresh_notice() -> void:
	var en := TranslationServer.get_locale().begins_with("en")
	toggle.text = "!  %d" % pending.size()
	toggle.icon = pending[0].icon if not pending.is_empty() else null
	toggle.tooltip_text = ("New enemy discovered · %d unread" if en else "新敵軍發現 · %d 則未讀") % pending.size()
	# _process stops while paused, so an emptied queue hides the notice here.
	if pending.is_empty(): toggle.hide()

## Every new enemy is now listed there, so the whole notice counts as read.
func open_notifications() -> void:
	if pending.is_empty() or not _hud.open_progress(pending[0].troop_name): return
	for profile in pending: read[profile.troop_name] = true
	pending.clear()
	_refresh_notice()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_notice()

func _process(_delta: float) -> void:
	toggle.visible = not pending.is_empty() and not get_tree().paused and session != null and not session.choosing_relic and not session.finished
	if session != null and session.relic_choice.get_node("Collection").visible: toggle.hide()
