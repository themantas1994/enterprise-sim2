extends PanelBase
## Damage control: the teams of the map entry as tiles, and the repair queue of the whole map. Pressing a
## queue row assigns the selected team to that component (the only way to repair); RECALL frees the team.
## Reads the ids of the map and the `ship.damage_control` section.

var _queue: VBoxContainer
var _empty: Label
var _team_sel := ""


func _group_defs() -> Array:
	return [["TEAMS", ["dc_team"]]]


func team() -> String:
	if _team_sel != "" and ids.has(_team_sel):
		return _team_sel
	return ids[0] if not ids.is_empty() else ""


func select(id: String) -> void:
	if ids.has(id):
		_team_sel = id
	super.select(id)


func _team_state(id: String) -> Dictionary:
	return ship("damage_control").get("teams", {}).get(id, {})


func _detail_text(id: String) -> String:
	var t := _team_state(id)
	if t.is_empty():
		return ""
	return "%s %s %ds left" % [str(t.get("state", "")), str(t.get("target", "")), int(float(t.get("left", 0)) * 0.1)] if t.get("target", "") != "" else str(t.get("state", ""))


func _assign(target: String) -> void:
	var b: Node = _queue.get_node_or_null("row_" + target)
	if b is PanelButton:
		_ctl["assign"] = b
		_ctl_base["assign"] = {"caption": b.caption, "sub": b.sub_caption, "level": b.level}
	send_ctl("assign", {"type": "assign_team", "team": team(), "target": target})


func _build_controls() -> void:
	add_button("recall", "RECALL TEAM", func() -> void: send_ctl("recall", {"type": "recall_team", "team": team()}), UiStatus.CAUTION)


func _build_extra(c: VBoxContainer) -> void:
	c.add_child(kit.caption("Repair queue - press to assign the selected team"))
	_empty = kit.caption("Nothing damaged")
	c.add_child(_empty)
	_queue = VBoxContainer.new()
	c.add_child(_queue)


func _update_controls(_snap_data: Dictionary) -> void:
	var t := team()
	set_button("recall", "RECALL TEAM", UiStatus.pretty(t).replace("DC ", ""), UiStatus.CAUTION)


func _update_extra(_snap_data: Dictionary) -> void:
	var rows: Array = []
	for entry: Dictionary in ship("damage_control").get("queue", []):
		var id := str(entry.get("id", ""))
		if not wide_ids.has(id):
			continue
		var who := str(entry.get("team", ""))
		var sub := "ETA %ds  %d%%" % [int(float(entry.get("eta", 0)) * 0.1), int(float(entry.get("integrity", 0.0)))]
		if who != "":
			sub += "  " + UiStatus.pretty(who)
		if not entry.get("repairable", true):
			sub += "  NOT REPAIRABLE"
		rows.append({"id": id, "caption": "ASSIGN " + UiStatus.pretty(id), "sub": sub, "level": level_of(id)})
	_empty.visible = rows.is_empty()
	sync_rows(_queue, rows, _assign)
