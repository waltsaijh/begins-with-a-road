extends "res://scripts/settings/settings_page.gd"
## Read-only sibling of the settings page: sections, then entries, then one entry in detail.
const Entry = preload("res://scenes/progress/components/progress_entry.tscn")
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")
@onready var column: VBoxContainer = $Panel/Margin/Layout/Body/Detail/Column
@onready var preview: SubViewportContainer = $Panel/Margin/Layout/Body/Detail/Column/Frame/Preview

func _show_rows() -> void:
	_clear(rows)
	_show_detail({})
	if sections.is_empty(): return
	for definition: Dictionary in sections[selected_section].entries:
		var row := Entry.instantiate()
		rows.add_child(row)
		row.configure(definition)
		row.chosen.connect(_choose.bind(row, definition))

func _choose(chosen_row: Control, definition: Dictionary) -> void:
	for row in rows.get_children(): row.set_selected(row == chosen_row)
	_show_detail(definition)

func _show_detail(definition: Dictionary) -> void:
	var empty := definition.is_empty()
	column.get_node("Hint").visible = empty
	for part in ["Frame", "Name", "Usage", "Stats", "Traits", "Description"]: column.get_node(part).hide()
	preview.display_node(null)
	if empty: return
	_show_art(definition)
	_show_text("Name", definition.name)
	_show_text("Usage", definition.get("usage", ""))
	if definition.has("usage"): column.get_node("Usage").add_theme_color_override("font_color", definition.usage_color)
	_show_text("Stats", "  ·  ".join(definition.stats))
	_show_text("Traits", "  ·  ".join(definition.traits))
	_show_text("Description", definition.get("detail", definition.description))
	$Panel/Margin/Layout/Body/Detail.scroll_vertical = 0

func _show_text(part: String, text: String) -> void:
	var label: Label = column.get_node(part)
	label.text = text
	label.visible = not text.is_empty()

## Enemies and towers turn as models; relics and locked entries have no model.
func _show_art(definition: Dictionary) -> void:
	var icon: TextureRect = column.get_node("Frame/Icon")
	var has_model: bool = definition.has("troop") or definition.has("tower")
	column.get_node("Frame").show()
	preview.visible = has_model
	icon.visible = not has_model and definition.icon != null
	column.get_node("Frame/Unknown").visible = not has_model and definition.icon == null
	if definition.has("troop"): preview.display(definition.troop)
	elif definition.has("tower"): preview.display_node(ProgressCatalog.tower_model(definition.tower))
	if not icon.visible: return
	icon.texture = definition.icon
	icon.material = null
	icon.self_modulate = Color.WHITE
	if definition.has("tint"):
		var mask := ShaderMaterial.new()
		mask.shader = IconMask
		icon.material = mask
		icon.self_modulate = definition.tint

## Opens straight on one entry, with its detail shown.
func focus_entry(id: String) -> void:
	for section in sections.size():
		for index in sections[section].entries.size():
			if sections[section].entries[index].id != id: continue
			selected_section = section
			_rebuild()
			var row: Control = rows.get_child(index)
			row.chosen.emit()
			row.grab_focus()
			return
