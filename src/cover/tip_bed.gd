extends Node3D
## One bed that tips over with E: TipState plus mesh, collision and its place in the cover field.
## The mesh hinges on the far long edge, so the top ends up facing away from whoever tipped it.

const TipState := preload("res://src/cover/tip_state.gd")

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
	var w := _across()
	var m := float(cfg.mattress_m)
	_add_slab("Frame", Vector3(w, _size.y - m, _long()), (_size.y - m) * 0.5, cfg.color)
	_add_slab("Mattress", Vector3(w, m, _long()), _size.y - m * 0.5, cfg.mattress_color)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_shape = BoxShape3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	_body.add_child(cs)
	add_child(_body)


func _add_slab(slab_name: String, size: Vector3, y: float, hex: Variant) -> void:
	var mi := MeshInstance3D.new()
	mi.name = slab_name
	var box := BoxMesh.new()
	# The slab's x runs across the bed in the pivot's frame, whichever way the bed lies.
	box.size = size if _along_z else Vector3(size.z, size.y, size.x)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(hex))
	box.material = mat
	mi.mesh = box
	mi.position.y = y
	_pivot.add_child(mi)


func _across() -> float:
	return upright_rect.size.x if _along_z else upright_rect.size.y


func _long() -> float:
	return upright_rect.size.y if _along_z else upright_rect.size.x


func _far_edge() -> Vector2:
	var c := upright_rect.get_center()
	var half := _across() * 0.5 * tip.side
	return Vector2(c.x + half, c.y) if _along_z else Vector2(c.x, c.y + half)


## Where the mesh is: the hinge on the far edge, the slabs offset back across the bed.
func _apply_pose() -> void:
	var edge := _far_edge()
	_pivot.global_position = Vector3(edge.x, 0.0, edge.y)
	var a := smoothstep(0.0, 1.0, tip.progress) * PI * 0.5 * tip.side
	_pivot.basis = Basis(Vector3.BACK, -a) if _along_z else Basis(Vector3.RIGHT, a)
	var back := -_across() * 0.5 * tip.side
	for child: Node in _pivot.get_children():
		var mi := child as MeshInstance3D
		if _along_z:
			mi.position.x = back
		else:
			mi.position.z = back


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
