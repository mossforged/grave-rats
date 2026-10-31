extends Node3D
## T022: clips laid out over time, for marking frames by eye: each row a state, each column a share of its length.
## Raw clips with no tree or twist, on the bone-pose rifle. Run windowed:
##   godot --path . scenes/dev/t022_strips.tscn -- --out=docs/screens/T022/strips

const OperatorBody := preload("res://src/player/operator_body.gd")
const SHARES := [0.0, 0.1, 0.2, 0.25, 0.3, 0.38, 0.45, 0.55, 0.65, 0.8, 0.9, 1.0]
const SHEETS := {
	"reloads": ["reload", "reload_walking", "reload_crouch"],
	"actions": ["pick_up", "interact", "cover_idle", "cover_to_stand"],
	"crouching": ["stand_to_crouch", "crouch_to_stand"],
	"deaths": ["death", "death_headshot", "death_forward", "death_backward"],
	"carry": ["carry_idle", "carry_walk", "carry_crouch_idle", "carry_crouch_walk"],
}

var _out := "docs/screens/T022/strips"
var _cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1900, 1000)
	_room()
	_cam = Camera3D.new()
	add_child(_cam)
	for sheet: String in SHEETS:
		await _strip(sheet, SHEETS[sheet])
	get_tree().quit(0)


func _room() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.35)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)


func _strip(sheet: String, states: Array) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var weight: Dictionary = OperatorBody.weight_for("hauler", Data.load_data("player"))
	for r in states.size():
		for c in SHARES.size():
			var slot := Node3D.new()
			holder.add_child(slot)
			slot.position = Vector3(c * 1.5, 0, r * 2.6)
			slot.rotation.y = deg_to_rad(-120.0)
			var body := OperatorBody.build(slot, "hauler", weight.anim, "weapon")
			body.anim.tree.active = false
			body.anim.twist.active = false
			var player: AnimationPlayer = body.visual.find_children("*", "AnimationPlayer", true, false)[0]
			player.play("hauler/" + String(states[r]))
			player.seek(player.current_animation_length * float(SHARES[c]), true)
			player.pause()
			if c == 0:
				var label := Label3D.new()
				label.text = states[r]
				label.pixel_size = 0.006
				label.font_size = 42
				label.outline_size = 12
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.position = Vector3(0, 2.3, 0)
				slot.add_child(label)
	var center := Vector3((SHARES.size() - 1) * 0.75, 0.9, (states.size() - 1) * 1.3)
	_cam.position = center + Vector3(0, 6.0 + states.size(), 7.0 + states.size() * 2.2)
	_cam.look_at(center)
	_cam.fov = 48
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, sheet])
	holder.free()
