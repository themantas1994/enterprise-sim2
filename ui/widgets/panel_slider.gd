class_name PanelSlider
extends HSlider
## Era-independent slider (0..1 by default) with its own label and value text, so it needs no separate readout.
## The era subclass draws it. Touch target.

var label := ""
var value_scale := 1.0      # shown value = value * value_scale
var value_decimals := 0
var value_suffix := ""


func _init() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	custom_minimum_size = Vector2(UiScale.dp(180.0), UiScale.dp(52.0))
	add_to_group("touch_target")


func setup_display(label_text: String, scale_factor: float = 1.0, decimals: int = 0, suffix: String = "") -> void:
	label = label_text.to_upper()
	value_scale = scale_factor
	value_decimals = decimals
	value_suffix = suffix
	queue_redraw()


func value_text() -> String:
	return ("%." + str(value_decimals) + "f") % (value * value_scale) + value_suffix
