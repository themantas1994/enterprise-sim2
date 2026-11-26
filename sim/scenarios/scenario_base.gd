class_name ScenarioBase
extends RefCounted
## Base class of the scenarios (ADR 0002). The runtime calls setup(runtime) once, then update(runtime) once per
## tick (after the sim step and the ship systems) until `status` leaves RUNNING; after that the status is final.
## `tick` counts the ticks since start. Every threshold and timer a scenario uses is a ship-file tuning value
## under systems.<scenario id> (all marked estimate there).

const RUNNING := "running"
const WON := "won"
const LOST := "lost"

var id: String = ""
var title: String = ""
var brief: String = ""
var status: String = RUNNING
var reason: String = ""
var tick: int = 0


func setup(_runtime: Variant) -> void:
	pass


func update(_runtime: Variant) -> void:
	pass


## Ticks left until the scenario ends by itself, or -1 when it has no timer.
func time_left() -> int:
	return -1


func win(why: String) -> void:
	if status == RUNNING:
		status = WON
		reason = why


func lose(why: String) -> void:
	if status == RUNNING:
		status = LOST
		reason = why
