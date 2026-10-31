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
