extends RefCounted
## Scene-free rules behind a few cues: when a foot lands, how hard the suit breathes, how far through a
## reload and how far up the cutter's hum. data/audio.json.

## Metres walked since the last footfall: true when another foot lands.
class StepClock:
	var _walked := 0.0

	func advance(metres: float, stride_m: float) -> bool:
		_walked += metres
		if _walked < stride_m:
			return false
		_walked = fmod(_walked, stride_m)
		return true

	func reset() -> void:
		_walked = 0.0


## Hands out 0..count-1: every one once, in a new order each time round, never the same twice in a row.
class RoundRobin:
	var _deck: Array[int] = []
	var _at := 0

	func _init(count: int) -> void:
		for i in count:
			_deck.append(i)
		_at = count

	func next(rng: RandomNumberGenerator) -> int:
		if _at >= _deck.size():
			var last := _deck[-1]
			for i in range(_deck.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var hold := _deck[i]
				_deck[i] = _deck[j]
				_deck[j] = hold
			if _deck[0] == last and _deck.size() > 1:
				_deck[0] = _deck[1]
				_deck[1] = last
			_at = 0
		_at += 1
		return _deck[_at - 1]


## Heavy fire pushes the ambience down, and it comes back once the firing stops. "ambience_duck" in data.
class Duck:
	var _heat := 0.0
	var _level := 0.0

	func note_shot(cfg: Dictionary) -> void:
		_heat += 1.0
		if _heat >= float(cfg.heavy_shots):
			_level = 1.0

	func step(delta: float, cfg: Dictionary) -> void:
		_heat = maxf(_heat - float(cfg.heat_decay_per_s) * delta, 0.0)
		if _heat < float(cfg.heavy_shots):
			_level = maxf(_level - delta / float(cfg.recover_s), 0.0)

	func db(cfg: Dictionary) -> float:
		return float(cfg.db) * _level

	func reset() -> void:
		_heat = 0.0
		_level = 0.0


## How a sound reaches you: {bus, extra_db, tail_db}. Further is duller and has more room in it. Behind a wall
## it's muffled whatever the range. "distance_mix" in data.
static func distance_mix(cfg: Dictionary, distance_m: float, occluded: bool) -> Dictionary:
	if occluded:
		return cfg.occluded
	var at: Dictionary = cfg.bands[0]
	for b: Dictionary in cfg.bands:
		if distance_m >= float(b.from_m):
			at = b
	return {"bus": at.bus, "extra_db": 0.0, "tail_db": at.tail_db}


## Which layers of "gun" one shot plays, by name. `rounds_left` is what's in the magazine after it went off.
## `local`: the shot is the local player's own.
static func shot_layers(gun: Dictionary, rounds_left: int, local: bool) -> Array:
	var out: Array = [gun.mechanical, gun.body]
	if local:
		out.append(gun.thump)
		if rounds_left < int(gun.last_rounds):
			out.append(gun.last_rounds_cue)
	return out


## Which gait a body is in, for "footsteps.gaits".
static func gait(crouched: bool, sprinting: bool) -> String:
	if sprinting:
		return "sprint"
	return "crouch" if crouched else "walk"


## 0 is calm, 1 is as frightened as a suit gets: whichever of suit and oxygen is worse below its line.
static func breath_stress(cfg: Dictionary, suit: float, oxygen: float) -> float:
	var from_suit := 1.0 - clampf(suit / float(cfg.low_suit), 0.0, 1.0)
	var from_air := 1.0 - clampf(oxygen / float(cfg.low_oxygen), 0.0, 1.0)
	return maxf(from_suit, from_air)


## Stages crossed as a reload went from `before` to `after`: "reload_stages" entries, in order.
static func stages_crossed(stages: Array, before: float, after: float) -> Array:
	var out: Array = []
	for s: Dictionary in stages:
		if before < float(s.at) and after >= float(s.at):
			out.append(s)
	return out


## The hum's pitch for how full the ring is, 0..1.
static func warm_pitch(cfg: Dictionary, share: float) -> float:
	return lerpf(float(cfg.pitch_from), float(cfg.pitch_to), clampf(share, 0.0, 1.0))


## The drone's chirp for this bar (from 1).
static func chirp_pitch(cfg: Dictionary, bar: int) -> float:
	return 1.0 + float(cfg.pitch_step) * float(bar - 1)


## One crossfade between room tones. `shares` is cue -> 0..1; the room you're in rises, the rest fall.
static func fade_rooms(shares: Dictionary, current: String, delta: float, fade_s: float) -> void:
	var rate := delta / maxf(fade_s, delta)
	for cue: String in shares:
		shares[cue] = move_toward(float(shares[cue]), 1.0 if cue == current else 0.0, rate)
