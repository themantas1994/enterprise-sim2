class_name TmpButton
extends PanelButton
## Film-era push-button: a rectangular hardware body with a bevel and a backlit legend window. The window glows
## in the lamp colour when the button is pressed or selected; otherwise it is dim. Pressed also sinks the bevel.
## `lamp` forces a legend colour (red, amber, blue, green, white); empty means: derive it from the level.
## A status marker (shape by level) is drawn when a sub-caption or fill is shown, so colour is never the only cue.

const MAX_GROW_DP := 300.0

var lamp := "":
	set(value):
		lamp = value
		queue_redraw()


func lamp_name() -> String:
	return lamp if TmpTokens.LAMP.has(lamp) else TmpTokens.level_lamp(level)


func _metrics(h: float) -> Dictionary:
	var bevel := maxf(2.0, UiScale.dp(2.0))
	var pad := minf(h * 0.3, UiScale.dp(12.0))
	var marker := sub_caption != "" or fill >= 0.0
	var text_x := pad + bevel * 2.0 + (minf(UiScale.dp(7.0), h * 0.18) * 2.0 + UiScale.dp(4.0) if marker else 0.0)
	return {"bevel": bevel, "pad": pad, "marker": marker, "text_x": text_x}


## Font sizes and (possibly cut) texts for the current size: shrink down to the minimum, then ellipsis.
func _fit_info() -> Dictionary:
	var bold := TmpTokens.font_bold()
	var reg := TmpTokens.font()
	var m := _metrics(size.y)
	var fs := int(UiScale.dp(16.0))
	var avail := maxf(0.0, size.x - float(m["text_x"]) - float(m["pad"]) - float(m["bevel"]) * 2.0)
	var min_fs := TmpTokens.min_font()
	var small := maxi(min_fs, int(fs * 0.8))
	var widest := maxf(bold.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, reg.get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
	if widest > avail and widest > 0.0:
		fs = maxi(min_fs, int(fs * avail / widest * 0.96))
		small = maxi(min_fs, int(small * avail / widest * 0.96))
	return {"fs": fs, "small": small, "text_x": m["text_x"], "marker": m["marker"], "bevel": m["bevel"], "avail": avail,
		"cap": TmpTokens.fit(bold, caption, fs, avail), "sub": TmpTokens.fit(reg, sub_caption, small, avail)}


func is_truncated() -> bool:
	var info := _fit_info()
	return info["cap"] != caption or info["sub"] != sub_caption


func drawn_font_sizes() -> Array:
	var info := _fit_info()
	return [info["fs"], info["small"]] if sub_caption != "" else [info["fs"]]


## Widens the button so that its texts fit at the minimum font size (never narrower than it was).
func _grow_to_fit() -> void:
	var h := maxf(custom_minimum_size.y, UiScale.touch_min())
	var m := _metrics(h)
	var min_fs := TmpTokens.min_font()
	var need := maxf(TmpTokens.font_bold().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, min_fs).x, TmpTokens.font().get_string_size(sub_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, min_fs).x)
	need = need + float(m["text_x"]) + float(m["pad"]) + float(m["bevel"]) * 2.0 + UiScale.dp(4.0)
	custom_minimum_size.x = maxf(custom_minimum_size.x, minf(need, UiScale.dp(MAX_GROW_DP)))


func set_caption(main: String, sub: String = "") -> void:
	super.set_caption(main, sub)
	_grow_to_fit()


func set_fill(value: float) -> void:
	super.set_fill(value)
	_grow_to_fit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var down := button_pressed or is_pressed()
	var lit := (down or selected) and not disabled
	var info := _fit_info()
	var bevel: float = info["bevel"]
	var lamp_color := TmpTokens.lamp_color(lamp_name())
	var body := TmpTokens.BODY.lightened(0.06) if is_hovered() and not disabled else TmpTokens.BODY
	draw_rect(r, body)
	TmpTokens.draw_bevel(self, r, bevel, down)
	var win := r.grow(-bevel * 2.0)
	if down:
		win.position += Vector2(1.0, 1.0) * bevel * 0.5
	var win_color := lamp_color if lit else lamp_color.darkened(0.68)
	if disabled:
		win_color = TmpTokens.BODY_DARK
	draw_rect(win.grow(bevel * 0.6), TmpTokens.BODY_DARK)
	draw_rect(win, win_color)
	if lit:
		draw_rect(Rect2(win.position, Vector2(win.size.x, win.size.y * 0.35)), Color(1, 1, 1, 0.14))
	var text_color := TmpTokens.BODY_DARK if lit else (TmpTokens.DIM if disabled else lamp_color.lightened(0.55))
	var fs: int = info["fs"]
	var small: int = info["small"]
	var text_x: float = info["text_x"]
	var show_marker: bool = info["marker"]
	var bold := TmpTokens.font_bold()
	var reg := TmpTokens.font()
	var off := Vector2(1.0, 1.0) * bevel * 0.5 if down else Vector2.ZERO
	if show_marker:
		var mr := minf(UiScale.dp(7.0), r.size.y * 0.18)
		TmpTokens.draw_marker(self, level, off + Vector2(text_x - mr * 2.0 - UiScale.dp(4.0) + mr, r.size.y * 0.5), mr, text_color, win_color)
	if sub_caption == "":
		var w := -1.0 if show_marker else r.size.x
		var x := text_x if show_marker else 0.0
		var align := HORIZONTAL_ALIGNMENT_LEFT if show_marker else HORIZONTAL_ALIGNMENT_CENTER
		draw_string(bold, off + Vector2(x, TmpTokens.baseline(bold, fs, r.size.y * 0.5)), info["cap"], align, w, fs, text_color)
	else:
		var gap := UiScale.dp(2.0)
		var block := fs + small + gap
		var top := r.size.y * (0.44 if fill >= 0.0 else 0.5) - block * 0.5
		draw_string(bold, off + Vector2(text_x, TmpTokens.baseline(bold, fs, top + fs * 0.5)), info["cap"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		draw_string(reg, off + Vector2(text_x, TmpTokens.baseline(reg, small, top + fs + gap + small * 0.5)), info["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, small, text_color)
	if fill >= 0.0:
		var bar := Rect2(off + Vector2(text_x, r.size.y - UiScale.dp(8.0)), Vector2(maxf(0.0, r.size.x - text_x - bevel * 3.0), UiScale.dp(3.0)))
		draw_rect(bar, text_color.darkened(0.55) if not lit else Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), text_color)
