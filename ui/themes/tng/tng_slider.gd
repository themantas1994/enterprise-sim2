class_name TngSlider
extends PanelSlider
## LCARS slider: flat track with a pill knob. The grabber icon is an invisible placeholder that only sets the
## knob size for the engine's hit testing; the visible knob is drawn here.


func _init() -> void:
	super._init()
	# Fully transparent grabber icon: it only sets the knob size for hit testing; the knob is drawn in _draw.
	var img := Image.create_empty(maxi(1, int(UiScale.dp(48.0))), maxi(1, int(UiScale.dp(48.0))), false, Image.FORMAT_RGBA8)
	var k := ImageTexture.create_from_image(img)
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		add_theme_icon_override(icon_name, k)
	for sb in ["slider", "grabber_area", "grabber_area_highlight"]:
		add_theme_stylebox_override(sb, StyleBoxEmpty.new())


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := TngTokens.min_font() + int(UiScale.dp(2.0))
	var knob_w := UiScale.dp(48.0)
	var track_h := UiScale.dp(8.0)
	var y := size.y * 0.72
	var vt := value_text()
	var vw := font.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(0, fs), TngTokens.fit(font, label, fs, size.x - vw - UiScale.dp(8.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TngTokens.PEACH)
	draw_string(font, Vector2(size.x - vw, fs), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TngTokens.TEXT)
	var track := Rect2(Vector2(knob_w * 0.5, y - track_h * 0.5), Vector2(maxf(1.0, size.x - knob_w), track_h))
	draw_rect(track, TngTokens.DIM)
	var ratio := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track_h)), TngTokens.LAVENDER)
	var knob := StyleBoxFlat.new()
	knob.bg_color = TngTokens.PEACH if editable else TngTokens.DIM
	knob.set_corner_radius_all(int(UiScale.dp(13.0)))
	draw_style_box(knob, Rect2(Vector2(track.position.x + track.size.x * ratio - knob_w * 0.4, y - UiScale.dp(13.0)), Vector2(knob_w * 0.8, UiScale.dp(26.0))))
