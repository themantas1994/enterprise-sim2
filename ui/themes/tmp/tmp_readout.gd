class_name TmpReadout
extends Readout
## Film-era readout: engraved label, and the value in a small dark display window in phosphor colour with a
## level marker (shape by level).


func _layout() -> Dictionary:
	var font := get_theme_font("font", "Label")
	var bold := TmpTokens.font_bold()
	var fs := get_theme_font_size("font_size", "Label")
	var m := UiScale.dp(7.0)
	var x := m * 2.4
	var label_w := size.x * 0.45
	if compact:
		label_w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UiScale.dp(8.0)
	var value_w := maxf(0.0, size.x - x - label_w)
	if not compact:
		# Keep the value readable: the label gives way when the value needs the room.
		var need := bold.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UiScale.dp(14.0)
		if need > value_w:
			label_w = maxf(size.x * 0.25, size.x - x - need)
			value_w = maxf(0.0, size.x - x - label_w)
	var win_pad := UiScale.dp(6.0)
	return {"font": font, "bold": bold, "fs": fs, "m": m, "x": x, "label_w": label_w, "value_w": value_w, "pad": win_pad,
		"label": TmpTokens.fit(font, label, fs, label_w - UiScale.dp(4.0)),
		"value": TmpTokens.fit(bold, value_text, fs, value_w - win_pad * 2.0)}


func is_truncated() -> bool:
	var l := _layout()
	return l["label"] != label or l["value"] != value_text


func _draw() -> void:
	var l := _layout()
	var font: Font = l["font"]
	var bold: Font = l["bold"]
	var fs: int = l["fs"]
	var m: float = l["m"]
	var x: float = l["x"]
	var label_w: float = l["label_w"]
	var value_w: float = l["value_w"]
	var color := TmpTokens.level_color(level)
	TmpTokens.draw_marker(self, level, Vector2(m, size.y * 0.5), m * 0.8, color, TmpTokens.BODY_DARK)
	draw_string(font, Vector2(x, TmpTokens.baseline(font, fs, size.y * 0.5)), l["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TmpTokens.ETCH)
	var win := Rect2(Vector2(x + label_w, size.y * 0.08), Vector2(maxf(0.0, value_w), size.y * 0.84))
	draw_rect(win, TmpTokens.SCREEN)
	draw_rect(win, TmpTokens.BODY_LIGHT, false, maxf(1.0, UiScale.dp(1.0)))
	var shown: String = l["value"]
	var tw := bold.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var vx := win.position.x + (win.size.x - tw - float(l["pad"]) if not compact else float(l["pad"]))
	draw_string(bold, Vector2(vx, TmpTokens.baseline(bold, fs, win.get_center().y)), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
