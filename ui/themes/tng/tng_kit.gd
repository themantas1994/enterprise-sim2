class_name TngKit
extends WidgetKit
## The 1701-D (TNG LCARS) widget kit.

var _frame_count := 0


func button() -> PanelButton:
	return TngButton.new()


func gauge(label_text: String = "") -> BarGauge:
	var g := TngBarGauge.new()
	g.set_label(label_text)
	return g


func frame(title_text: String = "") -> FrameBox:
	var f := TngFrame.new()
	f.accent = _frame_count
	_frame_count += 1
	f.set_title(title_text)
	return f


func readout(label_text: String = "", value_text: String = "") -> Readout:
	var r := TngReadout.new()
	r.set_pair(label_text, value_text)
	return r


func schematic() -> SchematicView:
	var s := TngSchematic.new()
	s.setup(self)
	return s


func banner() -> AlertBanner:
	return TngAlertBanner.new()


func slider() -> PanelSlider:
	return TngSlider.new()


func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", TngTokens.LAVENDER)
	return l


func era() -> String:
	return "tng"
