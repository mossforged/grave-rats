extends "res://src/sight/sight_deck.gd"
## Root of scenes/pirates/pirate_deck.tscn: the firefight. The junction and the cargo hold, the
## squad looting, cover on both sides, lock-to-cover, the suit and the run log.
## E door, Space lock to low cover, RMB aim over it, Backspace resets everything.

const CoverField := preload("res://src/cover/cover_field.gd")
const ShotTracer := preload("res://src/cover/shot_tracer.gd")
const ProtectionMark := preload("res://src/cover/protection_mark.gd")
const LockDriver := preload("res://src/cover/lock_driver.gd")
const Suit := preload("res://src/health/suit.gd")
const HealthHud := preload("res://src/health/health_hud.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const PirateSquad := preload("res://src/pirates/pirate_squad.gd")
const HitTally := preload("res://src/pirates/hit_tally.gd")

var cover: CoverField
var tracer: ShotTracer
var mark: ProtectionMark
var driver: LockDriver
var suit: Suit
var suit_hud: HealthHud
var squad: PirateSquad
var run_log: RunLog
var killed_by_text := ""

var _health_cfg: Dictionary
var _cover_cfg: Dictionary
var _pirate_cfg: Dictionary
var _tally: HitTally
var _brace_left := 0.0
var _sprint_noise_left := 0.0
var _kick := 0.0
var _kick_full := 0.0
var _kick_recover := 1.0
var _ready_done := false
var _hold_squad := false       # captures only: the squad stays exactly where the shot put it
var _shot_light: OmniLight3D
var _shot_legacy: Node3D


func _ready() -> void:
	_health_cfg = Data.load_data("health")
	_cover_cfg = Data.load_data("cover")
	_pirate_cfg = Data.load_data("pirates")
	super()
	cover = CoverField.new(_cover_cfg)
	for i in layout.props.size():
		var p: Dictionary = layout.props[i]
		cover.set_piece(i, p.rect, String(p.cover))
	suit = Suit.new(_health_cfg)
	var big := float(_health_cfg.stagger.threshold_fraction) * float(_health_cfg.suit.max)
	_tally = HitTally.new(float(_pirate_cfg.big_hit.window_s), big)
	suit_hud = HealthHud.new()
	suit_hud.name = "SuitHud"
	add_child(suit_hud)
	hud.suit = suit
	mark = ProtectionMark.new()
	mark.name = "ProtectionMark"
	add_child(mark)
	hud.mark = mark
	squad = PirateSquad.new()
	squad.name = "Squad"
	add_child(squad)
	squad.setup(layout, cover, sight.visibility.blocked, sight.visibility, doors.doors, get_world_3d(), float(deck_data.character_scale))
	squad.set_mask(mask.visible_texture(), sight.bounds)
	squad.light_on = func(p: Vector2) -> bool: return flashlight.on and sight.visibility.in_light(_eye(), operator.gun_yaw(), p)
	squad.player_body.radius = float(_pirate_cfg.hit_radius_m)
	squad.player_body.on_hit = _on_round_landed
	var characters: Array[RID] = [operator.get_rid()]
	for p: Node in squad.pirates:
		characters.append(p.get_rid())
	tracer = ShotTracer.new(cover, get_world_3d())
	tracer.exclude = characters
	tracer.bodies = squad.pirates
	tracer.cover_stopped.connect(func(_b: Object) -> void: run_log.note_your_shot_blocked())
	operator.rifle.shot_tracer = tracer.trace
	operator.rifle.fired.connect(_on_rifle_fired)
	squad.tracer.exclude = characters
	squad.tracer.cover_stopped.connect(func(_b: Object) -> void: run_log.note_shot_blocked_for_you())
	driver = LockDriver.new()
	driver.name = "LockDriver"
	add_child(driver)
	driver.setup(operator, cover, _cover_cfg.lock, func(p: Vector2, r: float) -> bool: return layout.is_free(p, r))
	run_log = RunLog.new()
	run_log.enabled = not _capture
	_ready_done = true
	_sync_target()


## The deck this scene plays on, in a copy: the hold, the junction and the side corridor, with the
## medbay gone, doors unlocked for the flank routes, and more to hide behind.
func _make_lighting() -> void:
	super()
	var d: Dictionary = Data.value("pirates", "deck", {})
	var keep: Array = d.keep_spaces
	deck_data.spaces = (deck_data.spaces as Array).filter(func(s: Dictionary) -> bool: return keep.has(s.name))
	deck_data.doors = (d.doors as Array).duplicate(true)
	deck_data.props = (d.props as Array).duplicate(true)
	deck_data.spawn = d.spawn


func _make_targets() -> void:
	pass


func _help_text() -> String:
	return String(Data.value("pirates", "help", {}).text)


func _noise_senses() -> Dictionary:
	return (Data.value("pirates", "senses") as Dictionary)


func respawn() -> void:
	super()
	if not _ready_done:
		return
	if run_log.time_alive_s > 0.0:
		run_log.write("respawn")
	run_log.begin()
	driver.release()
	suit.reset()
	_tally.clear()
	suit_hud.show_death("")
	operator.release_control()
	operator.crouch_shown = 1.0
	killed_by_text = ""
	_brace_left = 0.0
	_kick = 0.0
	var specs: Array = deck_data.doors
	for i in specs.size():
		doors.doors[i].reset(String(specs[i].get("state", "closed")))
	squad.reset()
	sight.refresh_occluders()
	_sync_target()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and run_log and run_log.time_alive_s > 0.0:
		run_log.write("quit")


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not _ready_done:
		return
	simulate_world(delta)


## One step of the world around the operator; public so tests can drive it with exact deltas.
func simulate_world(delta: float) -> void:
	if suit.dead:
		driver.release()
	driver.step(delta)
	_step_brace(delta)
	_sync_target()
	suit.step(delta)
	_tally.step(delta)
	var pos := _eye()
	if not suit.dead:
		run_log.note_time(delta)
		if driver.lock.locked():
			run_log.note_locked(delta)
		_step_noise(delta, pos)
	if not _hold_squad:
		squad.tick(delta)
	mark.set_lines(squad.shooter_lines() if not suit.dead else [])
	mark.set_in_cover(in_cover_now())


func _sync_target() -> void:
	squad.target = {"pos": _eye(), "height": body_height(), "alive": not suit.dead}


## Crouched and tucked in beside something, and not up over it.
func in_cover_now() -> bool:
	var m: Dictionary = _cover_cfg.mark
	return not suit.dead and _brace_left <= 0.0 and not driver.lock.exposed() \
			and operator.model.crouch_amount >= float(m.in_cover_min_crouch) and cover.near(_eye(), float(m.in_cover_reach_m))


## The torso a shot at the player aims for right now.
func body_height() -> float:
	return cover.torso_height(operator.model.crouch_amount, _brace_left > 0.0 or driver.lock.exposed())


func _step_brace(delta: float) -> void:
	_brace_left = maxf(_brace_left - delta, 0.0)
	var shown := float(_cover_cfg.brace_crouch_shown)
	if driver.lock.locked():
		operator.crouch_shown = lerpf(1.0, shown, driver.lock.raise)
		return
	var want := shown if _brace_left > 0.0 else 1.0
	operator.crouch_shown = move_toward(operator.crouch_shown, want, float(_cover_cfg.brace_rate_per_s) * delta)


func _step_noise(delta: float, pos: Vector2) -> void:
	_sprint_noise_left -= delta
	var kind: String = operator.model.noise_kind()
	if kind != "" and _sprint_noise_left <= 0.0:
		_sprint_noise_left = float(_pirate_cfg.senses.sprint_emit_s)
		squad.noise(kind, pos)


func _apply_camera_kick() -> void:
	super()
	if _kick <= 0.0:
		return
	var cam: Camera3D = rig.camera
	var dir := Vector2.from_angle(randf() * TAU) * _kick
	cam.h_offset += dir.x
	cam.v_offset += dir.y
	_kick = maxf(_kick - _kick_full / _kick_recover * get_process_delta_time(), 0.0)


func _start_kick(metres: float, recover_s: float) -> void:
	_kick_full = metres
	_kick = metres
	_kick_recover = recover_s


func _process(delta: float) -> void:
	super(delta)
	if not _ready_done:
		return
	doors.actors = [{"position": _eye(), "radius": operator.body_radius()}]
	for p: Node in squad.living():
		doors.actors.append({"position": p.floor_position(), "radius": float(_pirate_cfg.radius_m) * float(deck_data.character_scale)})
	driver.show_state(not suit.dead)
	hud.lock_state = driver.state_word() if not suit.dead else ""
	if panel and panel.visible:
		for p: Node in squad.pirates:
			p.light.apply_cfg()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed:
		driver.tap_fire()
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_SPACE:
			if not suit.dead:
				driver.press()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_R and driver.lock.locked():
			operator.request_reload()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_6:
			rig.set_preset(int(Data.value("camera", "default_preset")))
			get_viewport().set_input_as_handled()
			return
	super(event)


func _on_rifle_fired(from: Vector3, to: Vector3, _direction: Vector3, hit: Object) -> void:
	if operator.model.crouch_amount > 0.0 and not driver.lock.locked():
		_brace_left = float(_cover_cfg.brace_hold_s)
	run_log.note_shot(hit != null and hit.has_method("shot_disc"))
	squad.noise("gunfire", Vector2(from.x, from.z))
	squad.shot_at(Vector2(from.x, from.z), Vector2(to.x, to.z))


func _on_round_landed(hit: Dictionary) -> void:
	var who: String = hit.shooter.label
	_hurt("rifle", float(hit.damage), who, in_cover_now())


## Everything that hurts the suit comes through here.
func _hurt(source: String, amount: float, who: String, in_cover: bool) -> void:
	var result: Dictionary = suit.take(amount, source)
	if float(result.amount) <= 0.0:
		return
	run_log.note_damage(source, float(result.amount), in_cover)
	suit_hud.flash()
	if bool(result.staggered) or _tally.add(amount):
		_stagger()
	if bool(result.died):
		_die(who, source)


## A big hit: control gone for a moment, the cone blown wide, the view jolted.
func _stagger() -> void:
	var st: Dictionary = _health_cfg.stagger
	operator.hold_control(float(st.control_loss_s))
	operator.play_hit(float(st.control_loss_s))
	operator.rifle.cone.spread_deg = maxf(operator.rifle.cone.spread_deg, float(st.cone_deg))
	_start_kick(float(st.camera_kick_m), float(st.kick_recover_s))


func _die(who: String, how: String) -> void:
	operator.hold_control(INF)
	run_log.note_death(who, how, "pirate")
	run_log.write("death")
	killed_by_text = "%s: %s" % [who, how]
	suit_hud.show_death(killed_by_text)


# --- capture hooks (src/debug/capture.gd) ---

func capture_shots() -> Array[Dictionary]:
	if OS.get_environment("CAPTURE_HAULER") != "":
		return _hauler_shots()
	return [
		{"name": "deck_overview", "do": "overview"},
		{"name": "pirate_beside_operator", "do": "beside"},
		{"name": "squad_looting", "do": "looting"},
		{"name": "pirate_light_beside_yours", "do": "beam"},
		{"name": "pirate_braced_firing", "do": "braced"},
		{"name": "flank_1_called", "do": "flank", "wait": 0.5},
		{"name": "flank_2_moving", "do": "flank", "wait": 1.8},
		{"name": "flank_3_open_line", "do": "flank", "wait": -1.0},
		{"name": "lock_1_protected", "do": "lock", "aim": false},
		{"name": "lock_2_aiming_over", "do": "lock", "aim": true},
		{"name": "lock_prompt", "do": "prompt"},
		{"name": "death_screen", "do": "death"},
		{"name": "hud_locked", "do": "lock", "aim": false},
		{"name": "hud_locked_exposed", "do": "lock", "aim": true},
		{"name": "hud_shields_under_fire", "do": "flank", "wait": 1.8},
	]


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	release_shot()
	if panel:
		panel.visible = false
	sight_debug.visible = false
	rig.set_preset(int(Data.value("camera", "default_preset")))
	respawn()
	flashlight.set_on(true)
	operator.scripted = {}
	driver.scripted = {}
	_open_all_doors()
	var low := _piece_rect(5)
	var inside := Vector2(low.position.x - 0.7, low.get_center().y)
	match String(shot.do):
		"hauler":
			await _hauler_shot(String(shot.state))
		"hauler_beside":
			await _hauler_beside_shot(false)
		"hauler_legacy":
			await _hauler_beside_shot(true)
		"hauler_close":
			await _hauler_beside_shot(true, Vector3(0.0, 1.5, 3.2))
		"hauler_side":
			await _hauler_beside_shot(false, Vector3(3.0, 0.9, 0.9))
		"overview":
			await _show_room(Vector2(9.0, 8.8), Vector2(15.0, 8.8))
			mask.visible = false
			_hold_squad = true
			rig.set_process(false)
			var cam: Camera3D = rig.camera
			var mid := Vector3(9.0, 0.0, 9.5)
			cam.global_position = mid + Vector3(0.0, 27.0, 13.0)
			cam.look_at(mid)
		"beside":
			await _beside_shot()
		"looting":
			await _show_room(inside + Vector2(1.6, -2.5), squad.pirates[1].floor_position())
			await _sim(1.2)
		"beam":
			await _beam_shot()
		"braced":
			await _braced_shot()
		"flank":
			await _flank_shot(float(shot.wait))
		"lock":
			await _lock_shot(bool(shot.aim))
		"prompt":
			await _stand_at(inside + Vector2(-0.3, 0), low.get_center())
			await _sim(0.1)
		"death":
			await _stand_at(inside, low.get_center())
			_hurt("rifle", float(_health_cfg.suit.max), squad.pirates[0].label, false)
			await _sim(0.1)
	Engine.time_scale = 0.0


func _stand_at(p: Vector2, look: Vector2) -> void:
	await _stand(p, look)
	rig.aim_dir = operator.aim_dir()


func _piece_rect(i: int) -> Rect2:
	return layout.props[i].rect


func _open_all_doors() -> void:
	for d: Node in doors.doors:
		if d.door_state.blocks() and not d.door_state.is_locked():
			d.door_state.progress = 1.0
			d.door_state.state = d.door_state.State.OPEN
			d.tick(0.0, [])


func _show_room(p: Vector2, look: Vector2) -> void:
	await _stand_at(p, look)
	await _sim(0.2)


## Side by side, standing, up close and lit: the paint is the whole point of this one. Everything
## holds still; only the capture sees this camera.
func _beside_shot() -> void:
	var at := Vector2(11.8, 6.9)
	var q: Node = squad.pirates[0]
	await _stand_at(at, at + Vector2(0, 6))
	_hold_squad = true
	driver.hide_prompt = true
	hud.visible = false
	noise_ring.visible = false
	squad.hide_barks()
	for o: Node in squad.pirates:
		if o != q:
			o.global_position = Vector3(16.5, 0, 1.0)
	q.global_position = Vector3(at.x + 1.3, 0, at.y)
	q.brain.model.reset_motion()
	q.brain.model.face_now(q.brain.model.yaw_to(q.global_position, Vector3(at.x + 1.3, 0, at.y + 6)))
	q.anim.update(Vector2.ZERO, 1.0, 1.0, 0.0, 0.0, "aim", 1.0)
	q._visual.rotation.y = q.brain.model.hips_yaw
	q.get_node("SightTarget").set_seen(true)
	_shot_light = OmniLight3D.new()
	_shot_light.omni_range = 9.0
	_shot_light.light_energy = 3.0
	add_child(_shot_light)
	_shot_light.global_position = Vector3(at.x + 0.6, 3.5, at.y + 3.0)
	await _sim(0.15)
	rig.set_process(false)
	var cam: Camera3D = rig.camera
	var mid := Vector3(at.x + 0.65, 1.0, at.y)
	cam.global_position = mid + Vector3(0.0, 3.0, 2.9)
	cam.look_at(mid)
	await _sim(0.05)


func release_shot() -> void:
	super()
	if _shot_legacy:
		_shot_legacy.free()
		_shot_legacy = null
	_hold_squad = false
	driver.hide_prompt = false
	hud.visible = true
	mask.visible = true
	rig.set_process(true)
	if _shot_light:
		_shot_light.queue_free()
		_shot_light = null


## T009: the hauler at the default camera, state by state (env CAPTURE_HAULER=1).
func _hauler_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for state: String in ["idle", "walk", "run", "sprint", "strafe", "crouch", "crouch_walk", "aiming", "reload", "rolling", "dead"]:
		shots.append({"name": "hauler_%s" % state, "do": "hauler", "state": state})
	shots.append({"name": "hauler_beside_pirate", "do": "hauler_beside"})
	shots.append({"name": "hauler_pirate_legacy", "do": "hauler_legacy"})
	shots.append({"name": "hauler_close_up", "do": "hauler_close"})
	shots.append({"name": "hauler_close_side", "do": "hauler_side"})
	return shots


func _hauler_stage() -> Vector2:
	var at := Vector2(11.8, 6.9)
	await _stand_at(at, at + Vector2(0, 6))
	_hold_squad = true
	driver.hide_prompt = true
	squad.hide_barks()
	_shot_light = OmniLight3D.new()
	_shot_light.omni_range = 9.0
	_shot_light.light_energy = 3.0
	add_child(_shot_light)
	_shot_light.global_position = Vector3(at.x + 0.6, 3.5, at.y + 3.0)
	return at


func _hauler_shot(state: String) -> void:
	var at := await _hauler_stage()
	for o: Node in squad.pirates:
		o.global_position = Vector3(16.5, 0, 1.0)
	var away := Vector2(0, 1)
	match state:
		"idle":
			await _sim(0.6)
		"walk":
			operator.scripted = {"keys": away}
			await _sim(0.08)
		"run":
			operator.scripted = {"keys": away}
			await _sim(0.5)
		"sprint":
			operator.scripted = {"keys": away, "sprint": true}
			await _sim(0.5)
		"strafe":
			operator.scripted = {"keys": Vector2(1, 0)}
			await _sim(0.5)
		"crouch":
			operator.scripted = {"crouch": true}
			await _sim(0.5)
		"crouch_walk":
			operator.scripted = {"keys": away, "crouch": true}
			await _sim(0.6)
		"aiming":
			operator.aim_point = Vector3(at.x + 5.0, _aim_height, at.y + 2.0)
			operator.scripted = {"fire": true}
			await _sim(0.5)
		"reload":
			operator.rifle.state.mag = 0
			operator.request_reload()
			await _sim(0.7)
		"rolling":
			operator.anim.play_state("roll")
			await _sim(0.55)
		"dead":
			operator.hold_control(INF)
			await _sim(3.2)


## Beside a pirate at the default camera; with `legacy` the old operator on your other side; with
## a non-zero `close` the camera moved in to that offset.
func _hauler_beside_shot(legacy: bool, close := Vector3.ZERO) -> void:
	var at := await _hauler_stage()
	var moved_in := close != Vector3.ZERO
	hud.visible = not moved_in
	noise_ring.visible = not moved_in
	var q: Node = squad.pirates[0]
	for o: Node in squad.pirates:
		if o != q:
			o.global_position = Vector3(16.5, 0, 1.0)
	q.global_position = Vector3(at.x + 1.3, 0, at.y)
	q.brain.model.reset_motion()
	q.brain.model.face_now(q.brain.model.yaw_to(q.global_position, q.global_position + Vector3(0, 0, 6)))
	q.anim.update(Vector2.ZERO, 1.0, 1.0, 0.0, 0.0, "aim", 1.0)
	q._visual.rotation.y = q.brain.model.hips_yaw
	q.get_node("SightTarget").set_seen(true)
	if legacy:
		var Body: GDScript = operator.OperatorBody
		Body.forced = "legacy"
		_shot_legacy = (operator.get_script() as GDScript).new()
		add_child(_shot_legacy)
		Body.forced = ""
		_shot_legacy.input_enabled = false
		_shot_legacy.set_character_scale(float(Data.value("deck", "character_scale", 1.0)))
		_shot_legacy.visuals.visible = false
		_shot_legacy.global_position = Vector3(at.x - 1.3, 0, at.y)
		_shot_legacy.face_now(_shot_legacy.global_position + Vector3(0, _aim_height, 6))
	await _sim(0.5)
	if moved_in:
		rig.set_process(false)
		var cam: Camera3D = rig.camera
		var mid := Vector3(at.x, 1.05, at.y)
		cam.global_position = mid + close
		cam.look_at(mid)
		await _sim(0.05)


## A pirate coming along the south wall, its colder light crossing yours.
func _beam_shot() -> void:
	var c := _piece_rect(11)
	var me := Vector2(c.get_center().x - 3.5, c.position.y - 2.5)
	await _stand_at(me, me + Vector2(4.0, 2.0))
	var q: Node = squad.pirates[2]
	q.global_position = Vector3(c.end.x + 1.0, 0, c.end.y + 0.1)
	q.brain.model.face_now(q.brain.model.yaw_to(q.global_position, Vector3(me.x, 0, me.y)))
	await _sim(0.4)


## A pirate over low cover, firing at you in the open. The rest are out of this one.
func _braced_shot() -> void:
	var r := _piece_rect(11)
	var hide := Vector2(r.end.x + 0.6, r.get_center().y)
	var me := Vector2(r.position.x - 3.6, r.get_center().y)
	await _stand_at(me, hide)
	suit.reset()
	var q: Node = squad.pirates[0]
	for o: Node in squad.pirates:
		if o != q:
			o.global_position = Vector3(16.5, 0, 9.0)
			o.brain.take_hit(INF)
	q.global_position = Vector3(hide.x, 0, hide.y)
	q.brain.model.face_now(q.brain.model.yaw_to(q.global_position, Vector3(me.x, 0, me.y)))
	q.brain.order(squad.Tactics.Role.SUPPORT, {"hide": hide, "fire": hide, "kind": "low", "id": 11})
	squad.alert(me)
	var left := 4.0
	while left > 0.0 and not (q.brain.state == q.brain.State.BURST and q.brain.gun.camera_kick_m >= 0.0 and q.fx._flash.visible):
		await get_tree().process_frame
		left -= get_process_delta_time()
		suit.reset()
	# The hit flash reds out the whole frame, and this shot is about the pirate.
	suit_hud._flash_left = 0.0
	suit_hud._flash.visible = false


## You behind low cover near the door; the suppressor keeps you down and the flanker goes round.
## `wait` < 0: until the flanker has its open line.
func _flank_shot(wait: float) -> void:
	var low := _piece_rect(5)
	var me := Vector2(low.position.x - 0.6, low.get_center().y)
	await _stand_at(me, Vector2(14.0, 5.0))
	operator.scripted = {"crouch": true}
	await _sim(0.3)
	squad.alert(me)
	var left := wait if wait >= 0.0 else 12.0
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		suit.reset()
		squad.alert(me)
		if wait < 0.0:
			var f: Node = squad.with_role(squad.Tactics.Role.FLANK)
			if f and f.brain.dug_in() and squad.spots.open_line(f.floor_position(), me, float(_cover_cfg.crouched_torso_m)):
				break
	# Frame the flanker with you.
	var fl: Node = squad.with_role(squad.Tactics.Role.FLANK)
	if fl:
		operator.aim_point = Vector3(fl.global_position.x, _aim_height, fl.global_position.z)
		await _sim(0.5)
		suit.reset()


func _lock_shot(aim: bool) -> void:
	var low := _piece_rect(5)
	var me := Vector2(low.position.x - 0.8, low.get_center().y)
	var far := Vector2(13.5, low.get_center().y)
	await _stand_at(me, far)
	driver.press()
	driver.scripted = {"aim": aim}
	await _sim(float(_cover_cfg.lock.snap_s) + float(_cover_cfg.lock.raise_s) + 0.2)
	if aim:
		driver.scripted = {"aim": true, "fire": true}
		await _sim(0.15)


## Measuring window: the squad hunting you through the open door, all three fighting. Nobody dies,
## so the whole window counts.
func _demo_step(delta: float) -> void:
	var door: Node = _door("cargo", 0.6)
	if _demo_t == 0.0:
		_open_all_doors()
		var p := _door_side(door, 1.0, 2.5)
		operator.global_position = Vector3(p.x, 0, p.y)
		rig.snap()
		squad.alert(p)
	_demo_t += delta
	suit.reset()
	operator.release_control()
	for q: Node in squad.pirates:
		q.brain.suit.reset()
		q.brain.fell_back = false
	squad.contact_age = 0.0
	var phase := fmod(_demo_t, 4.0)
	operator.scripted = {"keys": Vector2(0, -1) if phase < 1.0 else (Vector2(0, 1) if phase < 2.0 else Vector2.ZERO), "fire": phase >= 2.0}
	if operator.rifle.state.mag == 0:
		operator.rifle.state.mag = int(operator.rifle.state.cfg.magazine)
	operator.aim_point = _ahead(90.0 + sin(_demo_t * 1.5) * 50.0)
