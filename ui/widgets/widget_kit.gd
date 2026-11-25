class_name WidgetKit
extends RefCounted
## The era-independent widget interface (PLAN section 5): button, bar gauge, frame/elbow, readout, schematic
## view, alert banner (plus slider and caption). Panels are written once against these methods; an era kit
## (for example TngKit) returns subclasses that draw the era's look. This base class returns undrawn widgets.


func button() -> PanelButton:
	return PanelButton.new()


func gauge(label_text: String = "") -> BarGauge:
	var g := BarGauge.new()
	g.set_label(label_text)
	return g


func frame(title_text: String = "") -> FrameBox:
	var f := FrameBox.new()
	f.set_title(title_text)
	return f


func readout(label_text: String = "", value_text: String = "") -> Readout:
	var r := Readout.new()
	r.set_pair(label_text, value_text)
	return r


func schematic() -> SchematicView:
	var s := SchematicView.new()
	s.setup(self)
	return s


func banner() -> AlertBanner:
	return AlertBanner.new()


func slider() -> PanelSlider:
	return PanelSlider.new()


## A small heading label.
func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	return l


## Era name, used by the host to pick the kit.
func era() -> String:
	return "base"
