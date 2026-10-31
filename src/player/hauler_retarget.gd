extends RefCounted
## Scene-free clip work for the hauler: moves a clip between skeletons that share a body plan but not
## rest poses or bone axes, pins the hips over the origin, and measures feet. A skeleton here is a
## plain "rest" Dictionary (see `rest_of`), so all of it runs headless on numbers.
##
## The retarget works on world rotations. Each bone's change from its source rest is applied to the
## same bone's rest on the target, after that rest has been straightened to point the way the source
## rest points (the hauler is nearly a T-pose, the legacy operator stands arms-down).


## {names: [..], index: {name: i}, parents: [i], local_rot: [Quaternion], local_pos: [Vector3],
## world_rot: [Quaternion], world_pos: [Vector3]}; parents always come before children.
static func rest_of(sk: Skeleton3D, facing_flip := false) -> Dictionary:
	var names: Array = []
	var index := {}
	var parents: Array = []
	var local_rot: Array = []
	var local_pos: Array = []
	var world_rot: Array = []
	var world_pos: Array = []
	var flip := Quaternion(Vector3.UP, PI) if facing_flip else Quaternion.IDENTITY
	for i in sk.get_bone_count():
		var bone_name := String(sk.get_bone_name(i))
		var rest := sk.get_bone_rest(i)
		var global := sk.get_bone_global_rest(i)
		names.append(bone_name)
		index[bone_name] = i
		parents.append(sk.get_bone_parent(i))
		local_rot.append(rest.basis.get_rotation_quaternion())
		local_pos.append(rest.origin)
		world_rot.append(flip * global.basis.get_rotation_quaternion())
		world_pos.append(flip * global.origin)
	return {"names": names, "index": index, "parents": parents, "local_rot": local_rot,
		"local_pos": local_pos, "world_rot": world_rot, "world_pos": world_pos, "flip": flip}


## Target rest world rotations, each bone turned the shortest way so the bone points where its source
## counterpart points. `chains` is [[bone, next bone], ...], parents first, in target names; `map` is
## {target name: source name}.
static func straightened(dst: Dictionary, src: Dictionary, map: Dictionary, chains: Array) -> Array:
	var turn: Array = []
	turn.resize(dst.names.size())
	var along := {}
	for c: Array in chains:
		along[c[0]] = c[1]
	var pos: Array = dst.world_pos.duplicate()
	for i in dst.names.size():
		var parent: int = dst.parents[i]
		var inherited: Quaternion = turn[parent] if parent >= 0 else Quaternion.IDENTITY
		if parent >= 0:
			var offset: Vector3 = dst.world_pos[i] - dst.world_pos[parent]
			pos[i] = pos[parent] + inherited * offset
		turn[i] = inherited
		var bone: String = dst.names[i]
		if not along.has(bone) or not dst.index.has(along[bone]) or not map.has(bone) or not map.has(along[bone]):
			continue
		if not src.index.has(map[bone]) or not src.index.has(map[along[bone]]):
			continue
		var next: int = dst.index[along[bone]]
		var have: Vector3 = (dst.world_pos[next] - dst.world_pos[i]) as Vector3
		have = (inherited * have).normalized()
		var want: Vector3 = (src.world_pos[src.index[map[along[bone]]]] - src.world_pos[src.index[map[bone]]])
		want = want.normalized()
		turn[i] = _arc(have, want) * inherited
	var out: Array = []
	for i in dst.names.size():
		out.append((turn[i] as Quaternion) * (dst.world_rot[i] as Quaternion))
	return out


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var d := from.dot(to)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		return Quaternion(from.cross(Vector3.RIGHT).normalized(), PI)
	return Quaternion(from, to)


## A new clip for the target skeleton. `opts`: `path` (target skeleton's node path, e.g.
## "Armature/Skeleton3D"), `hips` (target hips bone name), `hip_scale`, `fps`. A source facing -Z comes from `rest_of(sk, true)`.
static func retarget(clip: Animation, src: Dictionary, dst: Dictionary, map: Dictionary, chains: Array, opts: Dictionary) -> Animation:
	var straight := straightened(dst, src, map, chains)
	var flip: Quaternion = src.flip
	var tracks := {}
	var hip_src: String = map[String(opts.hips)]
	var hip_track := -1
	for t in clip.get_track_count():
		var bone := String(clip.track_get_path(t).get_concatenated_subnames())
		if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks[bone] = t
		elif clip.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == hip_src:
			hip_track = t
	var out := Animation.new()
	out.length = clip.length
	var fps := float(opts.get("fps", 30.0))
	var frames := maxi(int(ceil(clip.length * fps)), 1)
	var keyed: Array = []
	for bone: String in dst.names:
		if map.has(bone) and src.index.has(map[bone]):
			var t := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(t, NodePath("%s:%s" % [opts.path, bone]))
			keyed.append([bone, t])
	var hips_out := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_out, NodePath("%s:%s" % [opts.path, opts.hips]))
	var hip_scale := float(opts.get("hip_scale", 1.0))
	var src_rest_hips: Vector3 = src.local_pos[src.index[hip_src]]
	var src_parent: int = src.parents[src.index[hip_src]]
	for f in frames + 1:
		var time := minf(f / fps, clip.length)
		var src_world := _source_world(clip, src, tracks, time)
		var world := {}
		for pair: Array in keyed:
			var bone: String = pair[0]
			var i: int = dst.index[bone]
			var j: int = src.index[map[bone]]
			var change: Quaternion = (src_world[j] as Quaternion) * (src.world_rot[j] as Quaternion).inverse()
			world[i] = change * (straight[i] as Quaternion)
			var parent: int = dst.parents[i]
			var parent_world: Quaternion = world.get(parent, dst.world_rot[parent]) if parent >= 0 else Quaternion.IDENTITY
			out.rotation_track_insert_key(pair[1], time, (parent_world.inverse() * (world[i] as Quaternion)).normalized())
		var hip_at: Vector3 = src_rest_hips
		if hip_track >= 0:
			hip_at = clip.position_track_interpolate(hip_track, time)
		if src_parent >= 0:
			hip_at = (src.world_pos[src_parent] as Vector3) + (src_world[src_parent] as Quaternion) * hip_at
		else:
			hip_at = flip * hip_at
		out.position_track_insert_key(hips_out, time, hip_at * hip_scale)
	return out


static func _source_world(clip: Animation, src: Dictionary, tracks: Dictionary, time: float) -> Array:
	var world: Array = []
	world.resize(src.names.size())
	var flip: Quaternion = src.flip
	for i in src.names.size():
		var local: Quaternion = src.local_rot[i]
		if tracks.has(src.names[i]):
			local = clip.rotation_track_interpolate(tracks[src.names[i]], time)
		var parent: int = src.parents[i]
		world[i] = (world[parent] as Quaternion) * local if parent >= 0 else flip * local
	return world


## Pins the hips' x and z to their first key, so the clip plays on the spot and the code moves the body.
static func strip_hip_travel(clip: Animation, hip_path: String) -> void:
	var t := clip.find_track(NodePath(hip_path), Animation.TYPE_POSITION_3D)
	if t < 0:
		return
	var first: Vector3 = clip.track_get_key_value(t, 0)
	for k in clip.track_get_key_count(t):
		var at: Vector3 = clip.track_get_key_value(t, k)
		clip.track_set_key_value(t, k, Vector3(first.x, at.y, first.z))


## A new clip with time bent piecewise: the moment `from[i]` (s) of the clip plays at `to[i]`. Both rising. The
## clip before from[0] and after the last is cut, and it starts at to[0], which should be 0.
static func warped(clip: Animation, from: Array, to: Array, fps: float) -> Animation:
	var out := Animation.new()
	out.length = float(to[-1])
	var frames := maxi(int(ceil(out.length * fps)), 1)
	for t in clip.get_track_count():
		var kind := clip.track_get_type(t)
		var n := out.add_track(kind)
		out.track_set_path(n, clip.track_get_path(t))
		for f in frames + 1:
			var at := minf(f / fps, out.length)
			var source := _piecewise(at, to, from)
			if kind == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(n, at, clip.rotation_track_interpolate(t, source))
			elif kind == Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(n, at, clip.position_track_interpolate(t, source))
	return out


static func _piecewise(x: float, xs: Array, ys: Array) -> float:
	for i in xs.size() - 1:
		if x <= float(xs[i + 1]):
			return remap(x, float(xs[i]), float(xs[i + 1]), float(ys[i]), float(ys[i + 1]))
	return float(ys[-1])


## Turns a clip into a change on top of whatever's under it (an Add2): each bone's rotation becomes its change
## from the clip's first frame, written over the rest pose, because that's what the mixer measures from.
static func make_additive(clip: Animation, rest: Dictionary, skeleton_path: String) -> void:
	var prefix := skeleton_path + ":"
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(clip.track_get_path(t)).trim_prefix(prefix)
		if not rest.index.has(bone) or clip.track_get_key_count(t) == 0:
			continue
		var base: Quaternion = rest.local_rot[rest.index[bone]]
		var first: Quaternion = clip.track_get_key_value(t, 0)
		for k in clip.track_get_key_count(t):
			var q: Quaternion = clip.track_get_key_value(t, k)
			clip.track_set_key_value(t, k, (base * first.inverse() * q).normalized())


## Largest horizontal distance the hips stray from where they start.
static func hip_travel(clip: Animation, hip_path: String) -> float:
	var t := clip.find_track(NodePath(hip_path), Animation.TYPE_POSITION_3D)
	if t < 0:
		return 0.0
	var first: Vector3 = clip.track_get_key_value(t, 0)
	var most := 0.0
	for k in clip.track_get_key_count(t):
		var at: Vector3 = clip.track_get_key_value(t, k)
		most = maxf(most, Vector2(at.x - first.x, at.z - first.z).length())
	return most


## Takes the hips' turn about up out of a clip: the code turns the body, and the feet, children of the
## hips, then sweep the opposite way, which is what planted feet under a turning body do.
static func strip_hip_yaw(clip: Animation, hip_path: String) -> void:
	var t := clip.find_track(NodePath(hip_path), Animation.TYPE_ROTATION_3D)
	if t < 0:
		return
	var first: Quaternion = clip.track_get_key_value(t, 0)
	for k in clip.track_get_key_count(t):
		var q: Quaternion = clip.track_get_key_value(t, k)
		var change := q * first.inverse()
		var yaw := Quaternion(0.0, change.y, 0.0, change.w).normalized()
		clip.track_set_key_value(t, k, (yaw.inverse() * q).normalized())


## Adds `dy` to every hips key.
static func lift_hips(clip: Animation, hip_path: String, dy: float) -> void:
	var t := clip.find_track(NodePath(hip_path), Animation.TYPE_POSITION_3D)
	if t < 0:
		return
	for k in clip.track_get_key_count(t):
		clip.track_set_key_value(t, k, (clip.track_get_key_value(t, k) as Vector3) + Vector3.UP * dy)


## World positions of `bones` (names) at `time`, by forward kinematics over the clip.
static func fk(clip: Animation, rest: Dictionary, skeleton_path: String, time: float, bones: Array) -> Dictionary:
	var poses := fk_poses(clip, rest, skeleton_path, time, bones)
	var out := {}
	for b: String in bones:
		out[b] = (poses[b] as Transform3D).origin
	return out


## World transforms of `bones` at `time`.
static func fk_poses(clip: Animation, rest: Dictionary, skeleton_path: String, time: float, bones: Array) -> Dictionary:
	var rot: Array = []
	var pos: Array = []
	rot.resize(rest.names.size())
	pos.resize(rest.names.size())
	for i in rest.names.size():
		var path := NodePath("%s:%s" % [skeleton_path, rest.names[i]])
		var r_track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		var p_track := clip.find_track(path, Animation.TYPE_POSITION_3D)
		var r: Quaternion = clip.rotation_track_interpolate(r_track, time) if r_track >= 0 else rest.local_rot[i]
		var p: Vector3 = clip.position_track_interpolate(p_track, time) if p_track >= 0 else rest.local_pos[i]
		var parent: int = rest.parents[i]
		if parent < 0:
			rot[i] = r
			pos[i] = p
		else:
			pos[i] = (pos[parent] as Vector3) + (rot[parent] as Quaternion) * p
			rot[i] = (rot[parent] as Quaternion) * r
	var out := {}
	for b: String in bones:
		var i: int = rest.index[b]
		out[b] = Transform3D(Basis(rot[i] as Quaternion), pos[i])
	return out


## The lowest a foot joint gets over the clip, in the clip's own space.
static func lowest(clip: Animation, rest: Dictionary, skeleton_path: String, bones: Array, samples := 24) -> float:
	var low := INF
	for s in samples:
		var at := fk(clip, rest, skeleton_path, clip.length * s / float(samples), bones)
		for b: String in bones:
			low = minf(low, (at[b] as Vector3).y)
	return low


## Ground speed (m/s) the clip's feet imply: how fast the lower foot moves backward along `axis`
## while it's near its lowest. A clip on the spot walks at this speed.
static func foot_speed(clip: Animation, rest: Dictionary, skeleton_path: String, feet: Array, axis: Vector3, samples := 60) -> float:
	var low := lowest(clip, rest, skeleton_path, feet, samples)
	var dist := 0.0
	var time := 0.0
	var dt := clip.length / float(samples)
	for s in samples:
		var a := fk(clip, rest, skeleton_path, dt * s, feet)
		var b := fk(clip, rest, skeleton_path, dt * (s + 1), feet)
		for foot: String in feet:
			if (a[foot] as Vector3).y < low + 0.04:
				dist += -((b[foot] as Vector3) - (a[foot] as Vector3)).dot(axis)
				time += dt
	return dist / maxf(time, dt)
