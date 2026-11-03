extends Node
## A read-only future wave, recalculated only on the placement controller's changes.
const Schedule = preload("res://scripts/construction/construction_schedule.gd")
var status: Label
var rebuild_count := 0
var pending: Array = []
@onready var cards: Node = get_node("../CardPlacement")
@onready var towers: Node = get_node("../TowerMap")
@onready var flow: Node = get_node("../WaveFlowPreview")
@onready var wave: Node = get_node("../EnemyWave")

func _ready() -> void:
	cards.preview.detailed_geometry = true
	cards.build_preview_changed.connect(update)
	cards.preview.visibility_changed.connect(func(): if not cards.preview.visible: clear())

func clear() -> void:
	pending = []
	flow.set_construction_pending(null)
	cards.preview.prospective_ports = {}
	if is_instance_valid(status): status.text = "即時放置 · 準備期可編輯／補牌。金色新增道路；青色塔體；橙紅格會阻擋既有道路。"

func update(card: BuildCard, cell: Vector3i, turns: int, error: String) -> void:
	if not cards.preview.visible or card.traffic != null or cards.preview.upgrade_mode: clear(); return
	if not error.is_empty():
		flow.set_construction_pending([]); cards.preview.prospective_ports = {}; pending = []
		cards.preview.show_at(towers.map,card,cell,turns,false)
		status.text = error
		return
	var proposal: Dictionary = towers.construction_plan([{"card":card,"anchor":cell,"turns":turns}])
	var schedule := Schedule.build(towers,proposal,wave)
	rebuild_count += 1
	pending = schedule.pending
	flow.set_construction_pending(pending)
	cards.preview.prospective_ports = proposal.layout.masks if proposal.ok else {}
	cards.preview.show_at(towers.map,card,cell,turns,schedule.ok)
	status.text = "放置後路線預測（未提交）· %d 名敵人；完整塔體均不可通行。" % pending.size() if schedule.ok else schedule.error
