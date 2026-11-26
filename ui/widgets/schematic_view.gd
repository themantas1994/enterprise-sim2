class_name SchematicView
extends VBoxContainer
## Era-independent schematic: titled groups of selectable nodes (tiles) joined to a bus. The panel supplies
## groups {title, ids} and per-node data; the era subclass draws the bus. Nodes are PanelButtons made by the
## kit, so they are touch targets.

signal node_pressed(id: String)

var kit: WidgetKit
var nodes := {}          # id -> PanelButton
var _group_rows: Array = []


func setup(widget_kit: WidgetKit) -> void:
	kit = widget_kit


## groups: Array of {title: String, ids: Array}. Rebuilds the nodes only when the layout changed.
func set_groups(groups: Array) -> void:
	var sig := str(groups)
	if sig == get_meta("sig", ""):
		return
	set_meta("sig", sig)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	nodes.clear()
	_group_rows.clear()
	for g: Dictionary in groups:
		var title_label := kit.caption(str(g["title"]))
		add_child(title_label)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", int(UiScale.dp(8.0)))
		flow.add_theme_constant_override("v_separation", int(UiScale.dp(8.0)))
		add_child(flow)
		_group_rows.append(flow)
		for id: String in g["ids"]:
			var node := kit.button()
			node.custom_minimum_size = Vector2(UiScale.dp(168.0), UiScale.dp(56.0))
			node.pressed.connect(func() -> void: node_pressed.emit(id))
			flow.add_child(node)
			nodes[id] = node
	queue_redraw()


func set_node(id: String, main: String, sub: String, level: String, fill_value: float, is_selected: bool) -> void:
	var node: PanelButton = nodes.get(id)
	if node == null:
		return
	node.set_caption(main, sub)
	node.set_level(level)
	node.set_fill(fill_value)
	node.set_selected(is_selected)
