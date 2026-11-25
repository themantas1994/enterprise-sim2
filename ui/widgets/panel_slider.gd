class_name PanelSlider
extends HSlider
## Era-independent slider (0..1 by default). The era subclass draws it. Touch target.


func _init() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	custom_minimum_size = Vector2(UiScale.dp(160.0), UiScale.touch_min())
	add_to_group("touch_target")
