extends Node3D
## The salvage on the deck: rolls it from data/salvage.json "placements" and draws it. Grey boxes,
## colour-coded by class, each on a ring of light that reads in the dark (the fairness rule: a
## `src/sight` beacon, faint where you've never looked). The rules are in carry_state.gd.

const SalvageRules := preload("res://src/salvage/salvage_rules.gd")
const SalvageItem := preload("res://src/salvage/salvage_item.gd")
const BEACON := preload("res://src/sight/beacon.gdshader")

var rules: SalvageRules
## Everything on this ship, in the data's order.
var items: Array = []

var _cfg: Dictionary
var _layout: RefCounted
var _bind := Callable()
var _props := {}          # SalvageItem.id -> {root, rim}
var _bodies := {}         # look key -> Mesh
var _body_mats := {}
var _rims := {}
var _rim_mats := {}


func setup(config: Dictionary, layout: RefCounted, bind: Callable) -> void:
	_cfg = config
	_layout = layout
	_bind = bind
	rules = SalvageRules.new(_cfg)
	for i in (_cfg.placements as Array).size():
		var root := Node3D.new()
		root.name = "Salvage%d" % (i + 1)
		add_child(root)
		_props[i] = {"root": root}


## A new ship's worth of salvage: new rolls, everything back where the data puts it.
func reset(rng: RandomNumberGenerator) -> void:
	items = []
	var specs: Array = _cfg.placements
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var item: SalvageItem = rules.roll(String(spec.kind), i, rng)
		item.at = _layout.point_in(String(spec.space), spec.at)
		items.append(item)
		_dress(item)
		lay_down(item, item.at)


## The nearest item on the floor within reach of `p`, or null.
func nearest(p: Vector2) -> SalvageItem:
	var best: SalvageItem = null
	var best_d := float(_cfg.reach_m)
	for item: SalvageItem in items:
		if item.taken_by != 0 or not _on_floor(item):
			continue
		var d := p.distance_to(item.at)
		if d <= best_d:
			best = item
			best_d = d
	return best


func _on_floor(item: SalvageItem) -> bool:
	return (_props[item.id].root as Node3D).visible and (_props[item.id].rim as Node3D).visible


func on_floor() -> Array:
	return items.filter(func(item: SalvageItem) -> bool: return _on_floor(item))


## On the deck at `at`, ring and all.
func lay_down(item: SalvageItem, at: Vector2) -> void:
	item.at = at
	var root: Node3D = _props[item.id].root
	root.visible = true
	root.global_position = Vector3(at.x, 0.0, at.y)
	root.rotation = Vector3.ZERO
	(_props[item.id].rim as Node3D).visible = true


## Out of the world: pocketed or in the hold.
func put_away(item: SalvageItem) -> void:
	(_props[item.id].root as Node3D).visible = false


## In someone's hands: shown where the class says, relative to them, without its ring.
func hold_up(item: SalvageItem, xform: Transform3D) -> void:
	var root: Node3D = _props[item.id].root
	root.visible = true
	(_props[item.id].rim as Node3D).visible = false
	var c: Array = rules.class_of(item).carry_at
	root.global_transform = xform.translated_local(Vector3(float(c[0]), float(c[1]), float(c[2])))


func _dress(item: SalvageItem) -> void:
	var prop: Dictionary = _props[item.id]
	var root: Node3D = prop.root
	if prop.has("rim"):
		(prop.body as Node).free()
		(prop.rim as Node).free()
	var c: Dictionary = rules.class_of(item)
	var spec: Dictionary = rules.kind_spec(item.kind)
	var key := item.kind if spec.has("color") else item.klass
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(key, c)
	body.material_override = _body_mat(key, String(spec.get("color", c.color)))
	body.position.y = float((c.size_m as Array)[1]) * 0.5
	root.add_child(body)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = _rim_mesh(key, float(c.rim_radius_m))
	rim.material_override = _rim_mat(key, String(spec.get("rim_color", c.rim_color)))
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.position.y = float(_cfg.rim.height_m)
	root.add_child(rim)
	prop["body"] = body
	prop["rim"] = rim


func _body_mesh(key: String, c: Dictionary) -> Mesh:
	if not _bodies.has(key):
		var s: Array = c.size_m
		var box := BoxMesh.new()
		box.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
		_bodies[key] = box
	return _bodies[key]


func _body_mat(key: String, hex: String) -> Material:
	if not _body_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		_body_mats[key] = m
	return _body_mats[key]


func _rim_mesh(key: String, radius: float) -> Mesh:
	if not _rims.has(key):
		var torus := TorusMesh.new()
		var w := float(_cfg.rim.width_m)
		torus.inner_radius = radius - w
		torus.outer_radius = radius + w
		torus.rings = int(_cfg.rim.segments)
		torus.ring_segments = int(_cfg.rim.segments)
		_rims[key] = torus
	return _rims[key]


func _rim_mat(key: String, hex: String) -> Material:
	if not _rim_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = BEACON
		m.set_shader_parameter("beacon_color", Color(hex))
		m.set_shader_parameter("energy", float(_cfg.rim.energy))
		m.set_shader_parameter("unknown_share", float(_cfg.rim.unknown_share))
		if _bind.is_valid():
			_bind.call(m)
			m.set_shader_parameter("masked", true)
		_rim_mats[key] = m
	return _rim_mats[key]
