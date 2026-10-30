extends RefCounted
## Scene-free: where a pirate can go. Slots along every piece of cover, the ones that hide you from
## a threat and still let you fire at it (over low cover, or round the side of tall), and flank
## spots: anywhere with an open line on a crouched player, well off the suppressor's angle.

var cfg: Dictionary          # data/pirates.json "spots"
var cover: RefCounted
var muzzle_m := 0.0
var slots: Array = []        # {at: Vector2, kind: String, id, peeks: Array[Vector2]}

var _plan_blocked: Callable  # (a: Vector2, b: Vector2) -> bool: walls, shut doors, tall cover
var _path: Callable          # (a: Vector2, b: Vector2) -> PackedVector2Array
var _is_free: Callable       # (p: Vector2) -> bool


func _init(config: Dictionary, cover_field: RefCounted, pieces: Array, radius: float, muzzle: float,
		is_free: Callable, plan_blocked: Callable, path: Callable) -> void:
	cfg = config
	cover = cover_field
	muzzle_m = muzzle
	_is_free = is_free
	_plan_blocked = plan_blocked
	_path = path
	for i in pieces.size():
		var kind := String(pieces[i].cover)
		if kind != "none":
			_add_slots(pieces[i].rect, kind, i, radius)


func _add_slots(r: Rect2, kind: String, id: int, radius: float) -> void:
	var off := radius + float(cfg.gap_m)
	var c := r.get_center()
	var half := r.size * 0.5
	for out: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var along := Vector2(out.y, out.x).abs()
		var edge: float = half.dot(along)
		var count := maxi(floori(edge * 2.0 / float(cfg.step_m)), 1)
		var peek_at := edge + radius + float(cfg.peek_margin_m)
		var base: Vector2 = c + out * (half.dot(out.abs()) + off)
		var peeks: Array[Vector2] = [base + along * peek_at, base - along * peek_at]
		for k in count:
			var at: Vector2 = base + along * (((k + 0.5) / count * 2.0 - 1.0) * edge)
			if _is_free.call(at):
				slots.append({"at": at, "kind": kind, "id": id, "peeks": peeks})


## The best slot against `threat`, or {} : {hide, fire, kind, id}. `taken` are other pirates' spots.
## `away_from_threat`: falling back, so further scores instead of the preferred range.
func best_cover(threat: Vector2, crouched_m: float, from: Vector2, taken: Array, away_from_threat := false) -> Dictionary:
	var ranked: Array = []
	var eye := Vector3(threat.x, muzzle_m, threat.y)
	for s: Dictionary in slots:
		var at: Vector2 = s.at
		var d := at.distance_to(threat)
		if d < float(cfg.min_range_m) or d > float(cfg.max_range_m) or _is_taken(at, taken):
			continue
		if not cover.line_blocked(eye, Vector3(at.x, crouched_m, at.y)):
			continue
		var fire := _fire_point(s, threat)
		if fire == Vector2.INF:
			continue
		var score := -from.distance_to(at) * float(cfg.travel_cost_per_m)
		if away_from_threat:
			score += d * float(cfg.away_score_per_m)
		else:
			score -= absf(d - float(cfg.prefer_range_m)) * float(cfg.range_cost_per_m)
		if s.kind == "low":
			score += float(cfg.low_score)
		ranked.append([score, {"hide": at, "fire": fire, "kind": s.kind, "id": s.id}])
	return _first_reachable(ranked, from)


## Does this spot still hide you from `threat`?
func hides(spot: Dictionary, threat: Vector2, crouched_m: float) -> bool:
	var at: Vector2 = spot.hide
	return cover.line_blocked(Vector3(threat.x, muzzle_m, threat.y), Vector3(at.x, crouched_m, at.y))


## Does a muzzle at `p` have an open line on a body `height` up at `target`?
func open_line(p: Vector2, target: Vector2, height: float) -> bool:
	if _plan_blocked.call(p, target):
		return false
	return not cover.line_blocked(Vector3(p.x, muzzle_m, p.y), Vector3(target.x, height, target.y))


## Somewhere with an open line on a crouched body at `threat`, at least flank_min_deg round from
## where `anchor` (the suppressor) sees it. Slots count too, and score for hiding you as well.
func flank_spot(threat: Vector2, crouched_m: float, from: Vector2, anchor: Vector2, taken: Array) -> Dictionary:
	var bearing := (anchor - threat).angle()
	var points: Array = []
	var n := int(cfg.flank_samples)
	for r: Variant in cfg.flank_radii_m:
		for i in n:
			points.append([threat + Vector2.from_angle(TAU * i / n) * float(r), false])
	for s: Dictionary in slots:
		if s.kind == "low":
			points.append([s.at, true])
	var ranked: Array = []
	var min_rad := deg_to_rad(float(cfg.flank_min_deg))
	for entry: Array in points:
		var p: Vector2 = entry[0]
		var d := p.distance_to(threat)
		if d < float(cfg.min_range_m) or d > float(cfg.max_range_m) or not _is_free.call(p) or _is_taken(p, taken):
			continue
		if not open_line(p, threat, crouched_m):
			continue
		var off := absf(angle_difference(bearing, (p - threat).angle()))
		if off < min_rad:
			continue
		var score := minf(off, float(cfg.flank_max_rad)) * float(cfg.flank_score_per_rad)
		score -= from.distance_to(p) * float(cfg.flank_travel_cost_per_m)
		if entry[1] and cover.line_blocked(Vector3(threat.x, muzzle_m, threat.y), Vector3(p.x, crouched_m, p.y)):
			score += float(cfg.flank_cover_score)
		ranked.append([score, {"hide": p, "fire": p, "kind": "low" if entry[1] else "none", "id": -1}])
	return _first_reachable(ranked, from, threat, float(cfg.flank_keep_off_m))


## Nowhere hides you from there? Then somewhere you can at least fire from, cover or not.
func fire_spot(threat: Vector2, from: Vector2, taken: Array) -> Dictionary:
	var ranked: Array = []
	var n := int(cfg.flank_samples)
	for r: Variant in cfg.flank_radii_m:
		for i in n:
			ranked.append(threat + Vector2.from_angle(TAU * i / n) * float(r))
	for s: Dictionary in slots:
		ranked.append(s.at)
	var scored: Array = []
	for p: Vector2 in ranked:
		var d := p.distance_to(threat)
		if d < float(cfg.min_range_m) or d > float(cfg.max_range_m) or not _is_free.call(p) or _is_taken(p, taken):
			continue
		if _plan_blocked.call(p, threat):
			continue
		var score := -from.distance_to(p) * float(cfg.travel_cost_per_m) - absf(d - float(cfg.prefer_range_m)) * float(cfg.range_cost_per_m)
		scored.append([score, {"hide": p, "fire": p, "kind": "none", "id": -1}])
	return _first_reachable(scored, from)


func _is_taken(p: Vector2, taken: Array) -> bool:
	for t: Vector2 in taken:
		if t.distance_to(p) < float(cfg.claim_m):
			return true
	return false


func _fire_point(s: Dictionary, threat: Vector2) -> Vector2:
	if s.kind == "low":
		return s.at if not _plan_blocked.call(s.at, threat) else Vector2.INF
	for p: Vector2 in s.peeks:
		if _is_free.call(p) and not _plan_blocked.call(p, threat):
			return p
	return Vector2.INF


## The best one a walk can reach. With `keep_off`, a walk that passes that close to `threat` doesn't
## count: going round you doesn't mean brushing past you.
func _first_reachable(ranked: Array, from: Vector2, threat := Vector2.ZERO, keep_off := 0.0) -> Dictionary:
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in mini(ranked.size(), int(cfg.path_tries)):
		var spot: Dictionary = ranked[k][1]
		var walk: PackedVector2Array = _path.call(from, spot.hide)
		if walk.is_empty():
			continue
		var clear := true
		for q: Vector2 in walk:
			if keep_off > 0.0 and q.distance_to(threat) < keep_off:
				clear = false
				break
		if clear:
			return spot
	return {}
