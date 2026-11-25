class_name TngSchematic
extends SchematicView
## LCARS schematic: the base layout plus a thin bus line down the left of every group, joined to each row.


func _draw() -> void:
	for row: Control in _group_rows:
		if not is_instance_valid(row):
			continue
		var y0 := row.position.y
		draw_line(Vector2(UiScale.dp(2.0), y0), Vector2(UiScale.dp(2.0), y0 + row.size.y), TngTokens.LAVENDER, maxf(2.0, UiScale.dp(2.0)))
