class_name TmpLamp
extends Control
## Indicator lamp: a round lens in one of the five legend colours (red, amber, blue, green, white). Lit or dark.
## Not interactive. Drawn in code.

var lamp_name := "green"
var lit := true


func _init() -> void:
	custom_minimum_size = Vector2(UiScale.dp(24.0), UiScale.dp(24.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_lamp(color_name: String, is_lit: bool = true) -> void:
	lamp_name = color_name if TmpTokens.LAMP.has(color_name) else "white"
	lit = is_lit
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	var color := TmpTokens.lamp_color(lamp_name)
	draw_circle(c, r, TmpTokens.BODY_DARK)
	draw_circle(c, r * 0.82, color if lit else color.darkened(0.72))
	if lit:
		draw_circle(c, r * 0.5, color.lightened(0.35))
		draw_circle(c + Vector2(-r * 0.22, -r * 0.25), r * 0.14, Color(1, 1, 1, 0.85))
	draw_arc(c, r * 0.9, 0.0, TAU, 24, TmpTokens.BODY_LIGHT, maxf(1.5, r * 0.12))
