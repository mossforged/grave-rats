extends Node3D
## One bed that tips over with E: TipState plus mesh, collision and its place in the cover field.
## It lands past its far long edge with the plated underside facing away from whoever tipped it.

const TipState := preload("res://src/cover/tip_state.gd")
const KitPieces := preload("res://src/kit/kit_pieces.gd")

signal landed(bed: Node3D)
signal footprint_changed(bed: Node3D)

var tip: TipState
var cfg: Dictionary
var upright_rect := Rect2()
var cover: RefCounted

var _spec: Dictionary
var _size := Vector3.ZERO
var _along_z := true
var _pivot: Node3D
var _mesh: MeshInstance3D
var _body: StaticBody3D
var _shape: BoxShape3D


## `spec` is the data/deck.json prop, `rect` its footprint.
func setup(spec: Dictionary, rect: Rect2, cover_field: RefCounted, config: Dictionary) -> void:
	cfg = config
	cover = cover_field
	_spec = spec
	upright_rect = rect
	_size = Vector3(float(spec.size_m[0]), float(spec.size_m[1]), float(spec.size_m[2]))
	_along_z = rect.size.y >= rect.size.x
	name = "TipBed"
	_build()
	reset()


func reset() -> void:
	tip = TipState.new(cfg, bool(_spec.get("overturned", false)), float(_spec.get("tip_side", 1)))
	_apply_footprint()
	_apply_pose()


func _build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = KitPieces.prop("bed", Vector3(_across(), _size.y, _long()))
	# The file is long in Z; a bed lying east-west turns it, so it stays long along the bed.
	_mesh.rotation.y = 0.0 if _along_z else PI * 0.5
	_pivot.add_child(_mesh)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_shape = BoxShape3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	_body.add_child(cs)
	add_child(_body)


func _across() -> float:
	return upright_rect.size.x if _along_z else upright_rect.size.y


func _long() -> float:
	return upright_rect.size.y if _along_z else upright_rect.size.x


## A point `offset` across the bed from its middle, on the side it falls to when positive.
func _across_from_middle(offset: float) -> Vector2:
	var c := upright_rect.get_center()
	return Vector2(c.x + offset * tip.side, c.y) if _along_z else Vector2(c.x, c.y + offset * tip.side)


## Where the mesh is. The hinge starts on the near long edge and ends a bed's height past the far one:
## the far edge rears up and the bed rides over, so it lands on TipState's footprint with the mattress
## toward whoever tipped it and the plated underside out, as the shield.
func _apply_pose() -> void:
	var s := smoothstep(0.0, 1.0, tip.progress)
	var half := _across() * 0.5
	var hinge := _across_from_middle(lerpf(-half, half + _size.y, s))
	_pivot.global_position = Vector3(hinge.x, 0.0, hinge.y)
	var a := s * PI * 0.5 * tip.side
	_pivot.basis = Basis(Vector3.BACK, a) if _along_z else Basis(Vector3.RIGHT, -a)
	var middle := half * tip.side
	_mesh.position = Vector3(middle, 0.0, 0.0) if _along_z else Vector3(0.0, 0.0, middle)


func _apply_footprint() -> void:
	var r := footprint()
	var h := float(cfg.lying_height_m) if tip.state == TipState.State.OVERTURNED else _size.y
	_shape.size = Vector3(r.size.x, h, r.size.y)
	var c := r.get_center()
	_body.global_position = Vector3(c.x, h * 0.5, c.y)
	cover.set_piece(self, r, tip.cover_class())
	footprint_changed.emit(self)


func footprint() -> Rect2:
	return tip.footprint(upright_rect, _size.y)


func can_tip() -> bool:
	return tip.state == TipState.State.UPRIGHT


## E from `p`. It falls away from `p`. Returns true if it started.
func try_tip(p: Vector2) -> bool:
	var c := upright_rect.get_center()
	if not tip.start(p.x - c.x if _along_z else p.y - c.y):
		return false
	_apply_pose()
	return true


func distance_to_point(p: Vector2) -> float:
	var r := upright_rect
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)).distance_to(p)


func tick(delta: float) -> void:
	if tip.state != TipState.State.TIPPING:
		return
	var done := tip.step(delta)
	_apply_pose()
	if done:
		_apply_footprint()
		landed.emit(self)
