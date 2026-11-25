class_name AlertBanner
extends Control
## Era-independent alert banner. Levels "green", "yellow", "red" differ by shape and blink as well as colour
## (PLAN section 6): green is a plain pill, yellow has angled ends and blinks slowly, red has hazard teeth and
## blinks fast. `reduced_motion` stops the blinking and keeps the shapes.

const BLINK_PERIOD := {"green": 0.0, "yellow": 1.2, "red": 0.5}

var alert := "green"
var text := ""
var reduced_motion := false
var phase_on := true
var _clock := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(UiScale.dp(160.0), UiScale.dp(40.0))
	set_process(true)


func set_alert(level: String, label_text: String = "") -> void:
	alert = level if BLINK_PERIOD.has(level) else "green"
	text = label_text if label_text != "" else default_text(alert)
	queue_redraw()


static func default_text(level: String) -> String:
	match level:
		"yellow":
			return "YELLOW ALERT"
		"red":
			return "RED ALERT"
	return "CONDITION GREEN"


## Outline of the banner: "pill" (green), "angled" (yellow), "teeth" (red). Differs per level, not by colour.
func shape() -> String:
	match alert:
		"yellow":
			return "angled"
		"red":
			return "teeth"
	return "pill"


func blink_period() -> float:
	return 0.0 if reduced_motion else float(BLINK_PERIOD.get(alert, 0.0))


func _process(delta: float) -> void:
	var period := blink_period()
	var on := true
	if period > 0.0:
		_clock = fmod(_clock + delta, period)
		on = _clock < period * 0.5
	if on != phase_on:
		phase_on = on
		queue_redraw()
