class_name TngTokens
extends RefCounted
## Colour tokens for the 1701-D era (LCARS grammar, PLAN section 5): black ground, flat pastel colour, red for
## alerts. The values are original design choices; no Star Trek source value is involved.

const BLACK := Color("000000")
const PEACH := Color("f2a67a")
const SALMON := Color("e88a83")
const LAVENDER := Color("b79ad6")
const PALE_BLUE := Color("8fb4e8")
const TAN := Color("d9b48f")
const RED := Color("e0303a")
const AMBER := Color("f5c04a")
const GREEN := Color("86d49a")
const TEXT := Color("f4e9dc")
const DIM := Color("5a4f6a")

const LEVEL_COLOR := {
	"ok": PALE_BLUE,
	"info": LAVENDER,
	"caution": AMBER,
	"alarm": RED,
	"off": DIM,
}
const ALERT_COLOR := {"green": GREEN, "yellow": AMBER, "red": RED}
const FRAME_COLORS := [PEACH, LAVENDER, SALMON, TAN, PALE_BLUE]

const FONT_PATH := "res://ui/themes/tng/fonts/Antonio-Regular.ttf"


static func level_color(level: String) -> Color:
	return LEVEL_COLOR.get(level, LAVENDER)


## Antonio (ENG-FONT-001..005). Falls back to the engine default font when the file cannot be loaded.
static func font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f: Variant = load(FONT_PATH)
		if f is Font:
			return f
	return ThemeDB.fallback_font


## Draws a status marker whose shape encodes the level: circle = ok, ring = off, triangle = caution,
## square with bars = alarm, diamond = info. `c` is the centre, `r` the radius.
static func draw_marker(item: CanvasItem, level: String, c: Vector2, r: float, color: Color, bg: Color = BLACK) -> void:
	match level:
		"ok":
			item.draw_circle(c, r, color)
		"off":
			item.draw_arc(c, r * 0.85, 0.0, TAU, 20, color, maxf(1.5, r * 0.28))
		"caution":
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), color)
			item.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.25), Vector2(r * 0.24, r * 0.6)), bg)
		"alarm":
			item.draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), color)
			item.draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), bg, maxf(1.5, r * 0.3))
			item.draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.6, -r * 0.6), bg, maxf(1.5, r * 0.3))
		_:
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)
