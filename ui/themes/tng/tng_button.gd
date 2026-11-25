class_name TngButton
extends PanelButton
## LCARS pill button: flat colour pill, upper-case caption, optional fill bar along the bottom and a status
## marker whose shape encodes the level. Pressed state inverts to the text colour.


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := minf(r.size.y * 0.5, UiScale.dp(28.0))
	var base := TngTokens.PEACH
	if level == UiStatus.CAUTION:
		base = TngTokens.AMBER
	elif level == UiStatus.ALARM:
		base = TngTokens.SALMON
	elif level == UiStatus.OFF:
		base = TngTokens.DIM
	if disabled:
		base = base.darkened(0.55)
	if button_pressed or is_pressed():
		base = TngTokens.TEXT
	var pill := StyleBoxFlat.new()
	pill.bg_color = base
	pill.set_corner_radius_all(int(radius))
	draw_style_box(pill, r)
	if selected:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = TngTokens.TEXT
		ring.set_border_width_all(maxi(2, int(UiScale.dp(2.0))))
		ring.set_corner_radius_all(int(radius))
		draw_style_box(ring, r.grow(-UiScale.dp(1.0)))
	var font := get_theme_font("font", "Button")
	var fs := get_theme_font_size("font_size", "Button")
	var pad := radius * 0.8
	var marker_r := minf(UiScale.dp(7.0), r.size.y * 0.18)
	var show_marker := sub_caption != "" or fill >= 0.0
	var text_x := pad
	if show_marker:
		TngTokens.draw_marker(self, level, Vector2(pad, r.size.y * 0.5), marker_r, TngTokens.BLACK, base)
		text_x = pad + marker_r * 2.0 + UiScale.dp(4.0)
	var avail := maxf(0.0, r.size.x - text_x - pad * 0.6)
	# Shrink long captions down to the minimum readable size, then cut with an ellipsis.
	var min_fs := TngTokens.min_font()
	var small := maxi(min_fs, int(fs * 0.75))
	var widest := maxf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
	if widest > avail and widest > 0.0:
		fs = maxi(min_fs, int(fs * avail / widest))
		small = maxi(min_fs, int(small * avail / widest))
	var cap_text := TngTokens.fit(font, caption, fs, avail)
	var sub_text := TngTokens.fit(font, sub_caption, small, avail)
	if sub_caption == "":
		var ty := r.size.y * 0.5 + fs * 0.35
		draw_string(font, Vector2(text_x if show_marker else 0.0, ty), cap_text, HORIZONTAL_ALIGNMENT_LEFT if show_marker else HORIZONTAL_ALIGNMENT_CENTER, -1 if show_marker else r.size.x, fs, TngTokens.BLACK)
	else:
		draw_string(font, Vector2(text_x, r.size.y * 0.46), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TngTokens.BLACK)
		draw_string(font, Vector2(text_x, r.size.y * 0.46 + small + UiScale.dp(2.0)), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small, TngTokens.BLACK)
	if fill >= 0.0:
		var bar := Rect2(Vector2(pad, r.size.y - UiScale.dp(7.0)), Vector2(maxf(0.0, r.size.x - pad * 2.0), UiScale.dp(3.0)))
		draw_rect(bar, base.darkened(0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), TngTokens.BLACK)
