extends Node
## Exercise the generic preparation contract without gameplay dependencies.
func fail_loading(report: Callable) -> int:
	report.call(0, 2, &"ui.loading.navigation")
	await get_tree().process_frame
	return ERR_INVALID_DATA

func cancel_loading(_report: Callable) -> int:
	queue_free()
	await get_tree().process_frame
	return ERR_UNAVAILABLE
