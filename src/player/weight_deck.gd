extends Node3D
## Root of scenes/player/weight_deck.tscn: the operator and the rifle in the T002 grey-box deck
## with six target dummies, the minimal HUD and the F1 tuning panel.
##   WASD move, Shift sprint, C/Ctrl crouch, mouse aim, LMB fire, R reload,
##   1-5 camera presets, V cut-away mode, Backspace respawn, F1 tuning, F3 frame time, H key help.
## Capture hooks feed tools/capture.sh and hold each moment by freezing Engine.time_scale.

const DeckLayout := preload("res://src/study/deck_layout.gd")
const DeckBuilder := preload("res://src/study/deck_builder.gd")
const CameraRig := preload("res://src/camera/camera_rig.gd")
const Operator := preload("res://src/player/operator.gd")
const OperatorModel := preload("res://src/player/operator_model.gd")
const SuitOsHud := preload("res://src/hud/suit_os_hud.gd")
const NoiseRing := preload("res://src/hud/noise_ring.gd")
const TargetDummy := preload("res://src/weapons/target_dummy.gd")
const TuningPanel := preload("res://src/debug/tuning_panel.gd")
const Session := preload("res://src/session/session.gd")
const Commands := preload("res://src/session/commands.gd")

var deck_data: Dictionary
var layout: DeckLayout
var rig: Node3D
var session: Session
## The local player's operator: the one the camera, the HUD and the fog follow.
var operator: Operator
var hud: SuitOsHud
var noise_ring: NoiseRing
var panel: TuningPanel
var targets: Array[TargetDummy] = []
var aim_from_mouse := true

var _aim_height := 1.0
var _env: WorldEnvironment
var _plain_env: Environment
var _capture := false
var _demo_t := 0.0


func _ready() -> void:
	deck_data = Data.load_data("deck")
	_aim_height = float(Data.value("player", "aim_height_m"))
	_make_lighting()
	layout = DeckLayout.new(deck_data, float(deck_data.room_scale))
	add_child(DeckBuilder.build(layout))
	_make_targets()
	session = Session.new(Data.load_data("session"))
	operator = spawn_player(session.local_id, String(session.cfg.crew), Session.SOURCE_LOCAL)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = operator
	hud = SuitOsHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.operator = operator
	hud.camera_rig = rig
	noise_ring = NoiseRing.new()
	noise_ring.name = "NoiseRing"
	add_child(noise_ring)
	noise_ring.setup(hud.cfg.ring, _noise_senses())
	operator.rifle.fired.connect(_on_noise_shot)
	operator.space_at = layout.space_at
	Audio.follow(operator)
	if OS.is_debug_build():
		panel = TuningPanel.new()
		panel.name = "TuningPanel"
		add_child(panel)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-out="):
			_capture = true
			aim_from_mouse = false
			operator.input_enabled = false
	respawn()


func _exit_tree() -> void:
	Audio.stop_all()


## The one way onto a deck. Null if the session won't have them (a taken ID, a full crew).
func spawn_player(id: int, crew: String, source: String) -> Operator:
	var p: Session.SessionPlayer = session.add_player(id, crew, source)
	if p == null:
		return null
	var op := Operator.new()
	op.name = "Operator" if p.index == 0 else "Operator%d" % id
	op.player_id = id
	op.remote = source != Session.SOURCE_LOCAL
	op.input_enabled = source == Session.SOURCE_LOCAL
	op.send_command = session.send
	add_child(op)
	p.operator = op
	_place_player(p)
	return op


## Data "spawn" (each player a step along from the last), full gun.
func _place_player(player: Session.SessionPlayer) -> void:
	var sp: Dictionary = deck_data.spawn
	var p := layout.point_in(String(sp.space), sp.at) + session.spawn_offset(player)
	var op: Operator = player.operator
	op.global_position = Vector3(p.x, 0, p.y)
	op.model.reset_motion()
	op.rifle.state.refill()
	var a := deg_to_rad(float(sp.aim_deg))
	op.face_now(Vector3(p.x + sin(a) * 5.0, _aim_height, p.y - cos(a) * 5.0))


## Everyone back to the spawn.
func respawn() -> void:
	for p: Session.SessionPlayer in session.players:
		_place_player(p)
	hud.reset()
	noise_ring.state.reset()
	rig.aim_dir = operator.aim_dir()
	rig.snap()


func _process(delta: float) -> void:
	if aim_from_mouse:
		var cam: Camera3D = rig.camera
		var mp := get_viewport().get_mouse_position()
		var hit: Variant = Plane(Vector3.UP, _aim_height).intersects_ray(
				cam.project_ray_origin(mp), cam.project_ray_normal(mp))
		if hit != null:
			session.send(Commands.aim(operator.player_id, hit))
	elif _capture and _demo_t >= 0.0:
		_demo_step(delta)
	operator.move_yaw_deg = float(rig.preset().yaw_deg)
	rig.aim_dir = operator.aim_dir()
	_apply_camera_kick()
	noise_ring.tick(delta, operator.global_position, operator.model.noise_kind())


## The ears the ring shows: whoever hunts on this deck. The ring reads these, it doesn't copy them.
func _noise_senses() -> Dictionary:
	return (Data.value("enemies", "stalker") as Dictionary).senses


func _on_noise_shot(_from: Vector3, _to: Vector3, _direction: Vector3, _hit: Object) -> void:
	noise_ring.state.fire()


## The small kick pushes the view back along the shot, through the camera's own offsets so the
## rig's framing stays its own.
func _apply_camera_kick() -> void:
	var cam: Camera3D = rig.camera
	var k: float = operator.rifle.state.camera_kick_m
	var back := -operator.aim_dir() * k
	cam.h_offset = back.dot(cam.global_basis.x)
	cam.v_offset = back.dot(cam.global_basis.y)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_5 and k - KEY_1 < rig.presets.size():
		rig.set_preset(k - KEY_1)
	elif k == KEY_V:
		rig.cycle_cutaway_mode()
	elif k == KEY_BACKSPACE:
		respawn()
	elif k == KEY_F1 and panel:
		panel.toggle()
	elif k == KEY_H:
		hud.toggle_help()
	else:
		return
	get_viewport().set_input_as_handled()


# --- capture hooks (src/debug/capture.gd) ---

func capture_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = [
		{"name": "turn_arc_midturn", "do": "turn"},
		{"name": "cone_wide", "do": "cone_wide"},
		{"name": "cone_settled", "do": "cone_settled"},
		{"name": "shot_tracer", "do": "shot"},
		{"name": "reload_mid", "do": "reload"},
		{"name": "crouched", "do": "crouch"},
		{"name": "sprint_low_ready", "do": "sprint"},
		{"name": "torso_lead", "do": "lead"},
		{"name": "target_flinch", "do": "flinch"},
		{"name": "tuning_panel", "do": "panel"},
		{"name": "postfx_no_flash", "do": "postfx_before"},
		{"name": "postfx_flash", "do": "postfx_flash"},
	]
	for i in 6:
		shots.append({"name": "walk_%d" % (i + 1), "do": "walk", "index": i})
	return shots


## Sets up one moment with real frames, then freezes the world for the capture driver.
func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	match String(shot.do):
		"turn":
			await _pose(Vector2.ZERO, false, _ahead(180.0))
			operator.aim_point = _ahead(100.0)
			await _sim(0.18)
		"cone_wide":
			await _pose(Vector2.ZERO, false, _ahead(30.0))
			operator.scripted = {"keys": Vector2(0, -1)}
			await _sim(0.5)
			operator.scripted = {}
			await _sim(0.03)
		"cone_settled":
			await _pose(Vector2.ZERO, false, _ahead(30.0))
			await _sim(1.2)
		"shot", "postfx_flash":
			if shot.do == "postfx_flash":
				_set_postfx(true)
			await _shoot_at_dummy()
		"postfx_before":
			_set_postfx(true)
			await _pose_at_dummy()
			await _sim(1.0)
		"reload":
			await _pose(Vector2.ZERO, false, _ahead(30.0))
			operator.rifle.state.mag = floori(float(operator.rifle.state.cfg.magazine) * 0.5)
			operator.request_reload()
			await _sim(float(operator.rifle.state.reload_total) * 0.5)
		"crouch":
			await _pose(Vector2.ZERO, false, _ahead(30.0))
			operator.scripted = {"crouch": true}
			await _sim(0.6)
		"sprint":
			await _pose(Vector2.ZERO, false, _ahead(0.0))
			operator.scripted = {"keys": Vector2(0, -1), "sprint": true}
			await _sim(0.6)
		"lead":
			await _pose(Vector2.ZERO, false, _ahead(0.0))
			operator.aim_point = _ahead(60.0)
			await _sim(0.6)
		"flinch":
			await _shoot_at_dummy()
		"panel":
			await _pose(Vector2.ZERO, false, _ahead(30.0))
			panel.visible = true
			await _sim(0.1)
		"walk":
			if int(shot.index) == 0:
				_set_postfx(false)
				await _pose(Vector2.ZERO, false, _ahead(0.0))
				operator.scripted = {"keys": Vector2(0, -1)}
				await _sim(0.5)
			else:
				await _sim(_walk_cycle_s() / 6.0)
	Engine.time_scale = 0.0


func release_shot() -> void:
	Engine.time_scale = 1.0
	_set_postfx(false)
	if panel:
		panel.visible = false


func _walk_cycle_s() -> float:
	return operator.anim.cycle_length() / operator.model.leg_time_scale()


func _ahead(deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	var p := operator.global_position
	return Vector3(p.x + sin(a) * 5.0, _aim_height, p.z - cos(a) * 5.0)


func _pose(keys: Vector2, crouch: bool, point: Vector3) -> void:
	operator.scripted = {"keys": keys, "crouch": crouch}
	respawn()
	operator.face_now(point)
	await _sim(0.05)


func _pose_at_dummy() -> void:
	respawn()
	var t := targets[0]
	var point := Vector3(t.global_position.x, _aim_height, t.global_position.z)
	await _pose(Vector2.ZERO, false, point)
	await _sim(0.6)


## Waits (real frames) for a shot from a settled stance to land, stopping the same frame.
func _shoot_at_dummy() -> void:
	await _pose_at_dummy()
	operator.scripted = {"fire": true}
	await operator.rifle.fired
	operator.scripted = {}


func _sim(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


## Measuring window of a capture: walk, turn and fire so the frame time counts the whole gun.
func _demo_step(delta: float) -> void:
	_demo_t += delta
	var phase := fmod(_demo_t, 4.0)
	operator.scripted = {
		"keys": Vector2(0, -1) if phase < 1.0 else (Vector2(0, 1) if phase < 2.0 else Vector2.ZERO),
		"fire": phase >= 2.0,
	}
	if operator.rifle.state.mag == 0:
		operator.rifle.state.mag = int(operator.rifle.state.cfg.magazine)
	operator.aim_point = _ahead(30.0 + sin(_demo_t * 1.5) * 60.0)


# --- setup ---

func _make_targets() -> void:
	var cfg: Dictionary = Data.value("weapons", "targets", {})
	for placement in cfg.placements:
		var d := TargetDummy.new()
		d.name = "Target%d" % (targets.size() + 1)
		var p := layout.point_in(String(placement.space), placement.at)
		d.position = Vector3(p.x, 0, p.y)
		add_child(d)
		targets.append(d)


func _make_lighting() -> void:
	var l: Dictionary = deck_data.lighting
	_plain_env = Environment.new()
	_plain_env.background_mode = Environment.BG_COLOR
	_plain_env.background_color = Color(l.background_color)
	_plain_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_plain_env.ambient_light_color = Color(l.ambient_color)
	_plain_env.ambient_light_energy = float(l.ambient_energy)
	_plain_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env = WorldEnvironment.new()
	_env.environment = _plain_env
	add_child(_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(l.sun_color)
	sun.light_energy = float(l.sun_energy)
	sun.shadow_enabled = bool(l.sun_shadows)
	sun.directional_shadow_max_distance = float(l.sun_shadow_max_distance_m)
	sun.shadow_blur = float(l.sun_shadow_blur)
	sun.rotation_degrees = Vector3(float(l.sun_pitch_deg), float(l.sun_yaw_deg), 0)
	sun.visible = sun.light_energy > 0.0
	add_child(sun)


## The black-box check: the same look as the asset viewer (data/viewer.json "environment"),
## with glow, SSAO and volumetric fog on. Only used by captures.
func _set_postfx(on: bool) -> void:
	if not on:
		_env.environment = _plain_env
		return
	var e: Dictionary = Data.value("viewer", "environment", {})
	var env := _plain_env.duplicate() as Environment
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if e.tonemap == "agx" else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(e.exposure)
	env.glow_enabled = true
	env.glow_intensity = float(e.glow_intensity)
	env.glow_bloom = float(e.glow_bloom)
	env.glow_hdr_threshold = float(e.glow_hdr_threshold)
	env.ssao_enabled = true
	env.ssao_radius = float(e.ssao_radius)
	env.ssao_intensity = float(e.ssao_intensity)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(e.fog_density)
	env.volumetric_fog_albedo = Color(e.fog_albedo)
	env.volumetric_fog_emission = Color(e.fog_emission)
	env.volumetric_fog_anisotropy = float(e.fog_anisotropy)
	env.volumetric_fog_length = float(e.fog_length)
	_env.environment = env
