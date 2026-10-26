extends HBoxContainer
signal changed(key: StringName, value: Variant)
const TextButton = preload("res://scenes/settings/components/settings_button.tscn")

func configure(definition: Dictionary, value: Variant) -> void:
	# Keep translation keys so Godot updates labels in place, preserving focus
	# and each button's in-flight underline when the language changes.
	$Key.text = definition.label
	var key := StringName(definition.key)
	var choices: Array = definition.get("choices", [])
	match definition.kind:
		"dropdown", "radio":
			var group := ButtonGroup.new()
			for choice: Dictionary in choices:
				var radio := TextButton.instantiate() as Button
				radio.toggle_mode = true
				radio.text = choice.label
				radio.button_group = group
				radio.button_pressed = choice.value == value
				radio.pressed.connect(func(): changed.emit(key, choice.value))
				$Value.add_child(radio)
		"checkbox":
			var checkbox := TextButton.instantiate() as Button
			checkbox.set("checkbox", true)
			checkbox.toggle_mode = true
			checkbox.text = "ui.settings.enabled"
			checkbox.button_pressed = bool(value)
			checkbox.toggled.connect(func(enabled: bool): changed.emit(key, enabled))
			$Value.add_child(checkbox)
