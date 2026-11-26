class_name TngTheme
extends RefCounted
## Builds the Theme for the 1701-D era: Antonio, upper-case friendly sizes in dp, flat black styles.
## Built in code so sizes follow the screen density (UiScale); call build() again when the scale changes.

static func build() -> Theme:
	var t := Theme.new()
	var font := TngTokens.font()
	t.default_font = font
	t.default_font_size = int(UiScale.dp(18.0))
	for type_name in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		t.set_font("font", type_name, font)
		t.set_font_size("font_size", type_name, int(UiScale.dp(18.0)))
	t.set_color("font_color", "Label", TngTokens.TEXT)
	t.set_color("font_color", "Button", TngTokens.BLACK)
	var flat := StyleBoxFlat.new()
	flat.bg_color = TngTokens.BLACK
	flat.set_corner_radius_all(0)
	t.set_stylebox("normal", "PanelContainer", flat)
	t.set_stylebox("panel", "PanelContainer", flat)
	t.set_stylebox("focus", "Button", _focus_box())
	for sb in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(sb, "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "HSlider", _focus_box())
	t.set_constant("separation", "VBoxContainer", int(UiScale.dp(8.0)))
	t.set_constant("separation", "HBoxContainer", int(UiScale.dp(8.0)))
	return t


static func _focus_box() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = TngTokens.TEXT
	f.set_border_width_all(2)
	f.set_corner_radius_all(int(UiScale.dp(24.0)))
	return f
