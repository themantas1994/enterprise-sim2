class_name DamageControlSystem
extends ShipSystem
## Four damage control teams and the repair queue (D-DMG-001, estimate: team count and repair times are game
## choices). The queue lists every component with integrity below 100 or a cut conduit, worst first; a reactor in
## breach or ejected is listed as not repairable. A team assigned to a queue entry works for
## travel + base + per_damage x missing integrity ticks, then a repair command restores the component.
## Commands: assign_team {team, target} (a busy team is reassigned), recall_team {team}.

const TEAMS := ["dc_team_1", "dc_team_2", "dc_team_3", "dc_team_4"]

var tasks: Dictionary = {}  # team id -> {target, left, total}
var done: Dictionary = {}  # team id -> repairs finished


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	for t: String in TEAMS:
		done[t] = 0


func is_damaged(c: Dictionary) -> bool:
	return c["integrity"] < 100.0 or c["state"] == "cut"


func repairable(c: Dictionary) -> bool:
	return c["state"] != "breach" and c["state"] != "ejected"


func repair_ticks(c: Dictionary) -> int:
	return int(rt.tune("damage_control", "travel_ticks")) + int(rt.tune("damage_control", "base_ticks")) \
		+ int(float(rt.tune("damage_control", "per_damage_ticks")) * (100.0 - c["integrity"]))


func assigned_team(target: String) -> String:
	for t: String in tasks:
		if tasks[t]["target"] == target:
			return t
	return ""


func handle(cmd: Dictionary, snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	if type == "recall_team":
		var t: Variant = cmd.get("team", null)
		if typeof(t) != TYPE_STRING or not TEAMS.has(t):
			return no("team must be one of dc_team_1..4")
		tasks.erase(t)
		return ok()
	if type != "assign_team":
		return null
	var team: Variant = cmd.get("team", null)
	var target: Variant = cmd.get("target", null)
	if typeof(team) != TYPE_STRING or not TEAMS.has(team):
		return no("team must be one of dc_team_1..4")
	if not rt.alive(team):
		return no("team is lost")
	if typeof(target) != TYPE_STRING or not snap["components"].has(target) or TEAMS.has(target):
		return no("target must be a damaged component")
	var c: Dictionary = snap["components"][target]
	if not is_damaged(c):
		return no("target is not damaged")
	if not repairable(c):
		return no("target is beyond repair in state " + c["state"])
	var other := assigned_team(target)
	if other != "" and other != team:
		return no("%s is already working on %s" % [other, target])
	tasks[team] = {"target": target, "left": repair_ticks(c), "total": repair_ticks(c)}
	return ok()


func update(snap: Dictionary) -> void:
	for team: String in tasks.keys():
		var task: Dictionary = tasks[team]
		var c: Dictionary = snap["components"][task["target"]]
		if not is_damaged(c) or not repairable(c):
			tasks.erase(team)
			continue
		task["left"] -= 1
		if task["left"] <= 0:
			rt.cmd({"type": "repair", "target": task["target"]})
			done[team] += 1
			rt.event("repair_done", {"team": team, "target": task["target"]})
			tasks.erase(team)


func queue() -> Array:
	var out: Array = []
	for id: String in rt.components():
		var c: Dictionary = rt.components()[id]
		if TEAMS.has(id) or not is_damaged(c):
			continue
		out.append({
			"id": id, "integrity": c["integrity"], "state": c["state"], "repairable": repairable(c),
			"team": assigned_team(id), "eta": repair_ticks(c),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["integrity"] < b["integrity"] or (a["integrity"] == b["integrity"] and a["id"] < b["id"]))
	return out


func section() -> Dictionary:
	var teams := {}
	for t: String in TEAMS:
		var task: Dictionary = tasks.get(t, {})
		teams[t] = {
			"state": "working" if not task.is_empty() else "idle", "target": task.get("target", ""),
			"left": task.get("left", 0), "done": done[t],
		}
	return {"teams": teams, "queue": queue()}


func id_detail() -> Dictionary:
	var out := {}
	for t: String in TEAMS:
		var task: Dictionary = tasks.get(t, {})
		out[t] = {"state": "working" if not task.is_empty() else "idle", "target": task.get("target", ""), "left": task.get("left", 0)}
	return out
