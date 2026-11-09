extends CanvasLayer
## Three attached horizontal sticky notes shared by the hand and shop.
const Info = preload("res://scripts/cards/presentation/card_combat_info.gd")
@export var note_width := 260.0
@export var reveal_seconds := 0.18
@onready var placement: Node = get_parent()
@onready var root: Control = $Root
@onready var strips: Array[Control] = [$Root/Damage,$Root/Speed,$Root/Description]
var target: Control
var _signature: Array = []
var _reveal := 0.0
var _last_usec := 0
var _inside := true
var _focused := true
var _anchor := Vector2.ZERO
var opens_left := false

func _ready() -> void:
	root.hide()
	_last_usec = Time.get_ticks_usec()
	get_viewport().mouse_exited.connect(func(): _inside = false; clear())
	get_viewport().mouse_entered.connect(func(): _inside = true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		if is_node_ready(): clear()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: _focused = true

func clear() -> void:
	target = null
	_reveal = 0.0
	if is_node_ready(): root.hide()

func hovered_card() -> Control:
	if ScreenTransition.active or not _inside or not _focused or get_tree().paused or placement.pause_locked or placement.entry_selection_active or placement._wave_active or placement._wave_start_pending: return null
	var hand: CanvasLayer = placement.hand
	if hand.is_dragging(): return null
	var shop: CanvasLayer = placement.get_node("Shop/View")
	if shop.opened:
		if not shop.available or shop._animating or shop._hovered <= 0 or shop._hovered >= shop.slots.size(): return null
		if not shop._in_stock(shop._hovered): return null
		return shop.slots[shop._hovered].get_node("Face/Card")
	if placement.input_suspended or hand.collapsed or hand.stowed or not hand._interaction_enabled: return null
	if hand._hovered < 0 or hand._hovered >= hand.views.size(): return null
	return hand.views[hand._hovered]

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := minf(0.1,float(now-_last_usec)/1000000.0)
	_last_usec = now
	var next := hovered_card()
	if next != null and (not next.is_visible_in_tree() or next.card == null or next.card.tower == null): next = null
	if next != target:
		target = next
		_reveal = 0.0
	if target == null:
		root.hide()
		return
	var definition: TowerDefinition = target.card.tower
	var deployment := definition.deployment
	var signature := [definition,definition.default_damage,definition.attack_interval,definition.attack,definition.attack.damage_multiplier if definition.attack != null else 1.0,definition.name_key,definition.attack_area,deployment,deployment.damage if deployment != null else 0.0,deployment.interval if deployment != null else 0.0,TranslationServer.get_locale()]
	if signature != _signature:
		_signature = signature
		var info := Info.data(definition)
		$Root/Damage/Paper/Margin/Text.text = info.stats
		$Root/Speed/Paper/Margin/Text.text = info.speed
		$Root/Description/Paper/Margin/Text.text = info.description
	opens_left = _rightmost_shop_card(target)
	var height := 0.0
	for i in strips.size():
		var paper: PanelContainer = strips[i].get_node("Paper")
		var width: float = note_width if i == 2 else (152.0 if i == 0 else 170.0)
		_fit_text(paper.get_node("Margin/Text"),width-26.0,14 if i == 2 else 15)
		paper.custom_minimum_size.x = width
		paper.size = Vector2(width,0)
		paper.size.y = paper.get_combined_minimum_size().y
		strips[i].position = Vector2(0,height)
		height += paper.size.y+6.0
	root.size = Vector2(note_width,height-6.0)
	var visuals: Control = target.get_node("Visuals")
	var transform := visuals.get_global_transform_with_canvas()
	# Five pixels overlap the card so the notes remain physically attached.
	_anchor = transform*Vector2(5 if opens_left else visuals.size.x-5,14)
	root.rotation = transform.get_rotation()
	root.position = _anchor
	# The rightmost available shop card opens to its left, keeping its face clear.
	var viewport := get_viewport().get_visible_rect().size
	var bounds := note_bounds()
	var shift := Vector2.ZERO
	if bounds.end.x > viewport.x-12: shift.x = viewport.x-12-bounds.end.x
	if bounds.position.x+shift.x < 12: shift.x += 12-bounds.position.x-shift.x
	if bounds.end.y > viewport.y-12: shift.y = viewport.y-12-bounds.end.y
	if bounds.position.y+shift.y < 12: shift.y += 12-bounds.position.y-shift.y
	root.position += shift
	_reveal = minf(1.0,_reveal+elapsed/maxf(0.01,reveal_seconds))
	for i in strips.size():
		var paper: PanelContainer = strips[i].get_node("Paper")
		var phase := clampf((_reveal-float(i)*0.10)/0.80,0.0,1.0)
		var eased := 1.0-pow(1.0-phase,3)
		strips[i].size = Vector2(paper.size.x*eased,paper.size.y)
		strips[i].position.x = -strips[i].size.x if opens_left else 0.0
		paper.position.x = strips[i].size.x-paper.size.x if opens_left else 0.0
		strips[i].modulate.a = eased
	root.show()

func _rightmost_shop_card(view: Control) -> bool:
	var shop: CanvasLayer = placement.get_node("Shop/View")
	if not shop.opened: return false
	var rightmost: Control
	var right_edge := -INF
	for i in range(1,shop.slots.size()):
		if not shop._in_stock(i): continue
		var face: Control = shop.slots[i].get_node("Face/Card")
		if not face.is_visible_in_tree(): continue
		var x := card_bounds(face).get_center().x
		if x > right_edge:
			right_edge = x
			rightmost = face
	return view == rightmost

func _fit_text(label: Label, width: float, base_size: int) -> void:
	var font := label.get_theme_font("font")
	var fitted := base_size
	# Semantic line breaks do most of the work. Shrink only a long unbroken row.
	while fitted > 12:
		var fits := true
		for line in label.text.split("\n"):
			if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x > width:
				fits = false
				break
		if fits: break
		fitted -= 1
	if label.get_theme_font_size("font_size") != fitted: label.add_theme_font_size_override("font_size",fitted)

func note_bounds() -> Rect2:
	var left := -root.size.x if opens_left else 0.0
	var rect := Rect2(root.get_transform()*Vector2(left,0),Vector2.ZERO)
	for corner in [Vector2(left+root.size.x,0),Vector2(left+root.size.x,root.size.y),Vector2(left,root.size.y)]: rect = rect.expand(root.get_transform()*corner)
	return rect

func card_bounds(view: Control) -> Rect2:
	var visuals: Control = view.get_node("Visuals")
	var transform := visuals.get_global_transform_with_canvas()
	var rect := Rect2(transform*Vector2.ZERO,Vector2.ZERO)
	for corner in [Vector2(visuals.size.x,0),visuals.size,Vector2(0,visuals.size.y)]: rect = rect.expand(transform*corner)
	return rect
