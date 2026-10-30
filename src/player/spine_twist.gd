extends SkeletonModifier3D
## Turns the upper body by `twist` radians about the skeleton's up axis, on top of whatever the
## animation posed, shared between spine1 and spine2. This is the torso leading the hips; the arms,
## head and gun ride along.

var twist := 0.0
var spine1_share := 0.5
var weapon_pose := Transform3D.IDENTITY   # skeleton space, after the twist

var _spine1 := -1
var _spine2 := -1
var _weapon := -1


## Godot restores bone poses after the modifier stage, so the gun's pose is kept here for the muzzle.
func setup(skeleton: Skeleton3D, weapon_bone: int) -> void:
	_weapon = weapon_bone
	_spine1 = skeleton.find_bone("spine1")
	_spine2 = skeleton.find_bone("spine2")


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _spine1 < 0:
		return
	if twist != 0.0:
		_turn(sk, _spine1, twist * spine1_share)
		_turn(sk, _spine2, twist * (1.0 - spine1_share))
	weapon_pose = sk.get_bone_global_pose(_weapon)


func _turn(sk: Skeleton3D, bone: int, angle: float) -> void:
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = Basis(Vector3.UP, angle) * pose.basis
	sk.set_bone_global_pose(bone, pose)
