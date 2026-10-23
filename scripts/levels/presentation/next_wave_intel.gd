extends VBoxContainer
signal filter_changed(profile: Troop)
signal info_requested(profile: Troop)
const Item = preload("res://scenes/levels/components/troop_intel_item.tscn")
var counts := {}
var selected: Troop
var _configured := false

func display(value: Dictionary) -> void:
	if _configured and counts == value: return
	_configured = true
	counts = value.duplicate()
	clear_filter()
	var height := maxi(1,mini(3, counts.size()))*38.0
	$Scroll.custom_minimum_size.y = height
	offset_bottom = offset_top+height
	get_parent().set_intel_height(height)
	for child in $Scroll/Items.get_children():
		$Scroll/Items.remove_child(child)
		child.queue_free()
	var profiles := counts.keys()
	if profiles.is_empty():
		var empty := Label.new()
		empty.text = "×0"
		empty.custom_minimum_size.y = 36
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
		item.info_requested.connect(func(profile: Troop): info_requested.emit(profile))
		item.body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.body.pressed.connect(func():
			var action := get_parent() as Button
			if action.is_visible_in_tree() and not action.disabled:
				action.pressed.emit())

func _enter_filter(profile: Troop) -> void:
	selected = profile
	filter_changed.emit(selected)

func _exit_filter(profile: Troop) -> void:
	if selected == profile: clear_filter()

func clear_filter() -> void:
	selected = null
	filter_changed.emit(null)
