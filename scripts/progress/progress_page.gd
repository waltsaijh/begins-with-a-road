extends "res://scripts/settings/settings_page.gd"
## Read-only sibling of the settings page: same shell, entries instead of options.
const Entry = preload("res://scenes/progress/components/progress_entry.tscn")

func _show_rows() -> void:
	_clear(rows)
	if sections.is_empty(): return
	for definition: Dictionary in sections[selected_section].entries:
		var row := Entry.instantiate()
		rows.add_child(row)
		row.configure(definition)

## Opens straight on one entry, for example from a next-wave troop icon.
func show_entry(id: String) -> void:
	for section in sections.size():
		for index in sections[section].entries.size():
			if sections[section].entries[index].id != id: continue
			selected_section = section
			_rebuild()
			await get_tree().process_frame
			if is_instance_valid(rows) and index < rows.get_child_count():
				scroll.ensure_control_visible(rows.get_child(index))
			return
