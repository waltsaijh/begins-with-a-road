extends Control
## Counts completed work, without estimating time or compiler completion.
func report(completed: int, total: int, stage: StringName) -> void:
	$Column/Stage.text = stage
	$Column/Progress.visible = total > 0
	$Column/Count.visible = total > 0
	if total > 0:
		$Column/Progress.max_value = total
		$Column/Progress.value = clampi(completed, 0, total)
		$Column/Count.text = "%d / %d" % [clampi(completed, 0, total), total]
