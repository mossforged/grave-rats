extends RefCounted
## Scene-free rules of a bed that tips: upright (no cover), tipping (a commitment, still no
## cover), overturned (low cover). Numbers from data/cover.json "bed".

const CoverField := preload("res://src/cover/cover_field.gd")

enum State { UPRIGHT, TIPPING, OVERTURNED }

var cfg: Dictionary
var state := State.UPRIGHT
var progress := 0.0  # 0 upright, 1 lying
var side := 1.0      # which way across its long axis it falls


func _init(config: Dictionary, overturned := false, fall_side := 1.0) -> void:
	cfg = config
	side = fall_side
	if overturned:
		state = State.OVERTURNED
		progress = 1.0


## E pressed by someone at `from_side` of the bed (sign across its long axis): it falls away
## from them. False when it's already going or gone.
func start(from_side: float) -> bool:
	if state != State.UPRIGHT:
		return false
	side = -1.0 if from_side > 0.0 else 1.0
	state = State.TIPPING
	return true


## True on the step it lands.
func step(delta: float) -> bool:
	if state != State.TIPPING:
		return false
	progress = minf(progress + delta / float(cfg.tip_s), 1.0)
	if progress >= 1.0:
		state = State.OVERTURNED
		return true
	return false


func cover_class() -> String:
	return CoverField.LOW if state == State.OVERTURNED else CoverField.NONE


## The footprint now: upright it's `rect`; lying it stands just past the far long edge, as thick
## as the bed was high. `thickness` is the bed's upright height.
func footprint(rect: Rect2, thickness: float) -> Rect2:
	if state != State.OVERTURNED:
		return rect
	if rect.size.y >= rect.size.x:
		var x := rect.end.x if side > 0.0 else rect.position.x - thickness
		return Rect2(x, rect.position.y, thickness, rect.size.y)
	var z := rect.end.y if side > 0.0 else rect.position.y - thickness
	return Rect2(rect.position.x, z, rect.size.x, thickness)
