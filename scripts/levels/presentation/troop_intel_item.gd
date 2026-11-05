extends HBoxContainer
## Hover reveals this entrance's quota; clicking opens the field guide.
signal filter_entered(profile: Troop)
signal filter_exited(profile: Troop)
signal info_requested(profile: Troop)
var profile: Troop
var count := 0
var _motion: Tween
var _expanded := false
var _collapsed_width := 34.0
var expansion := 0.0:
	set(value):
		expansion = value
		if not is_node_ready(): return
		var label: Label = $Body/Content/Count
		label.visible = value > 0.001
		label.modulate.a = value
		$Body.custom_minimum_size.x = _collapsed_width+value*($Body/Content.get_theme_constant("separation")+label.get_combined_minimum_size().x)
@onready var body: Button = $Body

func configure(value: Troop, amount: int) -> void:
	profile = value
	count = amount
	$Body/Content/Icon.texture = value.icon
	if not value.ability_text.is_empty(): $Body/Content/Icon.modulate = Color.WHITE
	_update_text()

func _ready() -> void:
	_collapsed_width = body.custom_minimum_size.x
	body.mouse_entered.connect(func():
		if body.disabled: return
		set_expanded(true)
		filter_entered.emit(profile))
	body.mouse_exited.connect(func():
		set_expanded(false)
		filter_exited.emit(profile))
	body.pressed.connect(func(): info_requested.emit(profile))

func set_expanded(value: bool) -> void:
	if _expanded == value: return
	_expanded = value
	if _motion != null: _motion.kill()
	_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion.tween_property(self,"expansion",1.0 if value else 0.0,0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_text()

func _update_text() -> void:
	if profile == null: return
	$Body.tooltip_text = profile.localized_name()
	$Body/Content/Count.text = "×%d" % count
