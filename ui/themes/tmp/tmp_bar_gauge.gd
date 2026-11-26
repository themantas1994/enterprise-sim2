class_name TmpBarGauge
extends BarGauge
## Film-era gauge: engraved label, a row of lit segments (colour and marker shape by level), value on the right.


func _layout() -> Dictionary:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label")
	var label_w := minf(size.x * 0.34, UiScale.dp(150.0))
	var value_w := minf(size.x * 0.24, UiScale.dp(90.0))
	return {"font": font, "fs": fs, "label_w": label_w, "value_w": value_w,
		"label": TmpTokens.fit(font, label, fs, label_w), "value": TmpTokens.fit(font, value_text, fs, value_w)}


func drawn_font_sizes() -> Array:
	return [_layout()["fs"]]


func is_truncated() -> bool:
	var l := _layout()
	return l["label"] != label or l["value"] != value_text


func _draw() -> void:
	var l := _layout()
	var font: Font = l["font"]
	var fs: int = l["fs"]
	var label_w: float = l["label_w"]
	var value_w: float = l["value_w"]
	var color := TmpTokens.level_color(level)
	var ty := TmpTokens.baseline(font, fs, size.y * 0.5)
	draw_string(font, Vector2(0, ty), l["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TmpTokens.ETCH)
	var marker_w := size.y * 0.5
	var bar := Rect2(Vector2(label_w + UiScale.dp(6.0), size.y * 0.2), Vector2(maxf(8.0, size.x - label_w - value_w - marker_w - UiScale.dp(18.0)), size.y * 0.6))
	draw_rect(bar.grow(UiScale.dp(2.0)), TmpTokens.BODY_DARK)
	var count := maxi(4, int(bar.size.x / UiScale.dp(9.0)))
	var seg_gap := maxf(1.0, UiScale.dp(1.5))
	var seg_w := bar.size.x / count - seg_gap
	var lit_count := int(round(fraction() * count))
	for i in count:
		var seg := Rect2(Vector2(bar.position.x + i * (seg_w + seg_gap), bar.position.y), Vector2(seg_w, bar.size.y))
		draw_rect(seg, color if i < lit_count else color.darkened(0.8))
	TmpTokens.draw_marker(self, level, Vector2(bar.end.x + UiScale.dp(8.0) + marker_w * 0.25, size.y * 0.5), size.y * 0.2, color, TmpTokens.BODY_DARK)
	draw_string(font, Vector2(size.x - value_w, ty), l["value"], HORIZONTAL_ALIGNMENT_RIGHT, value_w, fs, TmpTokens.TEXT)
