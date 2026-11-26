class_name TmpCrt
extends RefCounted
## Builds the CRT overlay of the film-era kit (crt.gdshader) for a panel region.
## The overlay is a ColorRect with a ShaderMaterial. It reads the screen texture (ENG-GODOT-019), so it must be
## drawn after the content it covers: `wrap` puts the content and the overlay in one container, the overlay last.
## `layer` makes a full-screen variant under a high CanvasLayer index (ENG-GODOT-021).

const SHADER_PATH := "res://ui/themes/tmp/crt.gdshader"
const UNIFORMS := ["scan_period", "scan_strength", "glow", "glow_radius", "flicker", "flicker_rate", "vignette", "reduced_motion"]

## Tuning values (UI scales). They repeat the shader defaults so that the material reports them.
const DEFAULTS := {"scan_strength": 0.28, "glow": 0.35, "flicker": 0.04, "flicker_rate": 9.0, "vignette": 0.35}

static var _shader: Shader = null


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## Scanline distance in screen pixels for the current density: 3 dp, never below 2 px.
static func scan_period_px() -> float:
	return maxf(2.0, UiScale.dp(3.0) * UiScale.px_per_unit())


static func material(reduced_motion: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	for k: String in DEFAULTS:
		m.set_shader_parameter(k, DEFAULTS[k])
	m.set_shader_parameter("scan_period", scan_period_px())
	m.set_shader_parameter("glow_radius", clampf(UiScale.dp(1.0) * UiScale.px_per_unit(), 1.0, 4.0))
	m.set_shader_parameter("reduced_motion", reduced_motion)
	return m


## A ColorRect that fills its parent and lets input through. Add it as the LAST child of the region.
static func overlay(reduced_motion: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.name = "CrtOverlay"
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.material = material(reduced_motion)
	return r


## Puts `content` and a CRT overlay over it in one container (the overlay is the last child, so it is drawn
## after the content). The container's minimum size is the content's.
static func wrap(content: Control, reduced_motion: bool = false) -> MarginContainer:
	var box := MarginContainer.new()
	box.name = "CrtRegion"
	box.add_child(content)
	box.add_child(overlay(reduced_motion))
	return box


## Full-screen variant: a CanvasLayer (index 100) holding one overlay.
static func layer(reduced_motion: bool = false) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.name = "CrtLayer"
	l.layer = 100
	var r := overlay(reduced_motion)
	l.add_child(r)
	return l


static func find_overlay(root: Node) -> ColorRect:
	return root.find_child("CrtOverlay", true, false) as ColorRect


static func set_reduced_motion(over: ColorRect, on: bool) -> void:
	(over.material as ShaderMaterial).set_shader_parameter("reduced_motion", on)


## The flicker depth the shader will use: 0 in reduced motion.
static func effective_flicker(over: ColorRect) -> float:
	var m := over.material as ShaderMaterial
	if bool(m.get_shader_parameter("reduced_motion")):
		return 0.0
	return float(m.get_shader_parameter("flicker"))
