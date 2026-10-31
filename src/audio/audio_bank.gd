extends RefCounted
## Scene-free: what each cue is, and whether it may play now. Keeps its own clock so a cooldown means the
## same thing in a test as in the game. data/audio.json "cues".

const SoundRules := preload("res://src/audio/sound_rules.gd")

var cues: Dictionary
var groups: Dictionary
var now := 0.0

var _ready_at := {}
var _robins := {}


func _init(config: Dictionary) -> void:
	cues = config.cues
	groups = config.get("groups", {})
	for g: String in groups:
		_robins[g] = SoundRules.RoundRobin.new((groups[g].cues as Array).size())


func has(cue: String) -> bool:
	return cues.has(cue)


func is_group(name: String) -> bool:
	return groups.has(name)


## True if the group as a whole is off its cooldown (a voice or a rattle that mustn't chatter).
func take_group(group: String) -> bool:
	if now < float(_ready_at.get(group, 0.0)):
		return false
	_ready_at[group] = now + float(groups[group].get("cooldown_s", 0.0))
	return true


## The next variant: round-robin, in a new order each time round, never the same one twice in a row.
func next_in_group(group: String, rng: RandomNumberGenerator) -> String:
	return String(groups[group].cues[_robins[group].next(rng)])


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


## The cue's own ± level, in dB, if it has one.
func volume_jitter(cue: String, rng: RandomNumberGenerator) -> float:
	var v := float(spec(cue).get("volume_jitter_db", 0.0))
	return rng.randf_range(-v, v) if v > 0.0 else 0.0


func reset() -> void:
	now = 0.0
	_ready_at = {}
