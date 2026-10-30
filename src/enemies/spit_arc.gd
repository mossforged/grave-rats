extends RefCounted
## Scene-free glob: an arc from the mouth to the aim point, high and lobbed at short range, nearly
## flat at long range, which is why low cover stops it far away and not up close.
## Numbers from data/enemies.json "stalker.spit". The aim point stays where it was at release.

const FLYING := "flying"
const COVER := "cover"     # stopped by cover
const WALL := "wall"       # stopped by a wall or door
const HIT := "hit"         # reached the body
const LANDED := "landed"   # reached the aim point

var cfg: Dictionary
var from: Vector3
var to: Vector3
var apex := 0.0
var flight_s := 0.0
var elapsed := 0.0
var position := Vector3.ZERO


func _init(config: Dictionary, from_point: Vector3, to_point: Vector3) -> void:
	cfg = config
	from = from_point
	to = to_point
	position = from
	var d := flat_distance(from, to)
	apex = apex_for(cfg, d)
	flight_s = maxf(d / float(cfg.speed_m_s), float(cfg.min_flight_s))


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func apex_for(config: Dictionary, distance: float) -> float:
	var s := float(config.short_range_m)
	var l := float(config.long_range_m)
	return lerpf(float(config.apex_short_m), float(config.apex_long_m), clampf((distance - s) / (l - s), 0.0, 1.0))


## Where the glob is at `s` (0 mouth, 1 aim point).
func point_at(s: float) -> Vector3:
	var p := from.lerp(to, s)
	p.y += apex * 2.0 * 2.0 * s * (1.0 - s)  # a parabola whose top is `apex` above the line
	return p


## Would this arc reach its aim point past `cover`? Used for the HUD's per-shooter mark.
static func blocked_by_cover(config: Dictionary, cover: RefCounted, from_point: Vector3, to_point: Vector3) -> bool:
	var arc = new(config, from_point, to_point)
	var n := int(config.arc_samples)
	var prev: Vector3 = from_point
	for i in range(1, n + 1):
		var q: Vector3 = arc.point_at(float(i) / n)
		if cover.line_blocked(prev, q):
			return true
		prev = q
	return false


## One step. `plan_blocked(a2, b2)` answers for walls and doors on the floor plan; `body` is the
## target's torso right now. Returns one of the words above; `position` is where it ended.
func step(delta: float, cover: RefCounted, plan_blocked: Callable, body: Vector3) -> String:
	elapsed = minf(elapsed + delta, flight_s)
	var prev := position
	var next := point_at(elapsed / flight_s)
	var hit: Dictionary = cover.segment_hit(prev, next)
	if not hit.is_empty():
		position = hit.point
		return COVER
	if plan_blocked.call(Vector2(prev.x, prev.z), Vector2(next.x, next.z)):
		position = prev
		return WALL
	position = next
	var near := flat_distance(next, body) <= float(cfg.hit_radius_m)
	if near and next.y <= body.y + float(cfg.body_margin_m):
		return HIT
	return LANDED if elapsed >= flight_s else FLYING
