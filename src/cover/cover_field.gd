extends RefCounted
## Scene-free cover: footprints with a class (none, low, tall) and a straight 3D trace against
## their height. Points are Vector3 in world metres. Numbers from data/cover.json.
## Low cover stands `low_height_m` whatever its mesh, so the rule stays one number; tall has no top.

const NONE := "none"
const LOW := "low"
const TALL := "tall"

var cfg: Dictionary
var _pieces := {}  # id -> {rect: Rect2, kind: String}


func _init(config: Dictionary) -> void:
	cfg = config


## Adds, moves or reclassifies a piece. Class "none" takes it out.
func set_piece(id: Variant, rect: Rect2, kind: String) -> void:
	if kind == NONE:
		_pieces.erase(id)
	else:
		_pieces[id] = {"rect": rect, "kind": kind}


func kind_of(id: Variant) -> String:
	return String(_pieces[id].kind) if _pieces.has(id) else NONE


func height_of(kind: String) -> float:
	match kind:
		LOW:
			return float(cfg.low_height_m)
		TALL:
			return INF
	return 0.0


## First piece the segment enters: {t (0..1), point, id, kind}, or {} when it is clear.
func segment_hit(a: Vector3, b: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	for id: Variant in _pieces:
		var p: Dictionary = _pieces[id]
		var t := _enter_t(a, b, p.rect, height_of(p.kind))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"t": t, "point": a.lerp(b, t), "id": id, "kind": p.kind}
	return best


func line_blocked(a: Vector3, b: Vector3) -> bool:
	return not segment_hit(a, b).is_empty()


## Slabs: where the segment enters the box over `r` from the floor to `top`, or -1.
static func _enter_t(a: Vector3, b: Vector3, r: Rect2, top: float) -> float:
	var span := Vector2(0.0, 1.0)
	span = _slab(span, a.x, b.x, r.position.x, r.end.x)
	span = _slab(span, a.y, b.y, 0.0, top)
	span = _slab(span, a.z, b.z, r.position.y, r.end.y)
	return span.x if span.x <= span.y else -1.0


## Narrows the segment's (enter, leave) to where it's between `lo` and `hi` on one axis.
static func _slab(span: Vector2, from: float, to: float, lo: float, hi: float) -> Vector2:
	var d := to - from
	if d == 0.0:
		return span if from >= lo and from <= hi else Vector2(1.0, 0.0)
	var near := (lo - from) / d
	var far := (hi - from) / d
	return Vector2(maxf(span.x, minf(near, far)), minf(span.y, maxf(near, far)))


## Height of the torso a shot at this body aims for. `crouch_amount` is OperatorModel's;
## `braced` means firing from a crouch, which raises you over low cover.
func torso_height(crouch_amount: float, braced: bool) -> float:
	if braced and crouch_amount > 0.0:
		return float(cfg.braced_torso_m)
	return lerpf(float(cfg.standing_torso_m), float(cfg.crouched_torso_m), crouch_amount)
