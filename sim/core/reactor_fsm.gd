class_name ReactorFsm
extends RefCounted
## Generic reactor state machine, operating on a producer component dictionary with reactor = true.
##
## States: cold, startup, standby, online, overload, containment_failing, breach, ejected.
## Output: only online and overload deliver power (capacity = max_output * efficiency).
## Commands (all take target = reactor id):
##   reactor_start     cold -> startup; after startup_ticks steps -> standby (automatic)
##   reactor_online    standby -> online
##   reactor_shutdown  startup, standby, online or overload -> cold
##   reactor_eject     ALLOWED ONLY from online, overload, containment_failing -> ejected (terminal);
##                     removes the reactor from the grid and can no longer breach. Any other state is rejected.
## Automatic transitions, evaluated once per tick after heat is updated (load = output / rated):
##   online -> overload               load > overload_load, or temp > overload_temp, or integrity <= critical_integrity
##   overload -> containment_failing  temp >= critical_temp or integrity <= critical_integrity;
##                                    countdown = breach_ticks
##   overload -> online (recovery)    load <= overload_load and temp <= recover_temp and integrity > critical_integrity
##   containment_failing -> breach    countdown reaches 0: it drops by 1 each tick after entry, so the breach
##                                    happens exactly breach_ticks ticks after the entry event
## breach and ejected are terminal. On breach the caller applies breach_damage to connected components.
## Events: {type="reactor_state", id, from, to, tick} on every transition, plus {type="breach", id, tick}.

const STATES := ["cold", "startup", "standby", "online", "overload", "containment_failing", "breach", "ejected"]
const EJECT_ALLOWED := ["online", "overload", "containment_failing"]
const SHUTDOWN_ALLOWED := ["startup", "standby", "online", "overload"]
const COMMANDS := ["reactor_start", "reactor_online", "reactor_shutdown", "reactor_eject"]


static func provides_power(c: Dictionary) -> bool:
	return c["state"] == "online" or c["state"] == "overload"


## True while the reactor still physically exists on the grid.
static func present(c: Dictionary) -> bool:
	return c["state"] != "breach" and c["state"] != "ejected"


## Applies a reactor command. Returns "" on success or the rejection reason.
static func command(c: Dictionary, type: String, tick: int, events: Array) -> String:
	var st: String = c["state"]
	match type:
		"reactor_start":
			if st != "cold":
				return "start requires cold, state is " + st
			c["startup_left"] = c["startup_ticks"]
			_enter(c, "startup", tick, events)
		"reactor_online":
			if st != "standby":
				return "bring online requires standby, state is " + st
			_enter(c, "online", tick, events)
		"reactor_shutdown":
			if not SHUTDOWN_ALLOWED.has(st):
				return "shutdown not allowed in " + st
			c["countdown"] = 0
			c["startup_left"] = 0
			_enter(c, "cold", tick, events)
		"reactor_eject":
			if not EJECT_ALLOWED.has(st):
				return "eject not allowed in " + st
			c["countdown"] = 0
			_enter(c, "ejected", tick, events)
		_:
			return "unknown reactor command"
	return ""


static func step(c: Dictionary, tick: int, events: Array) -> void:
	var load_value: float = c["load"]
	match c["state"]:
		"startup":
			c["startup_left"] -= 1
			if c["startup_left"] <= 0:
				_enter(c, "standby", tick, events)
		"online":
			if load_value > c["overload_load"] or c["temp"] > c["overload_temp"] or c["integrity"] <= c["critical_integrity"]:
				_enter(c, "overload", tick, events)
		"overload":
			if c["temp"] >= c["critical_temp"] or c["integrity"] <= c["critical_integrity"]:
				c["countdown"] = c["breach_ticks"]
				_enter(c, "containment_failing", tick, events)
			elif load_value <= c["overload_load"] and c["temp"] <= c["recover_temp"]:
				_enter(c, "online", tick, events)
		"containment_failing":
			c["countdown"] -= 1
			if c["countdown"] <= 0:
				c["countdown"] = 0
				_enter(c, "breach", tick, events)
				events.append({"type": "breach", "id": c["id"], "tick": tick})


static func _enter(c: Dictionary, to: String, tick: int, events: Array) -> void:
	events.append({"type": "reactor_state", "id": c["id"], "from": c["state"], "to": to, "tick": tick})
	c["state"] = to
