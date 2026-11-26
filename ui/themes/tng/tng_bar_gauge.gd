class_name TngBarGauge
extends BarGauge
## LCARS horizontal bar: label left, flat bar with square end blocks in the middle, number right.


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label")
	var color := TngTokens.level_color(level)
	var label_w := minf(size.x * 0.34, UiScale.dp(150.0))
	var value_w := minf(size.x * 0.24, UiScale.dp(90.0))
	var ty := size.y * 0.5 + fs * 0.35
	draw_string(font, Vector2(0, ty), TngTokens.fit(font, label, fs, label_w), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TngTokens.TEXT)
	var bar := Rect2(Vector2(label_w + UiScale.dp(6.0), size.y * 0.18), Vector2(maxf(4.0, size.x - label_w - value_w - UiScale.dp(14.0)), size.y * 0.64))
	draw_rect(bar, TngTokens.DIM.darkened(0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction(), bar.size.y)), color)
	TngTokens.draw_marker(self, level, Vector2(bar.end.x - bar.size.y * 0.5, bar.get_center().y), bar.size.y * 0.28, TngTokens.BLACK, color)
	draw_string(font, Vector2(size.x - value_w, ty), TngTokens.fit(font, value_text, fs, value_w), HORIZONTAL_ALIGNMENT_RIGHT, value_w, fs, TngTokens.TEXT)
