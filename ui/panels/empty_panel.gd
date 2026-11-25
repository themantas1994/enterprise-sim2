extends Control
## Empty panel for the skeleton (checks C2 and C3 in docs/decisions/0001-engine.md).
## Custom drawing in _draw(): frame, grid lines, a gauge-like rect and a label. The scanline
## canvas_item shader is set as this node's material, so it post-processes everything drawn here.
## Original artwork only; no controls, so no touch targets are needed yet.

const MARGIN := 48.0
const BG := Color(0.02, 0.04, 0.05)
const LINE := Color(0.35, 0.85, 0.75)
const DIM := Color(0.12, 0.30, 0.28)
const FILL := Color(0.95, 0.65, 0.20)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, BG, true)
	var frame := area.grow(-MARGIN)
	draw_rect(frame, LINE, false, 3.0)
	# Grid of thin lines inside the frame.
	var step := 64.0
	var x := frame.position.x + step
	while x < frame.end.x:
		draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), DIM, 1.0)
		x += step
	var y := frame.position.y + step
	while y < frame.end.y:
		draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), DIM, 1.0)
		y += step
	# A filled bar and a diagonal, to exercise filled rects and anti-aliased lines.
	var bar := Rect2(frame.position + Vector2(32, 32), Vector2(frame.size.x * 0.4, 32))
	draw_rect(bar, FILL, true)
	draw_line(frame.position, frame.end, LINE, 2.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, frame.position + Vector2(32, 112), "EMPTY PANEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, LINE)
