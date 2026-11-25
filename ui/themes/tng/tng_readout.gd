class_name TngReadout
extends Readout
## LCARS readout: small pastel label, large value, level marker.


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label")
	var color := TngTokens.level_color(level)
	var m := UiScale.dp(7.0)
	TngTokens.draw_marker(self, level, Vector2(m, size.y * 0.5), m * 0.8, color)
	var x := m * 2.4
	var ty := size.y * 0.5 + fs * 0.35
	var label_w := size.x * 0.45
	if compact:
		label_w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UiScale.dp(8.0)
	draw_string(font, Vector2(x, ty), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, fs, TngTokens.PEACH)
	draw_string(font, Vector2(x + label_w, ty), value_text, HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT, maxf(0.0, size.x - x - label_w), fs, TngTokens.TEXT)
