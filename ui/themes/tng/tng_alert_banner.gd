class_name TngAlertBanner
extends AlertBanner
## LCARS alert banner. Shapes: green = pill with round ends; yellow = angled ends and a chevron strip;
## red = square ends with hazard teeth top and bottom. Blinking: green steady, yellow slow, red fast.


func _draw() -> void:
	var color: Color = TngTokens.ALERT_COLOR.get(alert, TngTokens.GREEN)
	var fill_color := color if phase_on else color.darkened(0.7)
	var r := Rect2(Vector2.ZERO, size)
	var h := r.size.y
	match shape():
		"teeth":
			draw_rect(Rect2(0, h * 0.18, r.size.x, h * 0.64), fill_color)
			var tooth := h * 0.18
			var x := 0.0
			while x < r.size.x:
				draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.18), Vector2(x + tooth, h * 0.18), Vector2(x + tooth * 0.5, 0)]), fill_color)
				draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.82), Vector2(x + tooth, h * 0.82), Vector2(x + tooth * 0.5, h)]), fill_color)
				x += tooth * 1.6
		"angled":
			var cut := h * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(r.size.x - cut, 0), Vector2(r.size.x, h * 0.5), Vector2(r.size.x - cut, h), Vector2(cut, h), Vector2(0, h * 0.5)]), fill_color)
		_:
			var pill := StyleBoxFlat.new()
			pill.bg_color = fill_color
			pill.set_corner_radius_all(int(h * 0.5))
			draw_style_box(pill, r)
	var font := get_theme_font("font", "Label")
	var fs := int(h * 0.55)
	var tx := h * 0.9
	var text_color := TngTokens.BLACK if phase_on else color
	if alert == "red":
		TngTokens.draw_marker(self, UiStatus.ALARM, Vector2(h * 0.55, h * 0.5), h * 0.2, TngTokens.BLACK, fill_color)
	elif alert == "yellow":
		TngTokens.draw_marker(self, UiStatus.CAUTION, Vector2(h * 0.75, h * 0.5), h * 0.2, TngTokens.BLACK, fill_color)
	else:
		TngTokens.draw_marker(self, UiStatus.OK, Vector2(h * 0.55, h * 0.5), h * 0.16, TngTokens.BLACK, fill_color)
	draw_string(font, Vector2(tx + (h * 0.3 if alert == "yellow" else 0.0), h * 0.5 + fs * 0.35), TngTokens.fit(font, text, fs, maxf(0.0, r.size.x - tx * 1.4)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
