class_name TmpAlertBanner
extends AlertBanner
## Film-era alert banner: a lit annunciator plate. Shapes: green = plain plate; yellow = chamfered corners with
## a diagonal stripe end; red = hazard teeth top and bottom. Blinking as the base class: green steady, yellow
## slow, red fast. The plate dims (not blanks) in the off phase so the text stays readable.


func _layout() -> Dictionary:
	var h := size.y
	var fs := maxi(TmpTokens.min_font(), int(h * 0.5))
	var font := TmpTokens.font_bold()
	var tx := h * 1.1
	return {"font": font, "fs": fs, "tx": tx, "text": TmpTokens.fit(font, text, fs, maxf(0.0, size.x - tx - h * 0.4))}


func is_truncated() -> bool:
	return _layout()["text"] != text


func _draw() -> void:
	var color := TmpTokens.lamp_color(TmpTokens.ALERT_LAMP.get(alert, "green"))
	var plate := color if phase_on else color.darkened(0.65)
	var r := Rect2(Vector2.ZERO, size)
	var h := r.size.y
	match shape():
		"teeth":
			draw_rect(Rect2(0, h * 0.18, r.size.x, h * 0.64), plate)
			var tooth := h * 0.18
			var x := 0.0
			while x < r.size.x:
				draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.18), Vector2(x + tooth, h * 0.18), Vector2(x + tooth * 0.5, 0)]), plate)
				draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.82), Vector2(x + tooth, h * 0.82), Vector2(x + tooth * 0.5, h)]), plate)
				x += tooth * 1.6
		"angled":
			var cut := h * 0.3
			draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(r.size.x - cut, 0), Vector2(r.size.x, cut), Vector2(r.size.x, h - cut), Vector2(r.size.x - cut, h), Vector2(cut, h), Vector2(0, h - cut), Vector2(0, cut)]), plate)
		_:
			draw_rect(r, plate)
	draw_rect(r.grow(-1.0), TmpTokens.BODY_DARK, false, maxf(1.5, UiScale.dp(1.5)))
	var text_color := TmpTokens.BODY_DARK if phase_on else color
	var level := UiStatus.ALARM if alert == "red" else (UiStatus.CAUTION if alert == "yellow" else UiStatus.OK)
	TmpTokens.draw_marker(self, level, Vector2(h * 0.6, h * 0.5), h * 0.2, text_color, plate)
	var l := _layout()
	var font: Font = l["font"]
	var fs: int = l["fs"]
	draw_string(font, Vector2(l["tx"], TmpTokens.baseline(font, fs, h * 0.5)), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
