extends RefCounted
## Scene-free choices for the hauler's clips, so they run headless on numbers: which way the legs go, which
## gait at what share and rate, which hit react and which death. Numbers from data/hauler_anim.json.
## A direction here is the leg blend's: x right, y forward, relative to the body.

const EIGHT := ["fwd", "fwd_right", "right", "back_right", "back", "back_left", "left", "fwd_left"]
const DIAGONAL := 0.7071068


## Where each direction's clip sits in a blend space.
static func point(dir_name: String) -> Vector2:
	match dir_name:
		"fwd": return Vector2(0, 1)
		"fwd_right": return Vector2(DIAGONAL, DIAGONAL)
		"right": return Vector2(1, 0)
		"back_right": return Vector2(DIAGONAL, -DIAGONAL)
		"back": return Vector2(0, -1)
		"back_left": return Vector2(-DIAGONAL, -DIAGONAL)
		"left": return Vector2(-1, 0)
		"fwd_left": return Vector2(-DIAGONAL, DIAGONAL)
	return Vector2.ZERO


## The closest of the eight directions.
static func nearest(dir: Vector2) -> String:
	var best := ""
	var most := -INF
	for n: String in EIGHT:
		var d := point(n).dot(dir.normalized())
		if d > most:
			most = d
			best = n
	return best


## The leg blend is relative to the torso, the legs are drawn on the hips, `lead` (rad) behind it.
static func on_hips(blend: Vector2, lead: float) -> Vector2:
	return blend.rotated(-lead)


## A gait's clip speed in a direction (m/s), between the clips either side of it. `speeds` holds some of the eight.
static func clip_speed(speeds: Dictionary, dir: Vector2) -> float:
	if dir.is_zero_approx():
		return float(speeds.get("fwd", 1.0))
	var unit := dir.normalized()
	var first := ""
	var second := ""
	var first_at := INF
	var second_at := INF
	for n: String in speeds:
		var off := acos(clampf(point(n).dot(unit), -1.0, 1.0))
		if off < first_at:
			second = first
			second_at = first_at
			first = n
			first_at = off
		elif off < second_at:
			second = n
			second_at = off
	if second == "" or first_at < 0.001:
		return float(speeds[first])
	return lerpf(float(speeds[first]), float(speeds[second]), first_at / (first_at + second_at))


## Sprint clips exist forward, left and right. Heading backward the run clips carry the speed instead.
static func sprint_dir(dir: Vector2) -> Vector2:
	if dir.y >= 0.0:
		return dir.normalized() if not dir.is_zero_approx() else Vector2(0, 1)
	var flat := Vector2(dir.x, 0.0)
	return flat.normalized() if not flat.is_zero_approx() else Vector2(0, 1)


## This step's shares and clip rates. `sprint_share` is the smoothed 0..1 of the sprint. Every gait's rate comes
## from one stride frequency, so clips of different lengths stay in step while they blend.
## {moving, run, sprint, walk_rate, run_rate, sprint_rate}.
static func gaits(cfg: Dictionary, dir: Vector2, speed: float, sprint_share: float, max_rate: float) -> Dictionary:
	var unit := dir.normalized() if not dir.is_zero_approx() else Vector2(0, 1)
	var speeds: Dictionary = cfg.speeds_m_s
	var cycle: Dictionary = cfg.cycle_s
	var from := float(cfg.walk_up_to_m_s)
	var to := float(cfg.run_from_m_s)
	var run := clampf((speed - from) / maxf(to - from, 0.001), 0.0, 1.0)
	var sprint := sprint_share if unit.y >= float(cfg.sprint_back_limit) else 0.0
	var stride_walk: float = clip_speed(speeds.walk, unit) * float(cycle.walk)
	var stride_run: float = clip_speed(speeds.run, unit) * float(cycle.run)
	var stride_sprint: float = clip_speed(speeds.sprint, sprint_dir(unit)) * float(cycle.sprint)
	var stride := lerpf(lerpf(stride_walk, stride_run, run), stride_sprint, sprint)
	var main_cycle := lerpf(lerpf(float(cycle.walk), float(cycle.run), run), float(cycle.sprint), sprint)
	var freq := speed / maxf(stride, 0.001)
	freq = minf(freq, max_rate / maxf(main_cycle, 0.001))
	return {"moving": clampf(speed / maxf(float(cfg.idle_fade_m_s), 0.001), 0.0, 1.0), "run": run, "sprint": sprint,
		"walk_rate": freq * float(cycle.walk), "run_rate": freq * float(cycle.run), "sprint_rate": freq * float(cycle.sprint)}


## Rate for a clip walking at `clip_m_s` to cover the ground at `speed`.
static func rate_for(speed: float, clip_m_s: float, max_rate: float) -> float:
	return minf(speed / maxf(clip_m_s, 0.001), max_rate)


## Where a blow came from against where the body faces: "front", "back", "left" or "right". `from` is the
## flat direction to whatever hit it (x, z in the world), `yaw` the body's facing (yaw 0 faces -Z).
static func side(from: Vector2, yaw: float, front_cos: float) -> String:
	if from.is_zero_approx():
		return "front"
	var unit := from.normalized()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var ahead := unit.dot(fwd)
	if ahead >= front_cos:
		return "front"
	if ahead <= -front_cos:
		return "back"
	return "right" if unit.dot(right) > 0.0 else "left"


## The react for a blow. A head hit wins, then a gun in use, then the side it came from.
static func hit_state(blow_side: String, high: bool, shouldered: bool) -> String:
	if high:
		return "hit_head"
	return "hit_rifle" if shouldered else "hit_" + blow_side


## The death for a last blow. No blow known (air, a puddle): the plain one. Shot from behind you go forward,
## from the front backward, from the side the plain one.
static func death_state(blow_side: String, high: bool) -> String:
	if high:
		return "death_headshot"
	match blow_side:
		"back": return "death_forward"
		"front": return "death_backward"
	return "death"
