class_name UiStatus
extends RefCounted
## Era-independent status levels. Widgets show a level by colour AND by marker shape, so no state relies on
## colour alone (PLAN section 6).

const OK := "ok"
const INFO := "info"
const CAUTION := "caution"
const ALARM := "alarm"
const OFF := "off"

const STATE_LEVEL := {
	"ok": OK, "online": OK, "standby": OK, "restored": OK,
	"partial": CAUTION, "startup": CAUTION, "overload": CAUTION, "shed": CAUTION,
	"unpowered": ALARM, "cut": ALARM, "containment_failing": ALARM, "breach": ALARM, "destroyed": ALARM,
	"cold": OFF, "ejected": OFF,
}
const SEVERITY := {OFF: 0, OK: 1, INFO: 1, CAUTION: 2, ALARM: 3}


static func worse(a: String, b: String) -> String:
	return a if SEVERITY.get(a, 1) >= SEVERITY.get(b, 1) else b


## Level of one snapshot component: the worse of its state and its integrity.
static func level_of(comp: Dictionary) -> String:
	if comp.is_empty():
		return INFO
	var level: String = STATE_LEVEL.get(str(comp.get("state", "")), INFO)
	var integrity := float(comp.get("integrity", 100.0))
	if integrity < 25.0:
		level = worse(level, ALARM)
	elif integrity < 75.0:
		level = worse(level, CAUTION)
	return level


## Off-nominal means caution or alarm; cold and ejected parts are idle, not faulty.
static func is_nominal(comp: Dictionary) -> bool:
	var level := level_of(comp)
	return level != CAUTION and level != ALARM


## "antimatter_pod_01" -> "ANTIMATTER POD 01".
static func pretty(id: String) -> String:
	return id.replace("_", " ").to_upper()


static func clock(ticks: float) -> String:
	var secs := int(maxf(0.0, ticks) * 0.1)
	return "%02d:%02d" % [secs / 60, secs % 60]
