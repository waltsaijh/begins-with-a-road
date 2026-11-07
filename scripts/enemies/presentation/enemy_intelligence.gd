extends CanvasLayer
## Actual spawn discovery is run-local; only codex unlock IDs persist.
const CodexText = preload("res://scripts/enemies/presentation/enemy_codex_text.gd")
var session: Node
var seen := {}
var read := {}
var pending: Array[Troop] = []
var profiles: Array[Troop] = []
var selected: Troop
var _queue_mode := false
var _listed: Array[Troop] = []
var _hud: Node
@onready var toggle: Button = $Screen/Toggle
@onready var panel: Control = $Screen/Panel
@onready var layout: VBoxContainer = $Screen/Panel/Paper/Layout
@onready var entries: ItemList = $Screen/Panel/Paper/Layout/Body/Entries
@onready var detail: VBoxContainer = $Screen/Panel/Paper/Layout/Body/Scroll/Detail
@onready var title: Label = $Screen/Panel/Paper/Layout/Body/Scroll/Detail/Title
@onready var description: Label = $Screen/Panel/Paper/Layout/Body/Scroll/Detail/Description

func _ready() -> void:
	panel.hide()
	toggle.pressed.connect(open_notifications)
	layout.get_node("Close").pressed.connect(close_panel)
	panel.close_requested.connect(close_panel)
	entries.item_selected.connect(func(index: int):
		_acknowledge(selected)
		_display(_listed[index]))
	get_viewport().size_changed.connect(_fit)
	_fit()

func setup(owner_session: Node) -> void:
	session = owner_session
	_hud = session.get_node("LevelHUD")
	profiles = TroopCatalog.all()
	session.get_node("EnemyWave").enemy_spawned.connect(_on_enemy_spawned)

func _on_enemy_spawned(enemy: Node3D) -> void:
	var profile: Troop = enemy.troop
	var id := profile.troop_name
	if seen.has(id): return
	seen[id] = true
	if not profiles.has(profile): profiles.append(profile)
	pending.append(profile)
	LevelProgress.encounter_enemy(id)
	_refresh_notice()

func _unlocked(profile: Troop) -> bool:
	return seen.has(profile.troop_name) or LevelProgress.enemy_unlocked(profile.troop_name)

func _refresh_notice() -> void:
	var en := TranslationServer.get_locale().begins_with("en")
	toggle.text = "!  %d" % pending.size()
	toggle.icon = pending[0].icon if not pending.is_empty() else null
	toggle.tooltip_text = ("New enemy discovered · %d unread" if en else "新敵軍發現 · %d 則未讀") % pending.size()

func _open(queue: bool) -> bool:
	if not _hud.begin_inspection(self): return false
	_queue_mode = queue
	panel.show()
	_refresh_entries()
	_fit()
	layout.get_node("Close").grab_focus()
	return true

func open_notifications() -> void:
	if pending.is_empty() or not _open(true): return
	_display(pending[0])

func open_codex() -> void:
	if not _open(false): return
	_display(profiles[0] if not profiles.is_empty() else null)

## Also used by the next-wave info icon. Unencountered profiles stay concealed.
func show_profile(profile: Troop) -> void:
	if profile == null or not _open(false): return
	_display(profile)

func _refresh_entries() -> void:
	entries.clear()
	_listed.assign(pending if _queue_mode else profiles)
	for profile in _listed:
		var unlocked := _unlocked(profile)
		var unread := pending.has(profile)
		entries.add_item((profile.localized_name()+(" · !" if unread else "")) if unlocked else "???",profile.icon if unlocked else null)
		if unlocked and profile.icon != null:
			entries.set_item_icon_modulate(entries.item_count-1,profile.icon_color())

func _display(profile: Troop) -> void:
	selected = profile
	var en := TranslationServer.get_locale().begins_with("en")
	layout.get_node("Heading").text = ("Newly discovered enemies" if en else "新發現敵軍") if _queue_mode else ("Enemy codex" if en else "敵軍圖鑑")
	var unlocked := profile != null and _unlocked(profile)
	title.text = profile.localized_name() if unlocked else "???"
	description.text = CodexText.description(profile) if unlocked else ("Encounter this enemy to unlock its record." if en else "在戰場遭遇後解鎖此敵軍情報。")
	detail.get_node("Appearance").visible = unlocked
	detail.get_node("Appearance/Stats").text = ("HP %s\n\n%s" % [str(profile.max_health),profile.type_description()]) if unlocked else ""
	detail.get_node("Route").text = profile.route_description() if unlocked else ""
	detail.get_node("Appearance/Preview").display(profile if unlocked else null)
	layout.get_node("Body/Scroll").scroll_vertical = 0
	layout.get_node("Close").text = ("Next enemy" if en else "下一種敵軍") if _queue_mode and pending.size() > 1 else ("Close" if en else "關閉")
	var index := _listed.find(profile)
	if index >= 0: entries.select(index)
	_refresh_notice()

func _acknowledge(profile: Troop) -> void:
	if profile == null or not seen.has(profile.troop_name): return
	read[profile.troop_name] = true
	pending.erase(profile)
	_refresh_notice()

func close_panel() -> void:
	if not panel.visible: return
	_acknowledge(selected)
	if _queue_mode and not pending.is_empty():
		_refresh_entries()
		_display(pending[0])
		return
	panel.hide()
	_hud.end_inspection(self)

func _fit() -> void:
	var paper: Control = $Screen/Panel/Paper
	var viewport := get_viewport().get_visible_rect().size
	var extent := Vector2(minf(780,viewport.x-40),minf(520,viewport.y-80))
	paper.offset_left = -extent.x*0.5
	paper.offset_right = extent.x*0.5
	paper.offset_top = -extent.y*0.5
	paper.offset_bottom = extent.y*0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_notice()
		if panel.visible:
			_refresh_entries()
			_display(selected)

func _process(_delta: float) -> void:
	toggle.visible = not pending.is_empty() and not panel.visible and not get_tree().paused and session != null and not session.choosing_relic and not session.finished
	if session != null and session.relic_choice.get_node("Collection").visible: toggle.hide()

func _exit_tree() -> void:
	if is_instance_valid(_hud) and _hud.is_inside_tree(): _hud.end_inspection(self)
