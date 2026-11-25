class_name FrameBox
extends MarginContainer
## Era-independent frame: a title bar with an elbow around a content area. Children go into `body`.

var title := ""
var accent := 0
var body: VBoxContainer


func _init() -> void:
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)


func set_title(text: String) -> void:
	title = text.to_upper()
	queue_redraw()
