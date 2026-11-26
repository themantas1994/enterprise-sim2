class_name PanelButton
extends Button
## Era-independent button interface. Panels create buttons through the widget kit and only use this API; the
## era kit subclass decides the look. The caption is drawn by the era subclass (text stays empty).
## A button is also used as a selectable tile: sub-caption, status level and a fill fraction (-1 = none).

var caption := ""
var sub_caption := ""
var level := UiStatus.OK
var fill := -1.0
var selected := false


func _init() -> void:
	custom_minimum_size = Vector2(UiScale.touch_min(), UiScale.touch_min())
	focus_mode = Control.FOCUS_ALL
	add_to_group("touch_target")


func set_caption(main: String, sub: String = "") -> void:
	caption = main.to_upper()
	sub_caption = sub.to_upper()
	tooltip_text = (caption + " " + sub_caption).strip_edges()
	queue_redraw()


func set_level(value: String) -> void:
	level = value
	queue_redraw()


func set_fill(value: float) -> void:
	fill = value
	queue_redraw()


## True when the era's drawing had to cut a caption with an ellipsis (tests check this).
func is_truncated() -> bool:
	return false


## Font sizes the era's drawing uses for the caption and the sub-caption.
func drawn_font_sizes() -> Array:
	return []


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()
