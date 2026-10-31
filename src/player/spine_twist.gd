extends SkeletonModifier3D
## Turns the upper body by `twist` radians about the skeleton's up axis, on top of whatever the
## animation posed, shared between the two spine bones. This is the torso leading the hips; the arms,
## head and gun ride along. With `aim_lock` it also takes up whatever yaw and pitch the clips left in
## the barrel, so the gun points where the torso does whichever clips are mixed under it.

var twist := 0.0
var spine1_share := 0.5
var weapon_pose := Transform3D.IDENTITY   # skeleton space, after the twist
var weapon_offset := Transform3D.IDENTITY # the weapon's frame in its bone's space
var forward := Vector3(0, 0, -1)          # the skeleton's front
var aim_lock := 0.0                       # 0..1, how much of the barrel's error to take up
var kick_deg := 0.0                       # recoil: the upper spine thrown back

var _spine1 := -1
var _spine2 := -1
var _weapon := -1


## Godot restores bone poses after the modifier stage, so the gun's pose is kept here for the muzzle.
func setup(skeleton: Skeleton3D, weapon_bone: int, lower := "spine1", upper := "spine2") -> void:
	_weapon = weapon_bone
	_spine1 = skeleton.find_bone(lower)
	_spine2 = skeleton.find_bone(upper)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _spine1 < 0:
		return
	var yaw := twist
	var pitch := 0.0
	if aim_lock > 0.0:
		var barrel := (sk.get_bone_global_pose(_weapon) * weapon_offset).basis.y.normalized()
		var flat := Vector3(barrel.x, 0.0, barrel.z)
		if not flat.is_zero_approx():
			yaw += flat.normalized().signed_angle_to(forward, Vector3.UP) * aim_lock
			pitch = asin(clampf(barrel.y, -1.0, 1.0)) * aim_lock
	if yaw != 0.0:
		_turn(sk, _spine1, Vector3.UP, yaw * spine1_share)
		_turn(sk, _spine2, Vector3.UP, yaw * (1.0 - spine1_share))
	var side := forward.rotated(Vector3.UP, twist).cross(Vector3.UP)
	# Positive turns about `side` tip the front up, so a low barrel comes up by a negative pitch.
	if pitch != 0.0:
		_turn(sk, _spine2, side, -pitch)
	if kick_deg != 0.0:
		_turn(sk, _spine2, side, deg_to_rad(kick_deg))
	weapon_pose = sk.get_bone_global_pose(_weapon) * weapon_offset


func _turn(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = Basis(axis, angle) * pose.basis
	sk.set_bone_global_pose(bone, pose)
