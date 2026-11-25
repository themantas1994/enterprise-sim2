class_name UiScale
extends RefCounted
## Density-independent sizes. One dp is 1/160 inch (ENG-ANDROID-001 targets are 48 dp). The project uses the
## canvas_items stretch mode with aspect expand (ENG-GODOT-012), so layout units are not screen pixels:
## one unit is `px_per_unit()` pixels. dp(x) returns layout units for x dp.
## Density comes from DisplayServer.screen_get_dpi (ENG-GODOT-013), never below 1.0 so a desktop window is
## laid out at 1 dp = 1 unit. Tests set an override for the two target sizes.

const MIN_TOUCH_DP := 48.0

static var _density_override := -1.0
static var _ppu_override := -1.0


static func set_override(density_value: float, px_per_unit_value: float) -> void:
	_density_override = density_value
	_ppu_override = px_per_unit_value


static func clear_override() -> void:
	_density_override = -1.0
	_ppu_override = -1.0


static func density() -> float:
	if _density_override > 0.0:
		return _density_override
	return maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)


## Screen pixels per layout unit of the root viewport (1.0 when no stretch scaling applies).
static func px_per_unit() -> float:
	if _ppu_override > 0.0:
		return _ppu_override
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root: Window = (loop as SceneTree).root
		var vis := root.get_visible_rect().size
		if vis.x > 0.0 and root.size.x > 0:
			return maxf(0.1, float(root.size.x) / vis.x)
	return 1.0


static func dp(value: float) -> float:
	return value * density() / px_per_unit()


static func touch_min() -> float:
	return dp(MIN_TOUCH_DP)
