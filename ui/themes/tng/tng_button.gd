class_name TngButton
extends PanelButton
## LCARS pill button: flat colour pill, upper-case caption, optional fill bar along the bottom and a status
## marker whose shape encodes the level. Pressed state inverts to the text colour.


const MAX_GROW_DP := 300.0


func _metrics(h: float) -> Dictionary:
	var radius := minf(h * 0.5, UiScale.dp(28.0))
	var pad := radius * 0.8
	var marker := sub_caption != "" or fill >= 0.0
	var text_x := pad + (minf(UiScale.dp(7.0), h * 0.18) * 2.0 + UiScale.dp(4.0) if marker else 0.0)
	return {"radius": radius, "pad": pad, "marker": marker, "text_x": text_x}


## Font sizes and (possibly cut) texts for the current size: shrink down to the minimum, then ellipsis.
func _fit_info(font: Font) -> Dictionary:
	var m := _metrics(size.y)
	var fs := int(UiScale.dp(18.0))
	var avail := maxf(0.0, size.x - float(m["text_x"]) - float(m["pad"]) * 0.6)
	var min_fs := TngTokens.min_font()
	var small := maxi(min_fs, int(fs * 0.75))
	var widest := maxf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
	if widest > avail and widest > 0.0:
		fs = maxi(min_fs, int(fs * avail / widest * 0.96))
		small = maxi(min_fs, int(small * avail / widest * 0.96))
	return {"fs": fs, "small": small, "pad": m["pad"], "text_x": m["text_x"], "marker": m["marker"],
		"cap": TngTokens.fit(font, caption, fs, avail), "sub": TngTokens.fit(font, sub_caption, small, avail)}


func is_truncated() -> bool:
	var info := _fit_info(TngTokens.font())
	return info["cap"] != caption or info["sub"] != sub_caption


func drawn_font_sizes() -> Array:
	var info := _fit_info(TngTokens.font())
	return [info["fs"], info["small"]] if sub_caption != "" else [info["fs"]]


## Widens the button so that its texts fit at the minimum font size (never narrower than it was).
func _grow_to_fit() -> void:
	var font := TngTokens.font()
	var h := maxf(custom_minimum_size.y, UiScale.touch_min())
	var m := _metrics(h)
	var min_fs := TngTokens.min_font()
	var small := maxi(min_fs, int(int(UiScale.dp(18.0)) * 0.75))
	var need := maxf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, min_fs).x, font.get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, min_fs).x)
	need = need + float(m["text_x"]) + float(m["pad"]) * 0.6 + UiScale.dp(4.0)
	custom_minimum_size.x = maxf(custom_minimum_size.x, minf(need, UiScale.dp(MAX_GROW_DP)))


func set_caption(main: String, sub: String = "") -> void:
	super.set_caption(main, sub)
	_grow_to_fit()


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
	var font := TngTokens.font()
	var info := _fit_info(font)
	var fs: int = info["fs"]
	var small: int = info["small"]
	var pad: float = info["pad"]
	var text_x: float = info["text_x"]
	var show_marker: bool = info["marker"]
	var cap_text: String = info["cap"]
	var sub_text: String = info["sub"]
	if show_marker:
		TngTokens.draw_marker(self, level, Vector2(pad, r.size.y * 0.5), minf(UiScale.dp(7.0), r.size.y * 0.18), TngTokens.BLACK, base)
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
