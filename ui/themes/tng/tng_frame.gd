class_name TngFrame
extends FrameBox
## LCARS elbow frame: a colour bar along the top and left edges with a rounded outer corner and a rounded
## inner corner, title in the top bar. The body sits inside the black interior.


func _init() -> void:
	super._init()
	var bar := UiScale.dp(30.0)
	add_theme_constant_override("margin_top", int(bar + UiScale.dp(6.0)))
	add_theme_constant_override("margin_left", int(bar + UiScale.dp(8.0)))
	add_theme_constant_override("margin_right", int(UiScale.dp(4.0)))
	add_theme_constant_override("margin_bottom", int(UiScale.dp(4.0)))


func _draw() -> void:
	var bar := UiScale.dp(30.0)
	var color: Color = TngTokens.FRAME_COLORS[accent % TngTokens.FRAME_COLORS.size()]
	var outer := StyleBoxFlat.new()
	outer.bg_color = color
	outer.corner_radius_top_left = int(bar * 1.6)
	draw_style_box(outer, Rect2(Vector2.ZERO, Vector2(bar, size.y)))
	var top := StyleBoxFlat.new()
	top.bg_color = color
	top.corner_radius_top_left = int(bar * 1.6)
	top.corner_radius_top_right = int(bar * 0.5)
	top.corner_radius_bottom_right = int(bar * 0.5)
	draw_style_box(top, Rect2(Vector2.ZERO, Vector2(size.x, bar)))
	draw_rect(Rect2(Vector2(bar, bar), Vector2(bar, bar)), color)
	var inner := StyleBoxFlat.new()
	inner.bg_color = TngTokens.BLACK
	inner.corner_radius_top_left = int(bar * 0.8)
	draw_style_box(inner, Rect2(Vector2(bar, bar), Vector2(bar, bar)))
	var font := get_theme_font("font", "Label")
	var fs := int(bar * 0.7)
	draw_string(font, Vector2(bar * 2.2, bar * 0.5 + fs * 0.35), title, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, size.x - bar * 3.0), fs, TngTokens.BLACK)
