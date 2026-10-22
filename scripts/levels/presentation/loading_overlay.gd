extends CanvasLayer
## Reusable loading presentation; the caller owns the work and gameplay lock.

func show_progress(completed: int, total: int) -> void:
	$Cover/Status.text = tr("ui.loading.visuals") % [completed, total]

func finish() -> void:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property($Cover, "modulate:a", 0.0, 0.25)
	await tween.finished
	queue_free()

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
