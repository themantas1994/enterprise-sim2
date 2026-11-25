class_name BarGauge
extends Control
## Era-independent horizontal bar gauge: label, a fill from 0 to max, a numeric text and a status level.

var label := ""
var value := 0.0
var max_value := 1.0
var value_text := ""
var level := UiStatus.OK


func _init() -> void:
	custom_minimum_size = Vector2(UiScale.dp(120.0), UiScale.dp(32.0))


func set_label(text: String) -> void:
	label = text.to_upper()
	queue_redraw()


func set_reading(v: float, max_v: float, status_level: String, text: String = "") -> void:
	value = v
	max_value = maxf(max_v, 0.000001)
	level = status_level
	value_text = text if text != "" else str(snappedf(v, 0.1))
	queue_redraw()


func fraction() -> float:
	return clampf(value / max_value, 0.0, 1.0)
