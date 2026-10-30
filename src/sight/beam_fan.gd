extends RefCounted
## Scene-free visible beam: a fixed fan of rays from the muzzle, turning with the gun and clipped
## only at walls. The vertex count never changes and each ray's reach moves at a capped rate, so
## nothing in it can jump from one frame to the next. Used by the player's light and the pirates'.

const Visibility := preload("res://src/sight/visibility.gd")

var half := 0.0        # radians, the light's own half angle
var range_m := 1.0
var rate_m_s := 1.0    # how fast one ray's reach may change
var snap_m := 1.0      # the muzzle moved further than this in a step: teleport, so no easing
var apex := Vector2.ZERO
var yaw := 0.0
var reach := PackedFloat64Array()

var _want := PackedFloat64Array()
var _fresh := true


func _init(rays: int) -> void:
	reach.resize(rays)
	_want.resize(rays)


func configure(half_rad: float, range_metres: float, rate: float, snap: float) -> void:
	half = half_rad
	range_m = range_metres
	rate_m_s = rate
	snap_m = snap


## The next step snaps to the walls instead of easing (light just switched on, say).
func restart() -> void:
	_fresh = true


## The yaw of ray `i`, across the light's full width.
func ray_yaw(i: int, at_yaw: float) -> float:
	return at_yaw - half + half * 2.0 * float(i) / float(reach.size() - 1)


## Asks the walls where each ray stops. Isn't free, so a caller may do it less often than step().
## `eye` is whose body holds the light: a muzzle poking through a wall has no beam.
func cast(visibility: Visibility, eye: Vector2, muzzle: Vector2, at_yaw: float) -> void:
	if visibility.blocked(eye, muzzle):
		_want.fill(0.0)
		return
	_want = visibility.fan(muzzle, ray_yaw(0, at_yaw), half * 2.0, reach.size(), range_m)


func step(delta: float, muzzle: Vector2, at_yaw: float) -> void:
	var snap := _fresh or apex.distance_to(muzzle) > snap_m
	_fresh = false
	apex = muzzle
	yaw = at_yaw
	var most := rate_m_s * delta
	for i in reach.size():
		reach[i] = _want[i] if snap else move_toward(reach[i], _want[i], most)


## The end of ray `i` on the floor plan.
func point(i: int) -> Vector2:
	return apex + Visibility.yaw_dir2(ray_yaw(i, yaw)) * reach[i]


## Rebuilds `mesh`: the sheet lies along the light's axis, starting at the muzzle and tipping down
## with the spot's pitch until `floor_m`. UV is beam space (forward, across) in ranges: linear over
## each triangle, so the shader's soft edges and fade don't depend on where the vertices are.
func fill(mesh: ImmediateMesh, muzzle: Vector3, pitch_rad: float, floor_m: float) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	var slope := tan(pitch_rad)
	for i in reach.size() - 1:
		if reach[i] <= 0.0 and reach[i + 1] <= 0.0:
			continue
		added = true
		mesh.surface_set_uv(Vector2.ZERO)
		mesh.surface_add_vertex(muzzle)
		for k in 2:
			var r := reach[i + k]
			var off := ray_yaw(i + k, 0.0)
			mesh.surface_set_uv(Vector2(cos(off), sin(off)) * r / range_m)
			var p := point(i + k)
			mesh.surface_add_vertex(Vector3(p.x, maxf(muzzle.y + slope * r, floor_m), p.y))
	if not added:
		# A surface can't be empty.
		mesh.surface_set_uv(Vector2.ZERO)
		for k in 3:
			mesh.surface_add_vertex(muzzle)
	mesh.surface_end()
