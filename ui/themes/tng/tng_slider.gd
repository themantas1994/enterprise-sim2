class_name TngSlider
extends PanelSlider
## LCARS slider: flat track with a pill knob. The grabber icon is an invisible placeholder that only sets the
## knob size for the engine's hit testing; the visible knob is drawn here.


func _init() -> void:
	super._init()
	var k := PlaceholderTexture2D.new()
	k.size = Vector2(UiScale.dp(48.0), UiScale.dp(48.0))
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		add_theme_icon_override(icon_name, k)
	for sb in ["slider", "grabber_area", "grabber_area_highlight"]:
		add_theme_stylebox_override(sb, StyleBoxEmpty.new())


func _draw() -> void:
	var track_h := UiScale.dp(10.0)
	var knob_w := UiScale.dp(48.0)
	var y := size.y * 0.5
	var track := Rect2(Vector2(knob_w * 0.5, y - track_h * 0.5), Vector2(maxf(1.0, size.x - knob_w), track_h))
	draw_rect(track, TngTokens.DIM)
	var ratio := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track_h)), TngTokens.LAVENDER)
	var knob := StyleBoxFlat.new()
	knob.bg_color = TngTokens.PEACH if editable else TngTokens.DIM
	knob.set_corner_radius_all(int(UiScale.dp(18.0)))
	draw_style_box(knob, Rect2(Vector2(track.position.x + track.size.x * ratio - knob_w * 0.5 + knob_w * 0.1, y - UiScale.dp(18.0)), Vector2(knob_w * 0.8, UiScale.dp(36.0))))
