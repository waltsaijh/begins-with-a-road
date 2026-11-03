extends Node
signal changed
const Calculator = preload("res://scripts/construction/geometry_bonus_calculator.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
@export var rules: Resource = preload("res://assets/data/construction/geometry_bonuses.tres")
var tower_map: Node
var effects := {}
var _queued := false

func _ready() -> void:
	tower_map = get_node("../TowerMap")
	tower_map.towers_changed.connect(refresh)
	tower_map.controller.graph_changed.connect(queue_refresh)
	tower_map.relics.changed.connect(queue_refresh)
	rules.changed.connect(queue_refresh)
	get_node("../TilePlacement").cell_placed.connect(func(_cell): queue_refresh())
	refresh()

func queue_refresh() -> void:
	if _queued: return
	_queued = true
	refresh.call_deferred()

func refresh() -> void:
	_queued = false
	if not is_inside_tree(): return
	var snapshot := Snapshot.capture(tower_map.map,tower_map.occupied)
	var next := {}
	for tower: DefenseTower in tower_map.towers.values():
		var effect := Calculator.evaluate(snapshot,tower.definition,tower.grid_cell,tower.rotation_steps,rules)
		next[tower] = effect
		if effects.get(tower,{}) != effect and not effect.messages.is_empty(): _show_notice(tower,"\n".join(effect.messages))
		tower.set_geometry_bonus(effect.range_extension,effect.damage_bonus)
	var different := effects != next
	effects = next
	if different: changed.emit()

func preview(card: BuildCard, cell: Vector3i, turns: int, drafts: Array = []) -> Dictionary:
	if card.tower == null: return {}
	var target: DefenseTower = tower_map.upgrade_target(cell)
	var proposed: Array = drafts.duplicate()
	proposed.append({"card":card,"anchor":cell,"turns":turns})
	var plan: Dictionary = tower_map.construction_plan(proposed,false)
	if not plan.ok: return {}
	var anchor := target.grid_cell if target != null else card.tower_anchor(Vector2i(cell.x,cell.z),turns)
	var rotation: int = target.rotation_steps if target != null else card.tower_facing(turns)
	var result := Calculator.evaluate(plan.snapshot,card.tower,anchor,rotation,rules)
	result.cells = Calculator.extend(tower_map.relics.preview_cells(card.tower,anchor,rotation,target.body_cells() if target != null else TowerBodyGeometry.local_cells(card.tile_preset)),anchor,rotation,result.range_extension)
	return result

## Preflight threat includes changed geometry bonuses on existing AND new towers.
func apply_proposed_influence(store: RefCounted, proposal: Dictionary) -> void:
	for tower: DefenseTower in tower_map.towers.values():
		var effect := Calculator.evaluate(proposal.snapshot,tower.definition,tower.grid_cell,tower.rotation_steps,rules)
		var base: Array[Vector2i] = tower_map.relics.preview_cells(tower.definition,tower.grid_cell,tower.rotation_steps,tower.body_cells())
		var before := Calculator.extend(base,tower.grid_cell,tower.rotation_steps,tower.geometry_range_extension)
		var after := Calculator.extend(base,tower.grid_cell,tower.rotation_steps,effect.range_extension)
		_adjust(store,before,after,tower.threat)
	for entry: Dictionary in proposal.builds:
		var base: Array[Vector2i] = tower_map.relics.preview_cells(entry.card.tower,entry.at,entry.turns,TowerBodyGeometry.local_cells(entry.card.tile_preset))
		var effect := Calculator.evaluate(proposal.snapshot,entry.card.tower,entry.at,entry.turns,rules)
		_adjust(store,base,Calculator.extend(base,entry.at,entry.turns,effect.range_extension),entry.card.tower.threat)

func _adjust(store: RefCounted, before: Array[Vector2i], after: Array[Vector2i], threat: float) -> void:
	for tile in store.all_tiles(): tile.threat += (float(tile.cell in after)-float(tile.cell in before))*threat

func _show_notice(tower: DefenseTower, message: String) -> void:
	var label := Label3D.new()
	label.text = message
	label.font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	label.font_size = 26
	label.pixel_size = 0.008
	label.position.y = 1.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b5954d")
	label.outline_modulate = Color("f2eee3")
	tower.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label,"modulate:a",0.0,0.5)
	tween.tween_callback(label.queue_free)
