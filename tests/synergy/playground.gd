extends Node3D
const Fixture = preload("res://tests/synergy/fixture.gd")
var session: Node3D
var scenario := 0
var busy := false
var panel: VBoxContainer
var hint: Label
var status: Label
var new_roads_button: Button
var split_button: Button
var air_button: Button
var viewport_target: SubViewport
var new_roads_added := false
var split_structures: Array[Node3D] = []
func _ready() -> void:
	TranslationServer.set_locale("zh_TW")
	create_ui()
	load_scenario(0)
func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	(viewport_target if viewport_target != null else self).add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var paper := PanelContainer.new()
	screen.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paper.offset_left = -334
	paper.offset_right = -16
	paper.offset_top = 74
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f1e8")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	paper.add_theme_stylebox_override("panel",style)
	panel = VBoxContainer.new()
	paper.add_child(panel)
	for i in 4:
		var button := Button.new()
		button.text = Fixture.TITLES[i]
		button.pressed.connect(load_scenario.bind(i))
		panel.add_child(button)
	hint = Label.new()
	hint.custom_minimum_size.x = 290
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color",Color("34504e"))
	hint.add_theme_font_size_override("font_size",14)
	panel.add_child(hint)
	split_button = Button.new()
	split_button.text = "套用分流：上路拒馬／下路窄口"
	split_button.pressed.connect(apply_split)
	panel.add_child(split_button)
	new_roads_button = Button.new()
	new_roads_button.text = "同一波新增兩條外圍道路（N）"
	new_roads_button.pressed.connect(add_roads)
	panel.add_child(new_roads_button)
	air_button = Button.new()
	air_button.pressed.connect(toggle_air)
	panel.add_child(air_button)
	var refill := Button.new()
	refill.text = "補齊缺少的塔牌與設施牌（B）"
	refill.pressed.connect(refill_cards)
	panel.add_child(refill)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",14)
	status.add_theme_color_override("font_color",Color("34504e"))
	panel.add_child(status)
func load_scenario(index: int) -> void:
	if busy or get_tree().paused: return
	busy = true
	if is_instance_valid(session):
		session.get_parent().remove_child(session)
		session.queue_free()
		await get_tree().process_frame
	scenario = index
	new_roads_added = false
	split_structures.clear()
	session = Fixture.session(index)
	(viewport_target if viewport_target != null else self).add_child(session)
	for i in 120:
		await get_tree().process_frame
		if not session.get_node("PortalMap").computing: break
	Fixture.towers(session)
	for i in 3: await get_tree().process_frame
	var shop: Node = session.get_node("CardPlacement/Shop")
	shop.coins = 150
	shop.balance_changed.emit(shop.coins)
	busy = false
	refill_cards()
	hint.text = ["比較分流前後的鼠群與盾衛兵流量。拒馬只影響 small，窄口只影響 large。",
		"血法師保持 Uniform；用窄口分離 large 主力，觀察治療範圍與嘲諷。",
		"觀察爆破手橘色前搖、塔頂癱瘓圖示與恢復；擊殺施法者會解除效果。",
		"按 N 建兩條較長的新路：偵查兵走新路，飛翼獸保留最短路。可切換空中打擊驗證迫擊砲。遺物與道路只改此測試。" ][index]
	air_button.text = "取得空中打擊"
	new_roads_button.visible = index == 3
	air_button.visible = index == 3
	status.text = "點入口菱形開波；B 補缺牌；F9 清波。"
func preparation() -> bool:
	return not busy and is_instance_valid(session) and not get_tree().paused and not session._wave.active and not session._wave_starting and not session.choosing_relic
func refill_cards() -> void:
	if not preparation(): return
	var placement: Node = session.get_node("CardPlacement")
	for key in Fixture.KEYS:
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		if placement.cards.any(func(c): return c.tower == definition): continue
		placement.add_card(BuildCard.from_parts(definition,definition.first_tile_preset()))
	for key in ["flag","barricade","narrow_passage"]:
		var definition: TrafficStructureDefinition = load("res://assets/data/traffic/"+key+".tres")
		if placement.cards.any(func(c): return c.traffic == definition): continue
		placement.add_card(BuildCard.from_traffic(definition))
func apply_split() -> void:
	if not preparation(): return
	if not split_structures.is_empty():
		status.text = "分流設施已套用；可切換場景重置比較。"
		return
	var manager: TrafficStructures = session.get_node("TowerMap").traffic
	for item in [["barricade",Vector2i(4,0)],["narrow_passage",Vector2i(12,6)]]:
		var structure: Node3D = manager.place(load("res://assets/data/traffic/"+item[0]+".tres"),item[1],0)
		if structure != null: split_structures.append(structure)
	status.text = "已套用分流；Hover 不同兵種比較實際配額。"
func add_roads() -> void:
	if not preparation() or new_roads_added: return
	Fixture.new_roads(session)
	new_roads_added = true
	status.text = "兩條路均誕生於目前 Wave；偵查兵只分配到這批新路。"
func toggle_air() -> void:
	if not preparation(): return
	var relics: RunRelics = session.get_node("TowerMap").relics
	var relic := relics.catalog.find(&"air_strike")
	if relics.held.has(relic.id):
		relics.remove(relic)
		air_button.text = "取得空中打擊"
	else:
		relics.acquire(relic)
		air_button.text = "移除空中打擊"
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or get_tree().paused or busy: return
	match event.physical_keycode:
		KEY_B: refill_cards()
		KEY_N: add_roads()
		KEY_F9:
			if session._wave.active:
				session._wave._process(10000)
				for enemy in session._wave.living_enemies(): enemy.take_damage(1e8)
