extends CanvasLayer
## Run-local first encounter notice, plus an explicitly opened field guide.
var session: Node
var seen := {}
var profiles: Array[Troop] = []
var selected: Troop
@onready var toggle: Button = $Screen/Toggle
@onready var panel: PanelContainer = $Screen/Panel
@onready var entries: ItemList = $Screen/Panel/Layout/Entries
@onready var title: Label = $Screen/Panel/Layout/Title
@onready var description: Label = $Screen/Panel/Layout/Description

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	toggle.pressed.connect(func():
		panel.visible = not panel.visible
		if panel.visible and selected == null and not profiles.is_empty(): show_profile(profiles[0]))
	$Screen/Panel/Layout/Close.pressed.connect(panel.hide)
	entries.item_selected.connect(func(index: int): show_profile(profiles[index]))

func setup(owner_session: Node) -> void:
	session = owner_session
	session.preparation_changed.connect(_preparation)
	session.relic_choice.get_node("Collection").visibility_changed.connect(func():
		if session.relic_choice.get_node("Collection").visible: panel.hide())

func _preparation(available: bool) -> void:
	if not available:
		panel.hide()
		return
	var definition: WaveDefinition = session.get_node("EnemyWave").definition
	if definition == null: return
	var discovered := PackedStringArray()
	for group in definition.groups:
		var profile := group.troop
		if profile == null or seen.has(profile.troop_name): continue
		seen[profile.troop_name] = true
		profiles.append(profile)
		discovered.append(profile.localized_name())
	entries.clear()
	for profile in profiles: entries.add_item(profile.localized_name(),profile.icon)
	var english := TranslationServer.get_locale().begins_with("en")
	toggle.text = ("Enemy intelligence" if english else "敵軍情報")
	if not discovered.is_empty(): toggle.text = ("Intel · %d new" if english else "敵軍情報 · 新 %d") % discovered.size()
	toggle.visible = not profiles.is_empty()

func show_profile(profile: Troop) -> void:
	if profile == null or get_tree().paused: return
	selected = profile
	if session != null: session.relic_choice.get_node("Collection").hide()
	title.text = profile.localized_name()
	description.text = profile.intelligence_text()
	description.text += "\n\nHP %s · ×%s" % [str(profile.max_health),str(profile.speed_multiplier)]
	$Screen/Panel/Layout/Close.text = "Close" if TranslationServer.get_locale().begins_with("en") else "關閉"
	var index := profiles.find(profile)
	if index >= 0: entries.select(index)
	panel.show()

func _process(_delta: float) -> void:
	$Screen.visible = not get_tree().paused and (session == null or not session.choosing_relic)
	if session != null: toggle.visible = not profiles.is_empty() and not session.relic_choice.get_node("Collection").visible
