class_name TmpSchematic
extends SchematicView
## Film-era schematic: the base layout drawn as CRT line art. A faint graticule is drawn behind the nodes
## and a rule with end ticks marks each group, in phosphor green (default) or blue. The scanline overlay is added by the
## panel (TmpCrt), not here. Original line art only.

var trace := "green":
	set(value):
		trace = value
		queue_redraw()


func _init() -> void:
	sort_children.connect(queue_redraw)


func trace_color() -> Color:
	return TmpTokens.PHOSPHOR_BLUE if trace == "blue" else TmpTokens.PHOSPHOR_GREEN


func _draw() -> void:
	var color := trace_color()
	var w := maxf(1.5, UiScale.dp(1.5))
	# Faint graticule behind everything.
	var grid := color
	grid.a = 0.12
	var step := UiScale.dp(24.0)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
		x += step
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
		y += step
	# A rule with end ticks above every group (in the gap above the group's nodes) and a dot on it.
	var tick := UiScale.dp(5.0)
	for row: Control in _group_rows:
		if not is_instance_valid(row):
			continue
		var ry := row.position.y - UiScale.dp(4.0)
		draw_line(Vector2(0, ry), Vector2(size.x, ry), color, w)
		draw_line(Vector2(0, ry), Vector2(0, ry + tick), color, w)
		draw_line(Vector2(size.x - 1.0, ry), Vector2(size.x - 1.0, ry + tick), color, w)
		draw_circle(Vector2(size.x * 0.5, ry), w * 2.0, color)
