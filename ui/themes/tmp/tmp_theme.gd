class_name TmpTheme
extends RefCounted
## Builds the Theme for the film-era kit: Exo 2 Regular, sizes in dp, dark hardware styles. Built in code so
## sizes follow the screen density (UiScale); call build() again when the scale changes.

const BASE_DP := 16.0


static func build() -> Theme:
	var t := Theme.new()
	var font := TmpTokens.font()
	var fs := int(UiScale.dp(BASE_DP))
	t.default_font = font
	t.default_font_size = fs
	for type_name in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		t.set_font("font", type_name, font)
		t.set_font_size("font_size", type_name, fs)
	t.set_color("font_color", "Label", TmpTokens.TEXT)
	t.set_color("font_color", "Button", TmpTokens.TEXT)
	var flat := StyleBoxFlat.new()
	flat.bg_color = TmpTokens.BODY_DARK
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
	f.border_color = TmpTokens.TEXT
	f.set_border_width_all(2)
	f.set_corner_radius_all(int(UiScale.dp(3.0)))
	return f
