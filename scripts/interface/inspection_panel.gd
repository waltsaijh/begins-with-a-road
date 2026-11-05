extends Control
## Shared input boundary for HUD detail pages. The HUD owns pause/navigation.
signal close_requested

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			var controls: Array[Control] = []
			for node in find_children("*","Control",true,false):
				if node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not (node is BaseButton and node.disabled): controls.append(node)
			if not controls.is_empty():
				var index := controls.find(get_viewport().gui_get_focus_owner())
				controls[posmod(index+(-1 if event.is_action_pressed("ui_focus_prev") else 1),controls.size())].grab_focus()
			get_viewport().set_input_as_handled()
		elif not (event.is_action("ui_accept") or event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right")):
			get_viewport().set_input_as_handled()
		else:
			var focus := get_viewport().gui_get_focus_owner()
			if focus == null or not is_ancestor_of(focus):
				get_viewport().set_input_as_handled()
			else:
				for action in {"ui_left":SIDE_LEFT,"ui_up":SIDE_TOP,"ui_right":SIDE_RIGHT,"ui_down":SIDE_BOTTOM}:
					if event.is_action_pressed(action):
						var target := focus.find_valid_focus_neighbor({"ui_left":SIDE_LEFT,"ui_up":SIDE_TOP,"ui_right":SIDE_RIGHT,"ui_down":SIDE_BOTTOM}[action])
						if target == null or not is_ancestor_of(target): get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if is_visible_in_tree(): get_viewport().set_input_as_handled()
