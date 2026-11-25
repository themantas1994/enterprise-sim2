class_name ShipSystem
extends RefCounted
## Base class of the NCC-1701-D ship systems (ADR 0002). A system reads the previous tick's snapshot, queues
## commands for the generic sim through the runtime, and offers a detail section for the ship snapshot.
## `rt` is the owning ShipRuntime (untyped on purpose: the runtime also references every system class).

var rt: Variant = null


func setup(runtime: Variant) -> void:
	rt = runtime


## Called once per tick before the sim step, with the snapshot of the previous tick.
func update(_snap: Dictionary) -> void:
	pass


## Called once per tick right after the sim step, with the fresh snapshot (events of this tick included).
func post(_snap: Dictionary) -> void:
	pass


## Ship command hook. Returns null when the command is not this system's, else {accepted, reason?}.
func handle(_cmd: Dictionary, _snap: Dictionary) -> Variant:
	return null


## Section for snapshot().ship[<name>].
func section() -> Dictionary:
	return {}


## Extra per-id fields for snapshot().ship.detail[<id>].
func id_detail() -> Dictionary:
	return {}


static func ok() -> Dictionary:
	return {"accepted": true}


static func no(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
