extends "res://tests/test_case.gd"
## Legacy pass-05 glTFs: they load, expose the clip names, share the 22-bone rig, and bind
## the named materials (assets/game/legacy/, see docs/handoffs/auto-T001.md).

const LEGACY := "res://assets/game/legacy/"
const CLIPS := ["F_Death", "F_Roll", "L_Crouch_Idle", "L_Crouch_Walk", "L_Idle", "L_Run_B", "L_Run_F",
	"L_Strafe_L", "L_Strafe_R", "L_Walk_F", "U_Aim", "U_LowReady", "U_Reload"]
const KIT_NEEDED := ["wall_tall", "post_tall", "floor_tile", "floor_grate_tile", "crate_large", "med_bed"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _spawn(path: String) -> Node:
	var ps: PackedScene = load(path)
	if not check(ps != null, "%s loads" % path):
		return null
	var n := ps.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	_nodes.append(n)
	return n


func _find(root: Node, cls: String) -> Node:
	var found := root.find_children("*", cls, true, false)
	return found[0] if found.size() > 0 else null


func test_operator_has_every_clip() -> void:
	var op := _spawn(LEGACY + "operator.glb")
	if op == null:
		return
	var ap: AnimationPlayer = _find(op, "AnimationPlayer")
	if not check(ap != null, "operator has an AnimationPlayer"):
		return
	for c in CLIPS:
		check(ap.has_animation(c), "operator clip %s" % c)
	check_eq(ap.get_animation("L_Run_F").loop_mode, Animation.LOOP_LINEAR, "L_ clips loop")
	check_eq(ap.get_animation("F_Roll").loop_mode, Animation.LOOP_NONE, "F_ clips play once")


func test_operator_and_robot_share_the_rig() -> void:
	var op := _spawn(LEGACY + "operator.glb")
	var robot := _spawn(LEGACY + "robot.tscn")
	if op == null or robot == null:
		return
	var a: Skeleton3D = _find(op, "Skeleton3D")
	var b: Skeleton3D = _find(robot, "Skeleton3D")
	check_eq(a.get_bone_count(), 22, "operator has 22 bones")
	check_eq(b.get_bone_count(), 22, "robot has 22 bones")
	for i in a.get_bone_count():
		check_eq(b.get_bone_name(i), a.get_bone_name(i), "bone %d name matches" % i)


func test_robot_plays_operator_clips() -> void:
	var robot := _spawn(LEGACY + "robot.tscn")
	if robot == null:
		return
	var ap: AnimationPlayer = robot.get_node("AnimationPlayer")
	var skel: Skeleton3D = _find(robot, "Skeleton3D")
	for c in CLIPS:
		check(ap.has_animation(c), "robot has clip %s" % c)
	var thigh := skel.find_bone("thigh_L")
	ap.play("L_Walk_F")
	ap.seek(0.0, true)
	var q0 := skel.get_bone_pose_rotation(thigh)
	ap.seek(0.25, true)
	var q1 := skel.get_bone_pose_rotation(thigh)
	check(q0.angle_to(q1) > 0.05, "robot thigh moves while walking (%.3f rad)" % q0.angle_to(q1))


func test_materials_bound_by_slot_name() -> void:
	var op := _spawn(LEGACY + "operator.glb")
	var robot := _spawn(LEGACY + "robot.tscn")
	var kit := _spawn(LEGACY + "kit.glb")
	if op == null or robot == null or kit == null:
		return
	for root in [op, robot, kit]:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = mi.mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				check(m != null and m.resource_path.begins_with(LEGACY + "materials/"),
					"%s surface %d uses a legacy material (%s)" % [mi.name, s, m.resource_path if m else "none"])
	var suit: ORMMaterial3D = load(LEGACY + "materials/suit_fabric.tres")
	check(suit.albedo_texture != null and suit.normal_texture != null and suit.orm_texture != null,
		"suit_fabric has albedo, normal and ORM")


func test_kit_pieces_are_scenes() -> void:
	for p in KIT_NEEDED:
		var n := _spawn(LEGACY + "kit/%s.tscn" % p)
		if n:
			var mi: MeshInstance3D = n.get_node("Mesh")
			check(mi.mesh != null and mi.mesh.get_surface_count() > 0, "kit %s has a mesh" % p)
