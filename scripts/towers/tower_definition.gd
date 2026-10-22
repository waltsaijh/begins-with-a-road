@tool
class_name TowerDefinition
extends Resource
## Shared tower type data. Runtime stats and occupancy belong to DefenseTower.

## Stable translation ID, e.g. tower.sentry.name.
@export var name_key := "tower.generic.name":
	set(value):
		if name_key != value:
			name_key = value
			emit_changed()
@export var model: PackedScene
## Optional friendly deployment; soldiers are not navigation obstacles.
@export var deployment: BarracksDeployment
@export var growth: TowerGrowth = preload("res://assets/data/towers/growth/standard.tres")
## Base shop price when this tower is rolled into a construction card.
@export_range(0, 100, 1, "or_greater") var card_price := ShopConstants.DEFAULT_CARD_PRICE
## Transparent icon silhouette is tinted with a darker accent_color in card UI.
@export var icon: Texture2D:
	set(value):
		if icon != value:
			icon = value
			emit_changed()
@export var accent_color := Color("85cbd4"):
	set(value):
		if accent_color != value:
			accent_color = value
			emit_changed()
@export var footprint: Array[Vector2i] = TowerConstants.FOOTPRINT.duplicate():
	set(value):
		footprint = value
		emit_changed()
## Null uses the circular attack_radius; set a Resource for arbitrary tile shapes.
@export var attack_area: TowerAttackArea:
	set(value):
		if attack_area == value: return
		if is_instance_valid(attack_area) and attack_area.changed.is_connected(emit_changed):
			attack_area.changed.disconnect(emit_changed)
		attack_area = value
		if attack_area != null: attack_area.changed.connect(emit_changed)
		emit_changed()
@export_range(0.0, 10.0, 0.5, "or_greater") var attack_radius := TowerConstants.ATTACK_RADIUS
@export_range(0.0, 10.0, 0.1, "or_greater") var threat := TowerConstants.THREAT
@export_group("Combat")
@export_range(1.0, 10000.0, 1.0, "or_greater") var max_health := TowerConstants.MAX_HEALTH
@export_range(0.0, 1000.0, 1.0, "or_greater") var default_damage := TowerConstants.DEFAULT_DAMAGE
@export_range(0.05, 10.0, 0.05, "or_greater") var attack_interval := TowerConstants.ATTACK_INTERVAL
## Attack geometry and threat use the same whole-tile attack area.
@export var attack: TowerAttack
## Paths relative to the model root. AimPivot faces local -Z; the base stays fixed.
@export_node_path("Node3D") var aim_pivot_path: NodePath
@export_node_path("Marker3D") var muzzle_path: NodePath
## Fallback for models without a muzzle marker.
@export var muzzle_offset := TowerConstants.MUZZLE_OFFSET
@export_group("Tile Presets")
@export var tile_preset_candidates: Array[TilePresetCandidate] = []

func localized_name() -> String:
	return tr(name_key)

func first_tile_preset() -> TilePreset:
	for candidate in tile_preset_candidates:
		if candidate == null: continue
		var preset := candidate.resolve_preset()
		if preset != null: return preset
	return null

func roll_tile_preset(rng: RandomNumberGenerator) -> TilePreset:
	var options: Array[Dictionary] = []
	var largest := 0.0
	for candidate in tile_preset_candidates:
		if candidate == null: continue
		var preset := candidate.resolve_preset()
		if preset == null: continue
		options.append({"preset": preset, "weight": candidate.weight})
		largest = maxf(largest, candidate.weight)
	if options.is_empty(): return null
	# Normalize before summing so large finite weights cannot overflow.
	var total := 0.0
	for option in options: total += float(option.weight)/largest
	var roll := rng.randf()*total
	for option in options:
		roll -= float(option.weight)/largest
		if roll < 0.0: return option.preset
	return options[-1].preset

func configuration_error() -> String:
	if growth == null: return "缺少升級成長資料"
	if not growth.configuration_error().is_empty(): return growth.configuration_error()
	if deployment != null and not deployment.configuration_error().is_empty(): return deployment.configuration_error()
	if not is_finite(max_health) or max_health <= 0 or not is_finite(default_damage) or default_damage < 0:
		return "防禦塔血量／傷害設定無效"
	if not is_finite(attack_interval) or attack_interval <= 0 or not is_finite(attack_radius) or attack_radius < 0 or not is_finite(threat) or threat < 0:
		return "防禦塔攻擊間隔／地塊範圍／威脅設定無效"
	if attack_area != null and not attack_area.configuration_error().is_empty():
		return attack_area.configuration_error()
	return attack.configuration_error() if attack != null else ""

func cells_at(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in footprint:
		for i in posmod(turns, 4):
			offset = Vector2i(-offset.y, offset.x)
		var cell := anchor + offset
		if not cell in result:
			result.append(cell)
	return result

func attack_cells_at(anchor: Vector2i, turns := 0, radius_override := -1.0) -> Array[Vector2i]:
	if attack_area != null: return attack_area.cells_at(anchor, turns)
	return TowerAttackArea.circle_cells(anchor, attack_radius if radius_override < 0 else radius_override)

func effective_attack_cells(anchor: Vector2i, turns: int, factor := 1.0, right_only := false, radius_override := -1.0) -> Array[Vector2i]:
	if factor == 1 and not right_only: return attack_cells_at(anchor, turns, radius_override)
	var local: Array[Vector2i] = []
	if attack_area == null:
		local = TowerAttackArea.circle_cells(Vector2i.ZERO, (attack_radius if radius_override < 0 else radius_override)*factor)
	else:
		var seen := {}
		# Scale the entire effective tile footprint, filling every scaled tile.
		for offset in attack_area.offsets:
			for y in range(ceili((offset.y-0.5)*factor), ceili((offset.y+0.5)*factor)):
				for x in range(ceili((offset.x-0.5)*factor), ceili((offset.x+0.5)*factor)):
					seen[Vector2i(x,y)] = true
		local.assign(seen.keys())
	var result: Array[Vector2i] = []
	for offset in local:
		if not right_only or offset.x > 0: result.append(anchor+BuildCard.rotate_cell(offset,turns))
	return result

func patrol_attack_cells(anchor: Vector2i, turns: int, factor := 1.0, right_only := false) -> Array[Vector2i]:
	var reach := 0
	for offset in attack_cells_at(Vector2i.ZERO): reach = maxi(reach,absi(offset.x))
	var covered := {}
	for step in range(-reach,reach+1):
		for cell in effective_attack_cells(anchor+BuildCard.rotate_cell(Vector2i(step,0),turns),turns,factor,right_only): covered[cell] = true
	var result: Array[Vector2i] = []
	result.assign(covered.keys())
	return result
