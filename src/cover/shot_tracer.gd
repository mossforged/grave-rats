extends RefCounted
## A shot in 3D. The plan line comes from the rifle's yaw; walls and doors stop it through physics.
## A body on that line is aimed for at its torso height, and cover between muzzle and torso stops
## it there. Duck-typed bodies: shot_disc() -> {} or {center: Vector2, radius, height}, take_hit().

var cover: RefCounted
var bodies: Array = []
var exclude: Array[RID] = []
var world: World3D


func _init(cover_field: RefCounted, world_3d: World3D) -> void:
	cover = cover_field
	world = world_3d


## Rifle.shot_tracer: returns {} (flew out of range) or {position, collider}.
func trace(origin: Vector3, dir: Vector3, length: float) -> Dictionary:
	var to := origin + dir * length
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.exclude = exclude
	var wall: Dictionary = world.direct_space_state.intersect_ray(query)
	var wall_d: float = length if wall.is_empty() else origin.distance_to(wall.position)
	var from2 := Vector2(origin.x, origin.z)
	var dir2 := Vector2(dir.x, dir.z)
	var best: Object = null
	var best_d := wall_d
	var best_h := 0.0
	for b: Object in bodies:
		var disc: Dictionary = b.shot_disc()
		if disc.is_empty():
			continue
		var d := disc_distance(from2, dir2, disc.center, float(disc.radius))
		if d >= 0.0 and d < best_d:
			best = b
			best_d = d
			best_h = float(disc.height)
	if best == null:
		return wall
	var aim := Vector3(origin.x + dir.x * best_d, best_h, origin.z + dir.z * best_d)
	var stopped: Dictionary = cover.segment_hit(origin, aim)
	if not stopped.is_empty():
		return {"position": stopped.point, "collider": null}
	return {"position": aim, "collider": best}


## Distance along the unit `dir` from `from` to where it enters the circle, or -1.
static func disc_distance(from: Vector2, dir: Vector2, center: Vector2, radius: float) -> float:
	var to := center - from
	var along := to.dot(dir)
	var off2 := to.length_squared() - along * along
	if off2 > radius * radius:
		return -1.0
	var d := along - sqrt(radius * radius - off2)
	if d >= 0.0:
		return d
	return along + sqrt(radius * radius - off2) if along >= 0.0 else -1.0
