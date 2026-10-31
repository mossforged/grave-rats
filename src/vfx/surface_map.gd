extends RefCounted
## Scene-free: what a round hit, as a kit material and a surface. Walls and props carry no material of their
## own (their colliders are plain boxes), so a wall answers from the room on its face and its family in
## data/kit.json, a prop from its type in data/vfx.json. A collider can name its own with meta "kit_material".
## Also the ground under a point. data/vfx.json "surfaces".

var cfg: Dictionary
var kit: Dictionary
var layout: RefCounted


func _init(surfaces: Dictionary, kit_cfg: Dictionary) -> void:
	cfg = surfaces
	kit = kit_cfg


## steel, hull... -> metal, panel, glass. An unlisted material is the first thing a test complains about.
func surface_of_material(material: String) -> String:
	return String((cfg.by_material as Dictionary).get(material, cfg.default_body))


## The recipe for a surface: metal, panel, glass, stalker, pirate, chew.
func recipe_for(surface: String) -> String:
	return String(cfg.recipes[surface])


## `target` may be null: cover stopped the round on the 3D line, and there's no collider.
func surface_of(target: Object, point: Vector3, normal: Vector3) -> String:
	if target != null and target.has_method("hit_surface"):
		return String(target.hit_surface())
	if target != null and target.has_method("take_hit"):
		return String(cfg.default_body)
	return surface_of_material(material_at(target, point, normal))


func material_at(target: Object, point: Vector3, normal: Vector3) -> String:
	if target != null and target.has_meta("kit_material"):
		return String(target.get_meta("kit_material"))
	if target is Node and (target as Node).get_parent() != null and "door_state" in (target as Node).get_parent():
		return String(cfg.door_material)
	if layout == null:
		return String(cfg.default_prop)
	var at := Vector2(point.x, point.z)
	var grow := float(cfg.prop_grow_m)
	for p: Dictionary in layout.props:
		if (p.rect as Rect2).grow(grow).has_point(at):
			return String((cfg.by_prop as Dictionary).get(String(p.type), cfg.default_prop))
	if target == null:
		return String(cfg.default_prop)
	return _wall_material(point, normal)


## Sparks and dust need a floor to fall to: the top of a prop under this point, or the deck.
func floor_at(point: Vector3) -> float:
	if layout == null:
		return 0.0
	var at := Vector2(point.x, point.z)
	for p: Dictionary in layout.props:
		if (p.rect as Rect2).has_point(at) and float(p.size.y) < point.y:
			return float(p.size.y)
	return 0.0


## deck, grate, wet: "footsteps.surfaces" in data/audio.json.
func ground_at(point: Vector3, footsteps: Dictionary) -> String:
	var space: String = layout.space_at(Vector2(point.x, point.z)) if layout != null else ""
	return String((footsteps.surfaces as Dictionary).get(space, footsteps.default_surface))


## A round's angle off the face, in degrees: 90 is square on.
static func incidence_deg(dir: Vector3, normal: Vector3) -> float:
	return rad_to_deg(asin(clampf(absf(dir.normalized().dot(normal.normalized())), 0.0, 1.0)))


func _wall_material(point: Vector3, normal: Vector3) -> String:
	var fams: Dictionary = kit.wall_families
	var d: Dictionary = kit.dims
	var at := Vector2(point.x, point.z)
	var off := Vector2(normal.x, normal.z) * float(cfg.face_probe_m)
	var space: String = layout.space_at(at + off)
	var family := String((fams.by_space as Dictionary).get(space, fams.outside))
	var fam: Dictionary = fams["plain" if family == "corridor" else family]
	var height := float(layout.data.wall_height_m)
	var y0 := float(d.kick_h_m)
	var y1 := height - float(d.cap_h_m)
	if point.y < y0 or point.y > y1:
		return String(cfg.frame_material)
	var wall := _wall_rect(at - off)
	if wall.size == Vector2.ZERO:
		return String(cfg.frame_material)
	var long_x := wall.size.x >= wall.size.y
	var along := at.x - wall.position.x if long_x else at.y - wall.position.y
	var length := wall.size.x if long_x else wall.size.y
	var post := float(d.post_m)
	if along < post or along > length - post:
		return String(cfg.frame_material)
	if fam.has("window"):
		var w := float(fam.window_inset_m)
		if length - post * 2.0 > w * float(cfg.window_min_insets) and along > post + w and along < length - post - w and point.y > y0 + w and point.y < y1 - w:
			return String(fam.window)
	return String(fam.panel)


func _wall_rect(p: Vector2) -> Rect2:
	for r: Rect2 in layout.walls:
		if r.has_point(p):
			return r
	return Rect2()
