extends CanvasLayer
## Actual spawn discovery is run-local; only unlock IDs persist.
## The notice counts new enemies; clicking it opens the progress page on the first one.
var session: Node
var seen := {}
var read := {}
var pending: Array[Troop] = []
var _hud: Node
var _last_read := ""
@onready var toggle: Button = $Screen/Toggle

func _ready() -> void:
	toggle.pressed.connect(open_notifications)

func setup(owner_session: Node) -> void:
	session = owner_session
	_hud = session.get_node("LevelHUD")
	_hud.progress_page.entry_viewed.connect(_mark_read)
	_refresh_notice()
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
	toggle.text = ""
	toggle.get_node("Badge").visible = not pending.is_empty()
	toggle.get_node("Badge/Count").text = str(pending.size())
	toggle.tooltip_text = (GameText.text("text.enemy_intelligence.1",{},en)) % pending.size() if not pending.is_empty() else tr("ui.intelligence.title")

func open_notifications() -> void:
	var id := pending[0].troop_name if not pending.is_empty() else _last_read
	if id.is_empty(): id = TroopCatalog.default_troop().troop_name
	_hud.open_progress(id)

func _mark_read(id: String) -> void:
	for profile in pending.duplicate():
		if profile.troop_name != id: continue
		read[id] = true
		_last_read = id
		pending.erase(profile)
	_refresh_notice()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_notice()

func _process(_delta: float) -> void:
	toggle.visible = session != null and not get_tree().paused and not session.choosing_relic and not session.choosing_event and not session.choosing_start and not session.finished
	if session != null and session.relic_choice.get_node("Collection").visible: toggle.hide()
