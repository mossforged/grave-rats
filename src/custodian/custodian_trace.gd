extends RefCounted
## The guns' 3D trace, for lines that aren't bullets: walls and doors through physics, then the cover field
## (src/cover/shot_tracer.gd reads them the same way). Bodies don't stop a line: anything but a static
## collider is stepped through, so a stalker in the way doesn't hide you.

var cover: RefCounted
var world: World3D
var exclude: Array[RID] = []


func _init(cover_field: RefCounted, world_3d: World3D, excluded: Array[RID]) -> void:
	cover = cover_field
	world = world_3d
	exclude = excluded


## (from, to) -> {clear, point}: where the line stops, or `to` if nothing's in the way.
func line(from: Vector3, to: Vector3) -> Dictionary:
	var stop := to
	var clear := true
	var skip: Array[RID] = exclude.duplicate()
	var space := world.direct_space_state
	while true:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		if hit.collider is StaticBody3D:
			stop = hit.position
			clear = false
			break
		skip.append(hit.rid)
	var piece: Dictionary = cover.segment_hit(from, to)
	if not piece.is_empty():
		var at: Vector3 = piece.point
		if clear or from.distance_to(at) < from.distance_to(stop):
			stop = at
		clear = false
	return {"clear": clear, "point": stop}
