extends Node3D
## Independent manual review: shortcuts affect this synthetic scene only.
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Endpoints = preload("res://tests/fixtures/level_fixture.gd")
const KEYS = ["mortar","ballista","crossfire","broadside","barracks","sentry"]
const ANCHORS = [Vector3i(3,0,5),Vector3i(6,0,5),Vector3i(9,0,5),Vector3i(12,0,4),Vector3i(14,0,5),Vector3i(16,0,6)]
var session: Node3D
var hint: Label
var picker: Button
var relic_list: ItemList
var selected_relic_index := 0
var grant_button: Button
var remove_button: Button
var refill_button: Button
var relic_description: Label
var relic_feedback: Label
var relic_panel: VBoxContainer
var render_viewport: SubViewport
func _ready() -> void: setup.call_deferred()
func setup() -> void:
	TranslationServer.set_locale("zh_TW")
	var level := LevelDefinition.new()
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-9,0,-5)
	for x in 18:
		for y in 10: terrain.set_cell_item(Vector3i(x,0,y),6)
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,4), "Start")
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,7), "Start2")
	Endpoints.endpoint(terrain, Endpoints.Goal, Vector2i(17,4), "Goal")
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	for act_index in 3:
		var act := ActDefinition.new()
		act.add_start_after_completion = false
		act.title = "ACT %d" % (act_index+1)
		var wave := WaveDefinition.new()
		wave.move_speed = 1.6
		wave.reward = 20
		for origin in 2:
			for key in ["soldier","quickfeet","heavy"]:
				var group := WaveSpawnGroup.new()
				group.start_index = origin
				group.enemy_count = 8
				group.interval_ticks = 3
				group.troop = load("res://assets/data/troops/"+key+".tres").duplicate()
				group.troop.max_health = 1200
				wave.groups.append(group)
		act.waves = [wave]
		level.acts.append(act)
	session = load("res://scenes/level.tscn").instantiate()
	session.level = level
	session.get_node("CardPlacement").initial_card_count = 0
	if render_viewport != null: render_viewport.add_child(session)
	else: add_child(session)
	for i in 120:
		await get_tree().process_frame
		if not session.get_node("PortalMap").computing: break
	for i in KEYS.size():
		var definition: TowerDefinition = load("res://assets/data/towers/"+KEYS[i]+".tres")
		var card := BuildCard.from_parts(definition,definition.first_tile_preset())
		var tower: DefenseTower = session.get_node("TowerMap").place_card(card,ANCHORS[i])
		if tower == null: push_error("Playground tower placement failed: "+KEYS[i])

	refill()
	var shop: Node = session.get_node("CardPlacement/Shop")
	shop.coins = 100
	shop.available = shop._deal()
	shop._refresh()
	shop.view.set_available(true)
	var layer := CanvasLayer.new()
	layer.layer = 4
	if render_viewport != null: render_viewport.add_child(layer)
	else: add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var panel := PanelContainer.new()
	screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -360
	panel.offset_right = -16
	panel.offset_top = 84
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f1e8")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	panel.add_theme_color_override("font_color",Color("34504e"))
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var toggle := Button.new()
	toggle.text = "自由增添／移除遺物（測試） ▾"
	layout.add_child(toggle)
	relic_panel = VBoxContainer.new()
	layout.add_child(relic_panel)
	toggle.pressed.connect(func():
		relic_panel.visible = not relic_panel.visible
		toggle.text = "自由增添／移除遺物（測試） " + ("▾" if relic_panel.visible else "▸"))
	hint = Label.new()
	hint.text = "F7 全部專屬 / B 補齊塔牌\nF9 清完本波 → 三選一"
	hint.add_theme_font_size_override("font_size",16)
	hint.add_theme_color_override("font_color",Color("34504e"))
	relic_panel.add_child(hint)
	refill_button = Button.new()
	refill_button.text = "補齊缺少的塔牌（B）"
	refill_button.pressed.connect(refill)
	relic_panel.add_child(refill_button)
	# Keep the list in the same viewport: native popup windows do not share the
	# camera's deferred press/release delivery or embedded-game focus reliably.
	picker = Button.new()
	relic_panel.add_child(picker)
	relic_list = ItemList.new()
	relic_list.custom_minimum_size.y = 160
	relic_list.add_theme_color_override("font_color",Color("34504e"))
	relic_list.add_theme_color_override("font_selected_color",Color("173e3b"))
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color("d9e8df")
	relic_list.add_theme_stylebox_override("selected",selected_style)
	relic_list.add_theme_stylebox_override("selected_focus",selected_style)
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color("fffdf6")
	relic_list.add_theme_stylebox_override("panel",list_style)
	relic_panel.add_child(relic_list)
	relic_list.hide()
	picker.pressed.connect(func(): relic_list.visible = not relic_list.visible)
	relic_list.item_selected.connect(func(index: int):
		selected_relic_index = index
		relic_list.hide()
		_refresh_relic_tool())
	relic_description = Label.new()
	relic_description.add_theme_color_override("font_color",Color("34504e"))
	relic_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_description.custom_minimum_size.x = 300
	relic_panel.add_child(relic_description)
	grant_button = Button.new()
	grant_button.pressed.connect(grant_selected_relic)
	relic_panel.add_child(grant_button)
	remove_button = Button.new()
	remove_button.text = "移除所選遺物一份"
	remove_button.pressed.connect(remove_selected_relic)
	relic_panel.add_child(remove_button)
	relic_feedback = Label.new()
	relic_feedback.add_theme_color_override("font_color",Color("34504e"))
	relic_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_panel.add_child(relic_feedback)
	session.get_node("TowerMap").relics.changed.connect(_refresh_relic_tool)
	_refresh_relic_tool()
	if "--smoke" in OS.get_cmdline_user_args(): await smoke()

func _refresh_relic_tool() -> void:
	var relics: RunRelics = session.get_node("TowerMap").relics
	if relic_list.item_count != relics.catalog.entries.size():
		relic_list.clear()
		for relic in relics.catalog.entries: relic_list.add_item(tr(relic.name_key))
	for index in relics.catalog.entries.size():
		var relic: RelicDefinition = relics.catalog.entries[index]
		var count := int(relics.held.get(relic.id,0))
		var limit := relic.max_stacks if relic.repeatable else 1
		relic_list.set_item_text(index,"%s（%d/%d）" % [tr(relic.name_key),count,limit])
	if relic_list.item_count == 0:
		grant_button.disabled = true
		remove_button.disabled = true
		grant_button.text = "沒有可用遺物"
		return
	selected_relic_index = clampi(selected_relic_index,0,relic_list.item_count-1)
	relic_list.select(selected_relic_index)
	picker.text = relic_list.get_item_text(selected_relic_index)+" ▾"
	var relic: RelicDefinition = relics.catalog.entries[selected_relic_index]
	relic_description.text = tr(relic.description_key)
	if relic.id == &"gold": relic_description.text += "\n移除持有紀錄不回收已發放金幣。"
	grant_button.disabled = not relics.can_acquire(relic)
	grant_button.text = "已達持有上限" if grant_button.disabled else "立即增添所選遺物"
	remove_button.disabled = int(relics.held.get(relic.id,0)) <= 0

func grant_selected_relic() -> bool:
	if get_tree().paused or relic_list.item_count == 0: return false
	var relics: RunRelics = session.get_node("TowerMap").relics
	var relic: RelicDefinition = relics.catalog.entries[selected_relic_index]
	var success := relics.acquire(relic)
	relic_feedback.text = ("已取得：" if success else "已達持有上限：") + tr(relic.name_key)
	return success

func remove_selected_relic() -> bool:
	if get_tree().paused or relic_list.item_count == 0: return false
	var relics: RunRelics = session.get_node("TowerMap").relics
	var relic: RelicDefinition = relics.catalog.entries[selected_relic_index]
	var success := relics.remove(relic)
	relic_feedback.text = ("已移除一份：" if success else "尚未持有：") + tr(relic.name_key)
	return success

func refill() -> bool:
	if get_tree().paused or not is_instance_valid(session): return false
	var placement: Node = session.get_node("CardPlacement")
	var present := {}
	for card: BuildCard in placement.cards:
		if card.tower != null: present[card.tower] = true
	var added := 0
	for key in KEYS:
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		if present.has(definition): continue
		if placement.add_card(BuildCard.from_parts(definition,definition.first_tile_preset())): added += 1
	if is_instance_valid(relic_feedback):
		relic_feedback.text = "手牌已齊全，無需補牌" if added == 0 else "已補入 %d 張缺少的塔牌" % added
	return true

func all_exclusives() -> void:
	var relics: RunRelics = session.get_node("TowerMap").relics
	for relic in relics.catalog.entries:
		if relic.tower != null and relics.can_acquire(relic): relics.acquire(relic)

func finish_wave() -> void:
	var wave: Node = session.get_node("EnemyWave")
	if not wave.active: return
	wave._process(10000)
	for enemy in wave.living_enemies(): enemy.take_damage(enemy.health+enemy.shield)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or get_tree().paused: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	match key:
		KEY_F7: all_exclusives()
		KEY_B: refill()
		KEY_F9: finish_wave()
		_: return
	get_viewport().set_input_as_handled()

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var viewport: Viewport = render_viewport if render_viewport != null else get_viewport()
	viewport.get_texture().get_image().save_png(Artifacts.path("relics/"+label+".png"))

func smoke() -> void:
	await get_tree().create_timer(0.5).timeout
	await snapshot("preparation")
	all_exclusives()
	session._on_start_requested()
	await get_tree().create_timer(9).timeout
	await snapshot("combat")
	finish_wave()
	await get_tree().create_timer(0.4).timeout
	await snapshot("reward")
	print("PHASE3_SHOWCASE: relics=",session.get_node("TowerMap").relics.held.size()," shots=",session.get_node("TowerMap").combat.shots_fired," soldiers=",session.get_node("TowerMap").combat.barracks.units.size())
	get_tree().quit()
