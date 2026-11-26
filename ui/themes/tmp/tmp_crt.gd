class_name TmpCrt
extends RefCounted
## Builds the CRT overlay of the film-era kit (crt.gdshader) for a panel region.
## The overlay is a ColorRect with a ShaderMaterial that reads the screen texture. In 2D that texture is copied
## once per frame, at the first node that reads it (ENG-GODOT-019), so a second overlay would see a stale copy.
## Every overlay therefore gets its own BackBufferCopy placed just before it, so
## each overlay reads a fresh copy of what is drawn below it (ENG-GODOT-019, ENG-GODOT-021).
## `wrap` puts the content, the BackBufferCopy and the overlay in one container, in that draw order.
## `layer` makes a full-screen variant: see its comment for the CanvasLayer index.

const SHADER_PATH := "res://ui/themes/tmp/crt.gdshader"
const UNIFORMS := ["scan_period", "scan_strength", "glow", "glow_radius", "flicker", "flicker_rate", "vignette", "reduced_motion"]
## Default CanvasLayer index of the full-screen variant. The overlay is drawn after every layer with a lower
## index (they are scanned and glowed) and before every layer with a higher one (they stay crisp: put modal
## dialogs and similar above it). The result is opaque, so it replaces what is below it in the covered region.
const DEFAULT_LAYER := 100

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


static func glow_radius_px() -> float:
	return clampf(UiScale.dp(1.0) * UiScale.px_per_unit(), 1.0, 4.0)


static func material(reduced_motion: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	for k: String in DEFAULTS:
		m.set_shader_parameter(k, DEFAULTS[k])
	m.set_shader_parameter("scan_period", scan_period_px())
	m.set_shader_parameter("glow_radius", glow_radius_px())
	m.set_shader_parameter("reduced_motion", reduced_motion)
	return m


## Re-reads the screen density: sets the pixel-based uniforms again. Called on a viewport size change.
static func refresh(over: ColorRect) -> void:
	if not is_instance_valid(over) or not (over.material is ShaderMaterial):
		return
	var m := over.material as ShaderMaterial
	m.set_shader_parameter("scan_period", scan_period_px())
	m.set_shader_parameter("glow_radius", glow_radius_px())


static func _bind(over: ColorRect) -> void:
	var vp := over.get_viewport()
	var cb := TmpCrt.refresh.bind(over)
	if vp != null and not vp.size_changed.is_connected(cb):
		vp.size_changed.connect(cb)
	refresh(over)


static func _unbind(over: ColorRect) -> void:
	var vp := over.get_viewport()
	var cb := TmpCrt.refresh.bind(over)
	if vp != null and vp.size_changed.is_connected(cb):
		vp.size_changed.disconnect(cb)


## A ColorRect that fills its parent and lets input through. It follows the viewport size (scanline period and
## glow radius are re-set when the viewport changes). Add it as the LAST child of the region, after a
## BackBufferCopy (see `wrap`).
static func overlay(reduced_motion: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.name = "CrtOverlay"
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.material = material(reduced_motion)
	r.tree_entered.connect(_bind.bind(r))
	r.tree_exiting.connect(_unbind.bind(r))
	return r


## A BackBufferCopy placed right before the node that follows it. It copies the whole viewport: the rectangle
## mode (COPY_MODE_RECT) was tried first and gave a black overlay on the Linux software-GL Compatibility run
## (ENG-GODOT-022 says nothing about it), so the viewport mode is used. One copy per overlay.
static func back_buffer() -> BackBufferCopy:
	var b := BackBufferCopy.new()
	b.name = "CrtBackBuffer"
	b.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	return b


## Puts `content` and a CRT overlay over it in one container: content, BackBufferCopy, overlay (the draw order).
## The container's minimum size is the content's.
static func wrap(content: Control, reduced_motion: bool = false) -> MarginContainer:
	var box := MarginContainer.new()
	box.name = "CrtRegion"
	box.add_child(content)
	box.add_child(back_buffer())
	box.add_child(overlay(reduced_motion))
	return box


## Full-screen variant: a CanvasLayer holding a BackBufferCopy of the whole viewport and one overlay.
## `index` is the CanvasLayer index (DEFAULT_LAYER): layers below it are affected, layers above it are not.
static func layer(reduced_motion: bool = false, index: int = DEFAULT_LAYER) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.name = "CrtLayer"
	l.layer = index
	l.add_child(back_buffer())
	l.add_child(overlay(reduced_motion))
	return l


static func find_overlays(root: Node) -> Array[ColorRect]:
	var out: Array[ColorRect] = []
	for n in root.find_children("CrtOverlay", "ColorRect", true, false):
		out.append(n as ColorRect)
	return out


static func find_overlay(root: Node) -> ColorRect:
	var all := find_overlays(root)
	return all[0] if not all.is_empty() else null


static func set_reduced_motion(over: ColorRect, on: bool) -> void:
	(over.material as ShaderMaterial).set_shader_parameter("reduced_motion", on)


## The flicker depth the shader will use: 0 in reduced motion.
static func effective_flicker(over: ColorRect) -> float:
	var m := over.material as ShaderMaterial
	if bool(m.get_shader_parameter("reduced_motion")):
		return 0.0
	return float(m.get_shader_parameter("flicker"))
