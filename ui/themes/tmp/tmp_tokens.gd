class_name TmpTokens
extends RefCounted
## Colour tokens and helpers for the film-era kit (PLAN section 5): dark grey-brown hardware panels, backlit
## rectangular push-buttons with coloured legends, indicator lamps, and green or blue CRT line art. The values
## are original design choices; no Star Trek source value is involved.

const BODY := Color("2d2824")
const BODY_LIGHT := Color("5a5047")
const BODY_DARK := Color("120f0d")
const SCREEN := Color("06120c")
const TEXT := Color("ece3d2")
const ETCH := Color("b5a892")
const DIM := Color("6c6459")
const PHOSPHOR_GREEN := Color("62f08a")
const PHOSPHOR_BLUE := Color("66bcff")

## Legend lamp colours (names are the public vocabulary of TmpButton.lamp and TmpLamp).
const LAMP := {
	"red": Color("ee4a40"),
	"amber": Color("f5a91c"),
	"blue": Color("4fa6ff"),
	"green": Color("4fd870"),
	"white": Color("f3eee2"),
}
const LAMP_NAMES := ["red", "amber", "blue", "green", "white"]
const LEVEL_LAMP := {"ok": "green", "info": "blue", "caution": "amber", "alarm": "red", "off": "white"}
const ALERT_LAMP := {"green": "green", "yellow": "amber", "red": "red"}

const FONT_REGULAR_PATH := "res://ui/themes/tmp/fonts/Exo2-Regular.ttf"
const FONT_BOLD_PATH := "res://ui/themes/tmp/fonts/Exo2-Bold.ttf"

static var _regular: Font = null
static var _bold: Font = null


## Smallest font size drawn anywhere: 13 dp (the project floor is 12 dp).
static func min_font() -> int:
	return int(ceilf(UiScale.dp(13.0)))


static func lamp_color(lamp_name: String) -> Color:
	return LAMP.get(lamp_name, LAMP["white"])


static func level_lamp(level: String) -> String:
	return LEVEL_LAMP.get(level, "blue")


## Colour of lit text or phosphor for a status level.
static func level_color(level: String) -> Color:
	return lamp_color(level_lamp(level))


## `text` cut with an ellipsis so that it fits in `width` at font size `fs`.
static func fit(font: Font, text: String, fs: int, width: float) -> String:
	if width <= 0.0 or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	var s := text
	while s.length() > 1 and font.get_string_size(s + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		s = s.substr(0, s.length() - 1)
	return s + "..."


## Baseline y that centres a line of text of size `fs` on `cy`.
static func baseline(font: Font, fs: int, cy: float) -> float:
	return cy + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5


## The font at `path`, or null when it cannot be loaded (the caller then uses the engine fallback without
## remembering it, so a later call can still load the real font).
static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Variant = load(path)
		if f is Font:
			return f
	return null


## Exo 2 Regular (ENG-FONT-006..008). Falls back to the engine default font when the file cannot be loaded.
static func font() -> Font:
	if _regular == null:
		_regular = _load_font(FONT_REGULAR_PATH)
	return _regular if _regular != null else ThemeDB.fallback_font


static func font_bold() -> Font:
	if _bold == null:
		_bold = _load_font(FONT_BOLD_PATH)
	return _bold if _bold != null else ThemeDB.fallback_font


## Raised (or, when `pressed`, sunk) bevel along the edges of `r`: light top and left, dark bottom and right.
static func draw_bevel(item: CanvasItem, r: Rect2, width: float, pressed: bool) -> void:
	var hi := BODY_LIGHT if not pressed else BODY_DARK
	var lo := BODY_DARK if not pressed else BODY_LIGHT
	item.draw_rect(Rect2(r.position, Vector2(r.size.x, width)), hi)
	item.draw_rect(Rect2(r.position, Vector2(width, r.size.y)), hi)
	item.draw_rect(Rect2(Vector2(r.position.x, r.end.y - width), Vector2(r.size.x, width)), lo)
	item.draw_rect(Rect2(Vector2(r.end.x - width, r.position.y), Vector2(width, r.size.y)), lo)


## Status marker whose shape encodes the level (never colour alone): circle = ok, ring = off, triangle =
## caution, square with a cross = alarm, diamond = info. `c` is the centre, `r` the radius.
static func draw_marker(item: CanvasItem, level: String, c: Vector2, r: float, color: Color, bg: Color) -> void:
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
