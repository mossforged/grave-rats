extends RefCounted
## Scene-free: when CUSTODIAN speaks. Calm, at state changes, and never every attack: each event rests for
## its own cooldown and all of them for the shared one. An urgent line (it just woke) doesn't wait, but
## it still starts the wait for the next. data/custodian.json "voice".

var cfg: Dictionary

var _shared := 0.0
var _rests := {}


func _init(config: Dictionary) -> void:
	cfg = config


func reset() -> void:
	_shared = 0.0
	_rests = {}


func step(delta: float) -> void:
	_shared = maxf(_shared - delta, 0.0)
	for key: String in _rests.keys():
		_rests[key] = maxf(float(_rests[key]) - delta, 0.0)


## The line to say for this event, or "" if it should keep quiet for now.
func say(event: String) -> String:
	var line: Dictionary = cfg.lines[event]
	var urgent := bool(line.get("urgent", false))
	if not urgent and (_shared > 0.0 or float(_rests.get(event, 0.0)) > 0.0):
		return ""
	_shared = float(cfg.global_cooldown_s)
	_rests[event] = float(line.cooldown_s)
	return String(line.text)
