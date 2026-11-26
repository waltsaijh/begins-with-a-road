extends HBoxContainer
## Text-only row over the scheduler's final entrance counts.
signal filter_entered(profile: Troop)
signal filter_exited(profile: Troop)
var profile: Troop
var count := 0
var _expanded := false
@onready var body: Button = $Body

func configure(value: Troop, amount: int) -> void:
	profile = value
	count = amount
	_update_text()

func _ready() -> void:
	body.mouse_entered.connect(func():
		if body.disabled: return
		set_expanded(true)
		filter_entered.emit(profile))
	body.mouse_exited.connect(func():
		set_expanded(false)
		filter_exited.emit(profile))

func set_expanded(value: bool) -> void:
	_expanded = value

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_text()

func _update_text() -> void:
	if profile == null: return
	$Body.text = "%s × %d" % [profile.localized_name(),count]
