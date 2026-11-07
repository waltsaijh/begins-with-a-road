extends Control
## Counts completed work, without estimating time or compiler completion.
## Compact is the intro's bottom strip: small label, wide hairline bar, nothing else.
var compact := false:
	set(value):
		compact = value
		$Column/Title.visible = not value
		$Column/Count.visible = false
		$Column/Stage.add_theme_font_size_override("font_size", 12 if value else 16)
		$Column/Progress.custom_minimum_size.y = 1 if value else 2
		$Column.offset_left = -360 if value else -180
		$Column.offset_right = 360 if value else 180
		$Column.offset_top = 150 if value else -60
		$Column.offset_bottom = 210 if value else 60

func report(completed: int, total: int, stage: StringName) -> void:
	$Column/Stage.text = stage
	$Column/Progress.visible = total > 0
	$Column/Count.visible = total > 0 and not compact
	if total > 0:
		$Column/Progress.max_value = total
		$Column/Progress.value = clampi(completed, 0, total)
		$Column/Count.text = "%d / %d" % [clampi(completed, 0, total), total]
