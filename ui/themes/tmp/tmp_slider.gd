class_name TmpSlider
extends PanelSlider
## Film-era slider: a fader. A dark groove with tick marks and a rectangular cap with grip ridges and a lit
## index line. The grabber icon is an invisible placeholder that only sets the knob size for hit testing.


func _init() -> void:
	super._init()
	var img := Image.create_empty(maxi(1, int(UiScale.dp(48.0))), maxi(1, int(UiScale.dp(48.0))), false, Image.FORMAT_RGBA8)
	var k := ImageTexture.create_from_image(img)
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		add_theme_icon_override(icon_name, k)
	for sb in ["slider", "grabber_area", "grabber_area_highlight"]:
		add_theme_stylebox_override(sb, StyleBoxEmpty.new())


func _layout() -> Dictionary:
	var font := TmpTokens.font()
	var fs := TmpTokens.min_font() + int(UiScale.dp(2.0))
	var vt := value_text()
	var vw := TmpTokens.font_bold().get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return {"font": font, "fs": fs, "vt": vt, "vw": vw, "label": TmpTokens.fit(font, label, fs, size.x - vw - UiScale.dp(8.0))}


func drawn_font_sizes() -> Array:
	return [_layout()["fs"]]


func is_truncated() -> bool:
	return _layout()["label"] != label


func _draw() -> void:
	var l := _layout()
	var font: Font = l["font"]
	var fs: int = l["fs"]
	var vw: float = l["vw"]
	var knob_w := UiScale.dp(48.0)
	var groove_h := UiScale.dp(8.0)
	var y := size.y * 0.7
	draw_string(font, Vector2(0, TmpTokens.baseline(font, fs, fs * 0.6)), l["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TmpTokens.ETCH)
	draw_string(TmpTokens.font_bold(), Vector2(size.x - vw, TmpTokens.baseline(font, fs, fs * 0.6)), l["vt"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TmpTokens.TEXT)
	var track := Rect2(Vector2(knob_w * 0.5, y - groove_h * 0.5), Vector2(maxf(1.0, size.x - knob_w), groove_h))
	draw_rect(track.grow(UiScale.dp(2.0)), TmpTokens.BODY_DARK)
	var ratio := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, groove_h)), TmpTokens.level_color(UiStatus.CAUTION).darkened(0.35) if editable else TmpTokens.DIM)
	for i in 11:
		var tx := track.position.x + track.size.x * i / 10.0
		draw_line(Vector2(tx, y + groove_h), Vector2(tx, y + groove_h + (UiScale.dp(5.0) if i % 5 == 0 else UiScale.dp(3.0))), TmpTokens.ETCH, 1.0)
	var cap_w := UiScale.dp(30.0)
	var cap_h := UiScale.dp(30.0)
	var cap := Rect2(Vector2(track.position.x + track.size.x * ratio - cap_w * 0.5, y - cap_h * 0.5), Vector2(cap_w, cap_h))
	draw_rect(cap, TmpTokens.BODY_LIGHT if editable else TmpTokens.BODY)
	TmpTokens.draw_bevel(self, cap, maxf(2.0, UiScale.dp(2.0)), false)
	for i in 3:
		var gx := cap.position.x + cap_w * (0.25 + 0.25 * i)
		draw_line(Vector2(gx, cap.position.y + cap_h * 0.18), Vector2(gx, cap.end.y - cap_h * 0.18), TmpTokens.BODY_DARK, 1.5)
	draw_line(Vector2(cap.get_center().x, cap.position.y + 2.0), Vector2(cap.get_center().x, cap.end.y - 2.0), TmpTokens.lamp_color("white") if editable else TmpTokens.DIM, maxf(1.5, UiScale.dp(1.5)))
