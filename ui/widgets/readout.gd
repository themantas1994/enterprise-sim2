class_name Readout
extends Control
## Era-independent label plus value readout with a status level marker.

var label := ""
var value_text := ""
var level := UiStatus.INFO
## Compact readouts put the value right after the label instead of at the right edge (for header strips).
var compact := false


func _init() -> void:
	custom_minimum_size = Vector2(UiScale.dp(120.0), UiScale.dp(32.0))


func set_pair(label_text: String, text: String, status_level: String = UiStatus.INFO) -> void:
	label = label_text.to_upper()
	value_text = text.to_upper()
	level = status_level
	queue_redraw()
