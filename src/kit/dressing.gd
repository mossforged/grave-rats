extends RefCounted
## The room dressing in data/deck.json "dressing": clutter on the floor and props on the walls. Looks
## only: no collision, no cover class, no nav blocker, nothing in `layout.props`. A wall prop has
## "wall" and "at" (0-1 along it) and its height in data/kit.json "wall_mounts"; clutter has "at"
## [fx, fz]. Entries for a room this deck doesn't have are left out (the pirate deck has no medbay).

const KitPieces := preload("res://src/kit/kit_pieces.gd")
const KitMaterials := preload("res://src/kit/kit_materials.gd")

const WALL_YAW := {"north": 0.0, "east": -PI * 0.5, "south": PI, "west": PI * 0.5}


## Every piece on this deck: {type, space, wall ("" for clutter), mesh, position: Vector3, yaw,
## rect: Rect2 (its floor footprint, world XZ)}. Skips a type with no file that loads.
static func placed(layout: RefCounted) -> Array:
	var out: Array = []
	for spec: Dictionary in layout.data.get("dressing", []):
		var space := String(spec.space)
		if not layout.spaces.has(space):
			continue
		var mesh: ArrayMesh = KitPieces.slot_mesh(KitPieces.slot_file(String(spec.type), Vector3.ZERO))
		if mesh == null:
			continue
		out.append(_on_wall(layout, spec, mesh) if spec.has("wall") else _on_floor(layout, spec, mesh))
	return out


static func build(layout: RefCounted) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	for piece: Dictionary in placed(layout):
		var mi := MeshInstance3D.new()
		mi.name = String(piece.type).to_pascal_case()
		mi.mesh = piece.mesh
		mi.set_meta("kit_piece", String(piece.type))
		mi.position = piece.position
		mi.rotation.y = piece.yaw
		mi.layers = KitPieces.space_layer(layout, String(piece.space))
		root.add_child(mi)
	return root


static func _on_floor(layout: RefCounted, spec: Dictionary, mesh: ArrayMesh) -> Dictionary:
	var c: Vector2 = layout.point_in(String(spec.space), spec.at)
	var yaw := deg_to_rad(float(spec.get("turn_deg", 0.0)))
	return _piece(spec, "", mesh, Vector3(c.x, 0.0, c.y), yaw)


## Its back on the room's face of the wall, whatever the file's origin, front to the room.
static func _on_wall(layout: RefCounted, spec: Dictionary, mesh: ArrayMesh) -> Dictionary:
	var wall := String(spec.wall)
	var r: Rect2 = layout.space_rect(String(spec.space))
	var pose := wall_pose(r, wall, float(wall_face(r, wall).length) * float(spec.at), mesh, String(spec.type))
	return _piece(spec, wall, mesh, pose.at, pose.yaw)


## A wall of room `r` as a line: `start` (its low end, on the room's face), `along`, `inward`, `length`.
static func wall_face(r: Rect2, wall: String) -> Dictionary:
	match wall:
		"north":
			return {"start": r.position, "along": Vector2.RIGHT, "inward": Vector2.DOWN, "length": r.size.x}
		"south":
			return {"start": Vector2(r.position.x, r.end.y), "along": Vector2.RIGHT, "inward": Vector2.UP, "length": r.size.x}
		"west":
			return {"start": r.position, "along": Vector2.DOWN, "inward": Vector2.RIGHT, "length": r.size.y}
	return {"start": Vector2(r.end.x, r.position.y), "along": Vector2.DOWN, "inward": Vector2.LEFT, "length": r.size.y}


## Where a wall prop stands: its back `along_m` down the wall's face (less the type's `sink_m`), at its
## `mount_y_m` from data/kit.json "wall_mounts". {at: Vector3, yaw}.
static func wall_pose(r: Rect2, wall: String, along_m: float, mesh: ArrayMesh, type: String) -> Dictionary:
	var f := wall_face(r, wall)
	var mount: Dictionary = KitMaterials.cfg().wall_mounts[type]
	var out := -mesh.get_aabb().position.z - float(mount.get("sink_m", 0.0))
	var p: Vector2 = (f.start as Vector2) + (f.along as Vector2) * along_m + (f.inward as Vector2) * out
	return {"at": Vector3(p.x, float(mount.mount_y_m), p.y), "yaw": float(WALL_YAW[wall])}


static func _piece(spec: Dictionary, wall: String, mesh: ArrayMesh, at: Vector3, yaw: float) -> Dictionary:
	var box: AABB = Transform3D(Basis(Vector3.UP, yaw), at) * mesh.get_aabb()
	return {"type": String(spec.type), "space": String(spec.space), "wall": wall, "mesh": mesh,
			"position": at, "yaw": yaw, "rect": Rect2(box.position.x, box.position.z, box.size.x, box.size.z)}
