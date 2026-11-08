extends VBoxContainer
signal filter_changed(profile: Troop)
const Item = preload("res://scenes/levels/components/troop_intel_item.tscn")
var counts := {}
var selected: Troop
var _configured := false

func _ready() -> void:
	$Scroll/Items.minimum_size_changed.connect(_update_layout)

func display(value: Dictionary) -> void:
	if _configured and counts == value: return
	_configured = true
	counts = value.duplicate()
	clear_filter()
	for child in $Scroll/Items.get_children():
		$Scroll/Items.remove_child(child)
		child.queue_free()
	var profiles := counts.keys()
	if profiles.is_empty():
		var empty := Label.new()
		empty.text = "×0"
		empty.custom_minimum_size = Vector2(34,34)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_color_override("font_color",Color(0.15,0.30,0.32))
		$Scroll/Items.add_child(empty)
	profiles.sort_custom(func(a: Troop, b: Troop): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.localized_name() < b.localized_name())
	for profile: Troop in profiles:
		var item := Item.instantiate()
		$Scroll/Items.add_child(item)
		item.configure(profile, counts[profile])
		item.filter_entered.connect(_enter_filter)
		item.filter_exited.connect(_exit_filter)
	_update_layout()

func _update_layout() -> void:
	var width: float = $Scroll/Items.get_combined_minimum_size().x
	var height := maxf(34,$Scroll/Items.get_combined_minimum_size().y)
	if width > 480: height += $Scroll.get_h_scroll_bar().get_combined_minimum_size().y
	$Scroll.custom_minimum_size.y = height
	get_parent().set_intel_size(Vector2(minf(width,480),height))

func set_interactive(enabled: bool) -> void:
	for item in $Scroll/Items.get_children():
		if item.has_method("set_expanded"):
			item.body.disabled = not enabled
			if not enabled: item.set_expanded(false)

func _enter_filter(profile: Troop) -> void:
	selected = profile
	filter_changed.emit(selected)

func _exit_filter(profile: Troop) -> void:
	if selected == profile: clear_filter()

func clear_filter() -> void:
	selected = null
	for item in $Scroll/Items.get_children():
		if item.has_method("set_expanded"): item.set_expanded(false)
	filter_changed.emit(null)
