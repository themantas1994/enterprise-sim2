class_name StatusStrip
extends HBoxContainer
## Scenario status readout: title, status (running, won, lost), time left and, when `show_reason` is set, the
## reason. Reads only the `ship.scenario` entry of the snapshot.

var host: Node
var kit: WidgetKit
var show_reason := false

var _title: Readout
var _status: Readout
var _time: Readout
var _reason: Readout


func _ready() -> void:
	if host == null:
		host = get_node_or_null("/root/SimHost")
	if kit == null:
		kit = TngKit.new()
	_title = _add_readout("Scenario")
	_status = _add_readout("Status")
	_time = _add_readout("Time left")
	if show_reason:
		_reason = _add_readout("Reason")
	if host != null:
		host.snapshot_ready.connect(func(snap: Dictionary, _p: Dictionary) -> void: update_from(snap))
		update_from(host.snapshot)


func _add_readout(label: String) -> Readout:
	var w := kit.readout(label)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.custom_minimum_size = Vector2(UiScale.dp(150.0), UiScale.dp(32.0))
	w.compact = true
	add_child(w)
	return w


func update_from(snap: Dictionary) -> void:
	var sc: Dictionary = snap.get("ship", {}).get("scenario", {})
	if sc.is_empty():
		_title.set_pair("Scenario", "none", UiStatus.INFO)
		_status.set_pair("Status", "-", UiStatus.INFO)
		_time.set_pair("Time left", "-", UiStatus.INFO)
		if _reason != null:
			_reason.set_pair("Reason", "", UiStatus.INFO)
		return
	var status := str(sc.get("status", "running"))
	var level := UiStatus.INFO
	if status == "won":
		level = UiStatus.OK
	elif status == "lost":
		level = UiStatus.ALARM
	_title.set_pair("Scenario", str(sc.get("title", sc.get("id", ""))), UiStatus.INFO)
	_status.set_pair("Status", status, level)
	_time.set_pair("Time left", UiStatus.clock(float(sc.get("time_left", 0))), UiStatus.CAUTION if status == "running" else UiStatus.INFO)
	if _reason != null:
		_reason.set_pair("Reason", str(sc.get("reason", "")), level)
