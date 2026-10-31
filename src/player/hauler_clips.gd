extends RefCounted
## John's hauler's clips: one AnimationLibrary, one clip per animation state, from data/hauler_anim.json
## "states". A state's source is a clip in the hauler's file ("Walking"), a Mixamo or Meshy file in
## clip_dir ("hauler-reload.fbx"), or a legacy clip ("legacy:U_LowReady"). Dropping
## `hauler-<state>.fbx` or `.glb` into clip_dir takes over that state with no data edit
## (`crouch_walk` -> `hauler-crouch-walk.fbx`). Built once and shared: every hauler plays the same clips.

const Retarget := preload("res://src/player/hauler_retarget.gd")
const LEGACY := "res://assets/game/legacy/operator.glb"

## The bone chains that say which way a bone points, for straightening rests.
const CHAIN_NAMES := [["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"],
	["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "LeftHandMiddle1", "LeftHandMiddle2", "LeftHandMiddle3", "LeftHandMiddle4"],
	["RightShoulder", "RightArm", "RightForeArm", "RightHand", "RightHandMiddle1", "RightHandMiddle2", "RightHandMiddle3", "RightHandMiddle4"],
	["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End"],
	["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "RightToe_End"]]

static var _library: AnimationLibrary
static var _sources := {}
static var _lifts := {}


static func library(cfg: Dictionary, player: AnimationPlayer, rest: Dictionary) -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	var made := {}
	for state: String in cfg.states:
		var spec: Dictionary = cfg.states[state]
		var key := _source_key(state, spec, cfg)
		var clip: Animation = made.get(key)
		if clip == null and key != "":
			clip = _build(key, cfg, player, rest)
			made[key] = clip
		if clip == null:
			_sources[state] = "stand-in: %s" % String(spec.get("stand_in", "holds the pose"))
			continue
		var own := clip.duplicate() as Animation
		own.loop_mode = Animation.LOOP_LINEAR if bool(spec.get("loop", false)) else Animation.LOOP_NONE
		var hip_path := "%s:%s" % [cfg.skeleton_path, cfg.bones.hips]
		if spec.has("hip_y_offset_m"):
			Retarget.lift_hips(own, hip_path, float(spec.hip_y_offset_m))
		if bool(spec.get("strip_yaw", false)):
			Retarget.strip_hip_yaw(own, hip_path)
		_library.add_animation(state, own)
		_sources[state] = key if not spec.has("stand_in") else "stand-in: %s (%s)" % [key, spec.stand_in]
	return _library


## state -> where its clip came from, for the handoff and the tests.
static func sources() -> Dictionary:
	return _sources


## Hip lift each retargeted file got to put its feet on the floor (m).
static func lifts() -> Dictionary:
	return _lifts


## For tests: a built library is thrown away, so changed data is read again.
static func forget() -> void:
	_library = null
	_sources = {}
	_lifts = {}


static func _source_key(state: String, spec: Dictionary, cfg: Dictionary) -> String:
	var dropped := "hauler-%s" % state.replace("_", "-")
	for ext: String in [".glb", ".fbx"]:
		if ResourceLoader.exists(String(cfg.clip_dir) + dropped + ext):
			return dropped + ext
	return String(spec.source)


static func _build(key: String, cfg: Dictionary, player: AnimationPlayer, rest: Dictionary) -> Animation:
	var clip: Animation
	if key.begins_with("legacy:"):
		clip = _from_legacy(key.trim_prefix("legacy:"), cfg, rest)
	elif key.ends_with(".fbx") or key.ends_with(".glb"):
		clip = _from_file(String(cfg.clip_dir) + key, cfg, rest)
	elif player.has_animation(key):
		clip = player.get_animation(key).duplicate() as Animation
	if clip == null:
		push_warning("hauler clip %s not found" % key)
		return null
	Retarget.strip_hip_travel(clip, "%s:%s" % [cfg.skeleton_path, cfg.bones.hips])
	return clip


## A file's clip, moved onto the hauler and stood on the floor.
static func _from_file(path: String, cfg: Dictionary, rest: Dictionary) -> Animation:
	if not ResourceLoader.exists(path):
		return null
	var scene := (load(path) as PackedScene).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var src := Retarget.rest_of(sk)
	var longest: Animation
	for a: String in ap.get_animation_list():
		if a != "RESET" and (longest == null or ap.get_animation(a).length > longest.length):
			longest = ap.get_animation(a)
	var map := {}
	for bone: String in rest.names:
		if src.index.has(bone):
			map[bone] = bone
	var out := _carry(longest, src, map, cfg, rest)
	_stand(out, cfg, rest, path.get_file())
	scene.free()
	return out


static func _from_legacy(clip_name: String, cfg: Dictionary, rest: Dictionary) -> Animation:
	var scene := (load(LEGACY) as PackedScene).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var out: Animation
	if ap.has_animation(clip_name):
		var src := Retarget.rest_of(sk, true)
		out = _carry(ap.get_animation(clip_name), src, cfg.legacy_map, cfg, rest)
		_stand(out, cfg, rest, "legacy:" + clip_name)
	scene.free()
	return out


static func _carry(clip: Animation, src: Dictionary, map: Dictionary, cfg: Dictionary, rest: Dictionary) -> Animation:
	var hips: String = cfg.bones.hips
	var feet: String = cfg.bones.feet[0]
	var dst_height: float = rest.world_pos[rest.index[hips]].y - rest.world_pos[rest.index[feet]].y
	var src_hips: int = src.index[map[hips]]
	var src_feet: int = src.index[map[feet]]
	var src_height: float = src.world_pos[src_hips].y - src.world_pos[src_feet].y
	return Retarget.retarget(clip, src, rest, map, chains(), {"path": cfg.skeleton_path, "hips": hips,
		"hip_scale": dst_height / src_height, "fps": float(cfg.retarget_fps)})


## The lowest a foot gets in the clip goes where the foot sits in the hauler's rest pose. A clip made
## on Mixamo's longer-legged body would otherwise float or sink.
static func _stand(clip: Animation, cfg: Dictionary, rest: Dictionary, label: String) -> void:
	var feet: Array = cfg.bones.feet
	var low := Retarget.lowest(clip, rest, cfg.skeleton_path, feet)
	var lift: float = rest.world_pos[rest.index[feet[0]]].y - low
	Retarget.lift_hips(clip, "%s:%s" % [cfg.skeleton_path, cfg.bones.hips], lift)
	_lifts[label] = lift


static func chains() -> Array:
	var out: Array = []
	for names: Array in CHAIN_NAMES:
		for i in names.size() - 1:
			out.append(["mixamorig_" + names[i], "mixamorig_" + names[i + 1]])
	return out
