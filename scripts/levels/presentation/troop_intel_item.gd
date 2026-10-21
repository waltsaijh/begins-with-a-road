extends HBoxContainer
## The optional Info action reserves a home for a future first-encounter entry.
signal filter_entered(profile: Troop)
signal filter_exited(profile: Troop)
var profile: Troop
var count := 0
@onready var body: Button = $Body

func configure(value: Troop, amount: int) -> void:
	profile = value
	count = amount
	$Body/Content/Icon.texture = value.icon
	_update_text()

func _ready() -> void:
	body.mouse_entered.connect(func(): filter_entered.emit(profile))
	body.mouse_exited.connect(func(): filter_exited.emit(profile))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_text()

func _update_text() -> void:
	if profile == null: return
	$Body/Content/Name.text = profile.localized_name()
	$Body/Content/Count.text = "×%d" % count
