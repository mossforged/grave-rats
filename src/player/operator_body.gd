extends RefCounted
## Which body an operator wears, by data: `body` in data/player.json, `body.model` in data/pirates.json,
## "hauler" or "legacy". Both come back with the same anim face, so the operator and the pirates don't
## care. The hauler's rifle is the legacy rifle's mesh on the right hand bone.

const OperatorAnim := preload("res://src/player/operator_anim.gd")
const HaulerAnim := preload("res://src/player/hauler_anim.gd")
const LEGACY := "res://assets/game/legacy/operator.glb"
const RIFLE_NODE := "Rifle"
const LEGACY_WEAPON_BONE := "weapon"

## Set to wear this body whatever the data says: tools comparing the two, tests of one of them.
static var forced := ""

static var _rifle_mesh: Mesh
static var _rifle_bind := Transform3D.IDENTITY


## The kind to wear, given what the data asks for.
static func kind(wanted: String) -> String:
	return forced if forced != "" else wanted


## A copy of the weight data whose "anim" block fits the body: the hauler's clips run at their own
## speeds, so the feet are matched to the ground by its numbers.
static func weight_for(wanted: String, weight: Dictionary) -> Dictionary:
	if kind(wanted) != "hauler":
		return weight
	var out := weight.duplicate(true)
	var clip_speeds: Dictionary = Data.value("hauler_anim", "anim", {})
	(out.anim as Dictionary).merge(clip_speeds, true)
	return out


## Adds "Model" and "Anim" under `owner`, and starts the animation. Returns {visual, anim}.
static func build(owner: Node3D, wanted: String, anim_cfg: Dictionary, muzzle_bone: String) -> Dictionary:
	return _hauler(owner, anim_cfg) if kind(wanted) == "hauler" else _legacy(owner, anim_cfg, muzzle_bone)


static func _legacy(owner: Node3D, anim_cfg: Dictionary, muzzle_bone: String) -> Dictionary:
	var visual: Node3D = (load(LEGACY) as PackedScene).instantiate()
	visual.name = "Model"
	owner.add_child(visual)
	var shotgun := visual.find_child("Shotgun", true, false) as Node3D
	if shotgun:
		shotgun.visible = false
	var anim := OperatorAnim.new()
	anim.name = "Anim"
	owner.add_child(anim)
	anim.setup(visual, anim_cfg, muzzle_bone)
	anim.start()
	return {"visual": visual, "anim": anim}


## "Model" turns and leans with the code; the scene inside it is stood at the data's height and turned
## to face -Z like everything else here.
static func _hauler(owner: Node3D, anim_cfg: Dictionary) -> Dictionary:
	var cfg: Dictionary = Data.load_data("hauler_anim")
	var visual := Node3D.new()
	visual.name = "Model"
	owner.add_child(visual)
	var inner: Node3D = (load(String(cfg.file)) as PackedScene).instantiate()
	inner.name = "Hauler"
	visual.add_child(inner)
	inner.rotation.y = PI
	inner.scale = Vector3.ONE * fit_scale(inner, float(cfg.height_m))
	var anim := HaulerAnim.new()
	anim.name = "Anim"
	owner.add_child(anim)
	var offset := weapon_offset(cfg.rifle)
	anim.setup(inner, anim_cfg, offset)
	anim.start()
	_attach_rifle(anim.skeleton, String(cfg.bones.hand_right), offset)
	return {"visual": visual, "anim": anim}


## The scale that makes the mesh's rest pose `height` tall.
static func fit_scale(root: Node, height: float) -> float:
	var mesh: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	return height / mesh.mesh.get_aabb().size.y


## Where the rifle's weapon frame sits in the hand bone's space.
static func weapon_offset(rifle: Dictionary) -> Transform3D:
	var e: Array = rifle.hand_euler_deg
	var p: Array = rifle.hand_offset_m
	var euler := Vector3(deg_to_rad(float(e[0])), deg_to_rad(float(e[1])), deg_to_rad(float(e[2])))
	var basis := Basis.from_euler(euler).scaled(Vector3.ONE * float(rifle.scale))
	return Transform3D(basis, Vector3(float(p[0]), float(p[1]), float(p[2])))


static func _attach_rifle(skeleton: Skeleton3D, hand: String, offset: Transform3D) -> void:
	_load_rifle()
	var mount := BoneAttachment3D.new()
	mount.name = "RifleMount"
	skeleton.add_child(mount)
	mount.bone_name = hand
	var rifle := MeshInstance3D.new()
	rifle.name = RIFLE_NODE
	rifle.mesh = _rifle_mesh
	# The mesh is the legacy one, modelled where its weapon bone rests on the legacy body.
	rifle.transform = offset * _rifle_bind.affine_inverse()
	mount.add_child(rifle)


static func _load_rifle() -> void:
	if _rifle_mesh != null:
		return
	var legacy: Node = (load(LEGACY) as PackedScene).instantiate()
	var sk: Skeleton3D = legacy.find_children("*", "Skeleton3D", true, false)[0]
	_rifle_mesh = (legacy.find_child(RIFLE_NODE, true, false) as MeshInstance3D).mesh
	_rifle_bind = sk.get_bone_global_rest(sk.find_bone(LEGACY_WEAPON_BONE))
	legacy.free()
