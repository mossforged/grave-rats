extends RefCounted
## Scene-free: what each cue is, and whether it may play now. Keeps its own clock so a cooldown means the
## same thing in a test as in the game. data/audio.json "cues".

var cues: Dictionary
var now := 0.0

var _ready_at := {}


func _init(config: Dictionary) -> void:
	cues = config.cues


func has(cue: String) -> bool:
	return cues.has(cue)


func spec(cue: String) -> Dictionary:
	return cues[cue]


func positional(cue: String) -> bool:
	return float(spec(cue).max_distance_m) > 0.0


func advance(delta: float) -> void:
	now += delta


## True if it's off cooldown, and starts the cooldown. A cue that isn't in the bank never plays.
func take(cue: String) -> bool:
	if not has(cue) or now < float(_ready_at.get(cue, 0.0)):
		return false
	_ready_at[cue] = now + float(spec(cue).cooldown_s)
	return true


func pitch_for(cue: String, rng: RandomNumberGenerator) -> float:
	var v := float(spec(cue).pitch_variance)
	return rng.randf_range(1.0 - v, 1.0 + v)


func reset() -> void:
	now = 0.0
	_ready_at = {}
