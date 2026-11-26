class_name TmpKit
extends WidgetKit
## The film-era (refit NCC-1701-A) widget kit: hardware panels, backlit push-buttons with coloured legends,
## indicator lamps, CRT line art. Same method set as TngKit plus `lamp()`. Fully deterministic: nothing here
## uses randomness. Original drawing only.


func button() -> PanelButton:
	return TmpButton.new()


func gauge(label_text: String = "") -> BarGauge:
	var g := TmpBarGauge.new()
	g.set_label(label_text)
	return g


func frame(title_text: String = "") -> FrameBox:
	var f := TmpFrame.new()
	f.set_title(title_text)
	return f


func readout(label_text: String = "", value_text: String = "") -> Readout:
	var r := TmpReadout.new()
	r.set_pair(label_text, value_text)
	return r


func schematic() -> SchematicView:
	var s := TmpSchematic.new()
	s.setup(self)
	return s


func banner() -> AlertBanner:
	return TmpAlertBanner.new()


func slider() -> PanelSlider:
	return TmpSlider.new()


func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", TmpTokens.ETCH)
	l.add_theme_font_override("font", TmpTokens.font_bold())
	return l


## An indicator lamp in one of the legend colours (red, amber, blue, green, white).
func lamp(color_name: String = "green", lit: bool = true) -> TmpLamp:
	var l := TmpLamp.new()
	l.set_lamp(color_name, lit)
	return l


func era() -> String:
	return "tmp"
