extends RefCounted
## Scene-free lock-to-cover: next to low cover a key snaps you to a slot along its edge, crouched
## and protected. Aiming over raises you to braced (exposed); lowering takes you back. You slide
## along the edge; moving away or pressing again lets go. Numbers from data/cover.json "lock".

enum State { FREE, SNAPPING, LOCKED }

var cfg: Dictionary
var state := State.FREE
var raise := 0.0                # 0 protected, 1 fully braced over the cover
var slot := Vector2.ZERO        # where the body sits now, on the line along the edge
var normal := Vector2.ZERO      # out of the cover, towards you
var tangent := Vector2.ZERO     # along the edge
var piece_id: Variant = null

var _from := Vector2.ZERO
var _snap_t := 0.0
var _edge_min := 0.0
var _edge_max := 0.0


func _init(config: Dictionary) -> void:
	cfg = config


func enabled() -> bool:
	return float(cfg.enabled) >= 0.5


func locked() -> bool:
	return state != State.FREE


## Over the cover: a shot at you finds your braced torso.
func exposed() -> bool:
	return locked() and raise >= float(cfg.exposed_at)


func can_fire() -> bool:
	return state == State.LOCKED and raise >= float(cfg.fire_at)


## Where a lock from `p` would put you, or {}. Low cover only, within reach, and the slot must be clear.
func spot_for(field: RefCounted, p: Vector2, radius: float, is_free: Callable) -> Dictionary:
	if not enabled():
		return {}
	var piece: Dictionary = field.low_near(p, float(cfg.reach_m))
	if piece.is_empty():
		return {}
	var r: Rect2 = piece.rect
	var near := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p - near
	var out := Vector2(signf(d.x), 0.0) if absf(d.x) > absf(d.y) else Vector2(0.0, signf(d.y))
	if out == Vector2.ZERO:
		return {}
	var off := radius + float(cfg.gap_m)
	var inset := float(cfg.edge_inset_m)
	var along := Vector2(0.0, 1.0) if out.x != 0.0 else Vector2(1.0, 0.0)
	var lo := minf(r.position.dot(along) + inset, r.get_center().dot(along))
	var hi := maxf(r.end.dot(along) - inset, r.get_center().dot(along))
	var line := r.end.dot(out) + off if out.x + out.y > 0.0 else r.position.dot(out) + off
	var at := _clear_slot(out * line, along, clampf(p.dot(along), lo, hi), lo, hi, radius, is_free)
	if at == Vector2.INF:
		return {}
	return {"slot": at, "normal": out, "tangent": along, "min": lo, "max": hi, "id": piece.id, "cover_center": r.get_center()}


## The clear place on the edge's line nearest `from`: something else may stand against part of it.
func _clear_slot(base: Vector2, along: Vector2, from: float, lo: float, hi: float, radius: float, is_free: Callable) -> Vector2:
	var step_m := float(cfg.search_step_m)
	var offset := 0.0
	while from + offset <= hi or from - offset >= lo:
		for pos: float in [from + offset, from - offset]:
			if pos >= lo and pos <= hi and is_free.call(base + along * pos, radius):
				return base + along * pos
		offset += step_m
	return Vector2.INF


## Starts the snap. False when there's nothing to lock to here.
func try_lock(field: RefCounted, p: Vector2, radius: float, is_free: Callable) -> bool:
	if locked():
		return false
	var spot := spot_for(field, p, radius, is_free)
	if spot.is_empty():
		return false
	slot = spot.slot
	normal = spot.normal
	tangent = spot.tangent
	piece_id = spot.id
	_edge_min = spot.min
	_edge_max = spot.max
	_from = p
	_snap_t = 0.0
	raise = 0.0
	state = State.SNAPPING
	return true


func release() -> void:
	state = State.FREE
	raise = 0.0
	piece_id = null


## One step. `wish` is the world direction the player is pushing, `wants_aim` is aiming over.
## Returns where to walk this step, along the edge. Pushing away lets go, and then it's `wish`.
func step(delta: float, wish: Vector2, wants_aim: bool) -> Vector2:
	if state == State.FREE:
		return wish
	if not enabled():
		release()
		return wish
	if state == State.SNAPPING:
		_snap_t = minf(_snap_t + delta / maxf(float(cfg.snap_s), delta), 1.0)
		if _snap_t >= 1.0:
			state = State.LOCKED
		return Vector2.ZERO
	if wish.length() > 0.0 and wish.normalized().dot(normal) >= float(cfg.release_dot):
		release()
		return wish
	var rate := float(cfg.raise_s) if wants_aim else float(cfg.lower_s)
	raise = move_toward(raise, 1.0 if wants_aim else 0.0, delta / maxf(rate, delta))
	# Up over the cover you're committed to this spot.
	if raise > 0.0 or wish.length() == 0.0:
		return Vector2.ZERO
	var along := wish.dot(tangent)
	var here := slot.dot(tangent)
	if (along > 0.0 and (here >= _edge_max or is_equal_approx(here, _edge_max))) \
			or (along < 0.0 and (here <= _edge_min or is_equal_approx(here, _edge_min))):
		return Vector2.ZERO
	return tangent * signf(along)


## Where the body belongs, given where it got to: the snap in progress, or back on the edge's line.
## Lets go if something shoved it off.
func hold_position(p: Vector2) -> Vector2:
	if state == State.SNAPPING:
		return _from.lerp(slot, _snap_t)
	if state == State.FREE:
		return p
	var on := slot + tangent * (clampf(p.dot(tangent), _edge_min, _edge_max) - slot.dot(tangent))
	if on.distance_to(p) > float(cfg.break_m):
		release()
		return p
	slot = on
	return on


## A point across the cover, for the body to face as it snaps in.
func facing_point(reach_m: float) -> Vector2:
	return slot - normal * reach_m
