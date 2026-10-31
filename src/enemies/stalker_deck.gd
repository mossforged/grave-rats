extends "res://src/sight/sight_deck.gd"
## Root of scenes/enemies/stalker_deck.tscn: the grey-box core loop. Sight deck plus cover, tipping
## beds, the suit, two stalkers, the bulkhead ambush and the run log. E tips a bed or works a door;
## Backspace resets everything and starts a new life.

const CoverField := preload("res://src/cover/cover_field.gd")
const ShotTracer := preload("res://src/cover/shot_tracer.gd")
const TipBed := preload("res://src/cover/tip_bed.gd")
const ProtectionMark := preload("res://src/cover/protection_mark.gd")
const Suit := preload("res://src/health/suit.gd")
const HealthHud := preload("res://src/health/health_hud.gd")
const StalkerPack := preload("res://src/enemies/stalker_pack.gd")
const Bulkhead := preload("res://src/enemies/bulkhead.gd")
const AmbushTrigger := preload("res://src/enemies/ambush_trigger.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
## Hurts that come from no one, so no flash and no hit.
const QUIET_HURTS := ["puddle", "oxygen"]

var cover: CoverField
var tracer: ShotTracer
var beds: Array = []
var mark: ProtectionMark
var suit: Suit
var suit_hud: HealthHud
var pack: StalkerPack
var bulkhead: Bulkhead
var ambush: AmbushTrigger
var run_log: RunLog
var killed_by_text := ""

var _health_cfg: Dictionary
var _cover_cfg: Dictionary
var _ambush_cfg: Dictionary
var _bed_specs: Array = []
var _bed_prompt: Label3D
var _brace_left := 0.0
var _sprint_noise_left := 0.0
var _emerge_left := -1.0
var _kick := 0.0
var _kick_full := 0.0
var _kick_recover := 1.0
var _ready_done := false


func _ready() -> void:
	_health_cfg = Data.load_data("health")
	_cover_cfg = Data.load_data("cover")
	_ambush_cfg = (Data.load_data("enemies") as Dictionary).ambush
	super()
	cover = CoverField.new(_cover_cfg)
	for i in layout.props.size():
		var p: Dictionary = layout.props[i]
		cover.set_piece(i, p.rect, String(p.cover))
	_make_beds()
	_make_bulkhead()
	sight.refresh_occluders()
	suit = Suit.new(_health_cfg)
	suit_hud = HealthHud.new()
	suit_hud.name = "SuitHud"
	add_child(suit_hud)
	hud.suit = suit
	mark = ProtectionMark.new()
	mark.name = "ProtectionMark"
	add_child(mark)
	hud.mark = mark
	pack = StalkerPack.new()
	pack.name = "Pack"
	add_child(pack)
	pack.setup(layout, cover, sight.visibility.blocked, float(_health_cfg.acid.puddle_dps))
	pack.light_on = func(p: Vector2) -> bool: return flashlight.on and sight.visibility.in_light(_eye(), operator.gun_yaw(), p)
	pack.player_hit.connect(_on_player_hit)
	pack.player_protected.connect(_on_player_protected)
	for bed: TipBed in beds:
		pack.nav.set_blocker(bed, bed.footprint())
		bed.footprint_changed.connect(func(b: TipBed) -> void: pack.nav.set_blocker(b, b.footprint()))
	for d: Node in doors.doors:
		_on_door_changed(d)
		d.state_changed.connect(_on_door_changed)
	pack.nav.set_blocker(bulkhead, bulkhead.rect)
	ambush = AmbushTrigger.new(_ambush_cfg, bulkhead.panel_center())
	tracer = ShotTracer.new(cover, get_world_3d())
	tracer.exclude = operator.rifle.exclude
	tracer.bodies = pack.stalkers
	operator.rifle.shot_tracer = tracer.trace
	operator.rifle.fired.connect(_on_rifle_fired)
	run_log = RunLog.new()
	run_log.enabled = not _capture
	_bed_prompt = Label3D.new()
	_bed_prompt.name = "BedPrompt"
	_bed_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bed_prompt.no_depth_test = true
	_bed_prompt.pixel_size = float(_cover_cfg.bed.prompt_pixel_size)
	_bed_prompt.font_size = int(_cover_cfg.bed.prompt_font_size)
	_bed_prompt.modulate = Color(String(_cover_cfg.bed.prompt_color))
	_bed_prompt.text = String(_cover_cfg.bed.prompt)
	_bed_prompt.visible = false
	add_child(_bed_prompt)
	_ready_done = true
	_sync_target()


## The deck this scene plays on, in a copy: the closet behind the panel, the spawn past it, no
## dummies, and tippable beds lifted out of the static props (they become TipBeds here).
func _make_lighting() -> void:
	super()
	var a: Dictionary = Data.value("enemies", "ambush", {})
	(deck_data.spaces as Array).append(a.closet)
	deck_data.breaches = [a.breach]
	deck_data.spawn = a.spawn
	_bed_specs = (deck_data.props as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("tippable", false)))
	deck_data.props = (deck_data.props as Array).filter(func(p: Dictionary) -> bool: return not bool(p.get("tippable", false)))


func _make_targets() -> void:
	pass


func _make_beds() -> void:
	for spec: Dictionary in _bed_specs:
		var c := layout.point_in(String(spec.space), spec.at)
		var s: Array = spec.size_m
		var bed := TipBed.new()
		add_child(bed)
		bed.setup(spec, Rect2(c.x - float(s[0]) * 0.5, c.y - float(s[2]) * 0.5, float(s[0]), float(s[2])), cover, _cover_cfg.bed)
		beds.append(bed)


func _make_bulkhead() -> void:
	bulkhead = Bulkhead.new()
	add_child(bulkhead)
	bulkhead.setup(layout.breaches[0], _ambush_cfg, float(deck_data.wall_height_m))
	bulkhead.use_mask(mask.bind)


func _help_text() -> String:
	return String(Data.value("enemies", "help", {}).text)


## Everything back; the life that just ended (if nobody wrote it yet) goes to the log.
func respawn() -> void:
	super()
	if not _ready_done:
		return
	if run_log.time_alive_s > 0.0:
		run_log.write("respawn")
	run_log.begin()
	suit.reset()
	suit_hud.show_death("")
	operator.release_control()
	operator.crouch_shown = 1.0
	killed_by_text = ""
	_brace_left = 0.0
	_emerge_left = -1.0
	_kick = 0.0
	for bed: TipBed in beds:
		bed.reset()
	var specs: Array = deck_data.doors
	for i in specs.size():
		doors.doors[i].reset(String(specs[i].get("state", "closed")))
	bulkhead.reset()
	pack.nav.set_blocker(bulkhead, bulkhead.rect)
	ambush.reset()
	pack.reset()
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
	_step_brace(delta)
	_sync_target()
	suit.step(delta)
	for bed: TipBed in beds:
		bed.tick(delta)
	var pos := _eye()
	if not suit.dead:
		run_log.note_time(delta)
		_step_noise(delta, pos)
		_step_acid(delta, pos)
		if ambush.check(pos, Vector2(operator.aim_dir().x, operator.aim_dir().z)):
			fire_ambush()
	_step_emerge(delta)
	bulkhead.tick(delta)
	pack.tick(delta)
	mark.set_lines(pack.shooter_lines() if not suit.dead else [])
	mark.set_in_cover(in_cover_now())


func _sync_target() -> void:
	pack.target = {"pos": _eye(), "height": body_height(), "alive": not suit.dead}


## Crouched and tucked in beside something, and not rising to fire over it.
func in_cover_now() -> bool:
	var m: Dictionary = _cover_cfg.mark
	return not suit.dead and _brace_left <= 0.0 and operator.model.crouch_amount >= float(m.in_cover_min_crouch) \
			and cover.near(_eye(), float(m.in_cover_reach_m))


## The torso a shot at the player aims for right now.
func body_height() -> float:
	return cover.torso_height(operator.model.crouch_amount, _brace_left > 0.0)


func _step_brace(delta: float) -> void:
	_brace_left = maxf(_brace_left - delta, 0.0)
	var want := float(_cover_cfg.brace_crouch_shown) if _brace_left > 0.0 else 1.0
	operator.crouch_shown = move_toward(operator.crouch_shown, want, float(_cover_cfg.brace_rate_per_s) * delta)


func _step_noise(delta: float, pos: Vector2) -> void:
	_sprint_noise_left -= delta
	var kind: String = operator.model.noise_kind()
	if kind != "" and _sprint_noise_left <= 0.0:
		_sprint_noise_left = float(pack.cfg.senses.sprint_emit_s)
		pack.noise(kind, pos)


func _step_acid(delta: float, pos: Vector2) -> void:
	var dmg: float = pack.spits.puddles.damage_at(pos, delta)
	hud.in_acid = dmg > 0.0
	if dmg <= 0.0:
		return
	var owner_name := String(pack.spits.puddles.puddle_at(pos).owner)
	_hurt("puddle", dmg, owner_name, not mark.lines.is_empty() and mark.protected_count() == mark.lines.size())


func _step_emerge(delta: float) -> void:
	if _emerge_left < 0.0:
		return
	_emerge_left -= delta
	if _emerge_left <= 0.0:
		_emerge_left = -1.0
		pack.nav.set_blocker(bulkhead, Rect2())
		for s: Node in pack.stalkers:
			if s.brain.state == s.brain.State.DORMANT:
				s.brain.wake(_eye(), s.floor_position())


## The burst: bang, kick, debris, then it comes out. The player hears it first.
func fire_ambush() -> void:
	bulkhead.blow()
	var c := bulkhead.panel_center()
	pack.play_sound("bang", Vector3(c.x, float(deck_data.wall_height_m) * 0.5, c.y))
	_emerge_left = float(_ambush_cfg.emerge_delay_s)
	_start_kick(float(_ambush_cfg.camera_kick_m), float(_ambush_cfg.camera_kick_recover_s))


func _start_kick(metres: float, recover_s: float) -> void:
	_kick_full = metres
	_kick = metres
	_kick_recover = recover_s


## The rifle's own kick (weight_deck), plus a shake from anything heavier.
func _apply_camera_kick() -> void:
	super()
	if _kick <= 0.0:
		return
	var cam: Camera3D = rig.camera
	var dir := Vector2.from_angle(randf() * TAU) * _kick
	cam.h_offset += dir.x
	cam.v_offset += dir.y
	_kick = maxf(_kick - _kick_full / _kick_recover * get_process_delta_time(), 0.0)


func _process(delta: float) -> void:
	super(delta)
	if not _ready_done:
		return
	doors.actors = [{"position": _eye(), "radius": operator.body_radius()}]
	for s: Node in pack.stalkers:
		if s.brain.alive():
			doors.actors.append({"position": s.floor_position(), "radius": float(pack.cfg.radius_m)})
	var bed := bed_in_reach(_eye())
	_bed_prompt.visible = bed != null and not suit.dead and not operator.control_held()
	if bed:
		var c: Vector2 = bed.upright_rect.get_center()
		_bed_prompt.global_position = Vector3(c.x, float(_cover_cfg.bed.prompt_height_m), c.y)


func bed_in_reach(p: Vector2) -> TipBed:
	var best: TipBed = null
	var best_d := float(_cover_cfg.bed.reach_m)
	for bed: TipBed in beds:
		var d: float = bed.distance_to_point(p)
		if bed.can_tip() and d <= best_d:
			best = bed
			best_d = d
	return best


## E: a bed in reach comes before a door. Starts the same step, then holds you for the tip.
func interact() -> void:
	if suit.dead or operator.control_held():
		return
	var bed := bed_in_reach(_eye())
	if bed and bed.try_tip(_eye()):
		operator.hold_control(float(_cover_cfg.bed.tip_s))
		return
	doors.interact(_eye())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_E:
		interact()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_6:
		rig.set_preset(int(Data.value("camera", "default_preset")))
		get_viewport().set_input_as_handled()
		return
	super(event)


func _on_door_changed(d: Node) -> void:
	pack.nav.set_blocker(d, d.opening if d.door_state.blocks() else Rect2(), not d.door_state.is_locked())


func _on_rifle_fired(from: Vector3, to: Vector3, _direction: Vector3, hit: Object) -> void:
	if operator.model.crouch_amount > 0.0:
		_brace_left = float(_cover_cfg.brace_hold_s)
	run_log.note_shot(hit != null and hit.has_method("shot_disc"))
	pack.noise("gunfire", Vector2(from.x, from.z))
	pack.shot_at(Vector2(from.x, from.z), Vector2(to.x, to.z))


func _on_player_hit(source: String, amount: float, stalker: Node3D, in_cover: bool) -> void:
	note_hit_from(stalker.floor_position(), source)
	_hurt(source, amount, stalker.label, in_cover)


func _on_player_protected(_stalker: Node3D) -> void:
	run_log.note_protected()


## Everything that hurts the suit comes through here.
func _hurt(source: String, amount: float, who: String, in_cover: bool) -> void:
	var result: Dictionary = suit.take(amount, source)
	if float(result.amount) <= 0.0:
		return
	run_log.note_damage(source, float(result.amount), in_cover)
	if not QUIET_HURTS.has(source):
		suit_hud.flash()
	if bool(result.staggered):
		_stagger()
	if bool(result.died):
		_die(who, source)


## A big hit: control gone for a moment, the cone blown wide, the view jolted.
func _stagger() -> void:
	var st: Dictionary = _health_cfg.stagger
	operator.hold_control(float(st.control_loss_s))
	operator.rifle.cone.spread_deg = maxf(operator.rifle.cone.spread_deg, float(st.cone_deg))
	_start_kick(float(st.camera_kick_m), float(st.kick_recover_s))


func _die(who: String, how: String) -> void:
	operator.hold_control(INF)
	run_log.note_death(who, how, _killer_kind(how))
	run_log.write("death")
	killed_by_text = "%s: %s" % [who, how]
	suit_hud.show_death(killed_by_text)


## What the run log calls whatever did this.
func _killer_kind(_how: String) -> String:
	return "stalker"


# --- capture hooks (src/debug/capture.gd) ---

func capture_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = [
		{"name": "camera_default", "do": "camera", "preset": int(Data.value("camera", "default_preset"))},
		{"name": "camera_preset_1", "do": "camera", "preset": 0},
		{"name": "junction_default", "do": "junction"},
		{"name": "dash_mid_motion", "do": "dash"},
		{"name": "dodge", "do": "dodge"},
		{"name": "spit_windup_fast", "do": "windup"},
		{"name": "lunge_charge", "do": "lunge"},
		{"name": "door_mid_bash", "do": "bash", "done": 0.6},
		{"name": "door_broken", "do": "bash", "done": 1.0},
		{"name": "in_cover_readout", "do": "cover_alone"},
		{"name": "cover_protected", "do": "cover"},
		{"name": "cover_braced_exposed", "do": "braced"},
		{"name": "light_off_hud", "do": "light_off"},
		{"name": "ambush_1_bang", "do": "ambush", "wait": 0.05},
		{"name": "ambush_2_out_and_dashing", "do": "ambush", "wait": 0.45},
		{"name": "ambush_3_lunging", "do": "ambush", "wait": 1.0},
		{"name": "death_screen", "do": "death"},
		{"name": "flicker_fixed", "do": "flicker", "beam": true},
		{"name": "flicker_fixed_beam_off", "do": "flicker", "beam": false},
		{"name": "hud_rest", "do": "ring", "keys": Vector2.ZERO},
		{"name": "hud_walk", "do": "ring", "keys": Vector2(0, 1)},
		{"name": "hud_crouch_walk", "do": "ring", "keys": Vector2(0, 1), "crouch": true},
		{"name": "hud_sprint", "do": "ring", "keys": Vector2(0, 1), "sprint": true},
		{"name": "hud_fire_bloom", "do": "fire", "wait": 0.1},
		{"name": "hud_fire_shrinking", "do": "fire", "wait": 1.2},
		{"name": "hud_tense", "do": "tense"},
		{"name": "t011_cutaway_fade", "do": "kit_cutaway", "mode": "fade"},
		{"name": "t011_cutaway_off", "do": "kit_cutaway", "mode": "off"},
		{"name": "t011_faded_walls_under_mask", "do": "kit_cutaway", "mode": "fade", "view": "play"},
		{"name": "t011_rooms_medbay", "do": "kit_room", "space": "medbay", "at": [0.5, 0.45]},
		{"name": "t011_rooms_junction", "do": "kit_room", "space": "junction", "at": [0.5, 0.25]},
		{"name": "t011_rooms_cargo", "do": "kit_room", "space": "cargo", "at": [0.55, 0.55]},
		{"name": "t011_rooms_corridor", "do": "kit_room", "space": "side_corridor", "at": [0.4, 0.5]},
	]
	shots.append_array(_kit_shots())
	shots.append({"name": "t011_ambush_tell", "do": "kit_tell"})
	return shots


## T010: the four A006 paint-over frames, each with no mask, with everything known, and in play;
## a door in each state, seen from the front and from the side.
func _kit_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for frame: String in ["01b", "02b", "03c", "04b"]:
		for view: String in ["off", "known", "play"]:
			shots.append({"name": "t011_%s_%s" % [frame, view], "do": "kit_frame", "frame": frame, "view": view})
	for state: String in ["closed", "open", "locked", "bashed", "broken"]:
		shots.append({"name": "t011_door_%s_front" % state, "do": "kit_door", "state": state, "space": "side_corridor", "at": 0.8})
		shots.append({"name": "t011_door_%s_side" % state, "do": "kit_door", "state": state, "space": "medbay", "at": 0.7})
	return shots


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	mask.visible = true
	rig.set_cutaway_mode(String(rig.cutaway.mode))
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	flashlight._beam.visible = true
	var hunter: Node = pack.stalkers[0]
	var bed: TipBed = beds[2]
	var r: Rect2 = bed.footprint()
	var behind := Vector2(r.position.x - float(_cover_cfg.bed.reach_m) * 0.5, r.get_center().y)
	var infront := Vector2(r.end.x + float(pack.cfg.spit.short_range_m) * 1.5, r.get_center().y)
	match String(shot.do):
		"cover":
			await _open_medbay_door()
			await _crouch_at(behind, infront)
			_hunt_from(hunter, infront, behind)
			await _sim(0.25)
		"braced":
			await _open_medbay_door()
			await _crouch_at(behind, infront)
			_hunt_from(hunter, infront, behind)
			operator.scripted = {"crouch": true, "fire": true}
			await _sim(0.3)
		"camera":
			rig.set_preset(int(shot.preset))
			await _open_medbay_door()
			await _stand_at(behind, behind + Vector2(-float(pack.cfg.lunge.range_m), 0))
		"junction":
			await _stand_at(layout.point_in("junction", [0.5, 0.4]), layout.point_in("junction", [0.5, 0.1]))
		"dash":
			await _open_medbay_door()
			var far := behind + Vector2(-float(pack.cfg.lunge.range_m), 0)
			await _stand_at(behind, far)
			_hunt_from(hunter, far + Vector2(-float(pack.cfg.lunge.range_m), 0), behind)
			hunter.brain._lunge_cd = INF
			hunter.brain._spit_cd = INF
			await _until_dash(hunter)
		"dodge":
			await _open_medbay_door()
			var at := behind + Vector2(-float(pack.cfg.lunge.range_m) * 1.2, 0)
			await _stand_at(behind, at)
			_hunt_from(hunter, at, behind)
			hunter.brain._lunge_cd = INF
			hunter.brain._spit_cd = INF
			await _sim(0.05)
			hunter.take_hit({"damage": 1.0, "origin": operator.global_position})
			await _sim(float(pack.cfg.dodge.max_s) * 0.6)
		"bash":
			await _bash_shot(hunter, float(shot.done))
		"cover_alone":
			await _crouch_at(behind, infront)
		"light_off":
			await _open_medbay_door()
			await _stand_at(behind, behind + Vector2(-float(pack.cfg.lunge.range_m), 0))
			flashlight.set_on(false)
			await _sim(0.1)
		"windup":
			await _open_medbay_door()
			await _stand_at(behind, infront)
			_hunt_from(hunter, infront, behind)
			hunter.brain.force_spit()
			await _sim(float(pack.cfg.spit.windup_s) * 0.8)
		"puddle":
			await _open_medbay_door()
			await _stand_at(behind, infront)
			var near := behind + Vector2(float(pack.cfg.puddle.radius_m) * 2.0, 0)
			pack.spits.add_puddle(near, hunter.label)
			pack.spits.add_puddle(infront + Vector2(0, -float(pack.cfg.puddle.radius_m)), hunter.label)
			_hunt_from(hunter, infront, behind)
			await _sim(0.2)
		"lunge", "recover":
			await _open_medbay_door()
			await _stand_at(behind, infront)
			# Across open floor to the west, so nothing stops the charge.
			var spot := behind + Vector2(-float(pack.cfg.lunge.range_m), 0)
			await _stand_at(behind, spot)
			_hunt_from(hunter, spot, behind)
			hunter.brain.force_lunge()
			await _sim(float(pack.cfg.lunge.windup_s) + 0.1)
			if shot.do == "recover":
				while hunter.brain.state != hunter.brain.State.RECOVER:
					await get_tree().process_frame
				await _sim(0.25)
		"ambush":
			await _ambush_shot(float(shot.wait))
		"death":
			await _stand_at(behind, infront)
			_hurt("lunge", float(_health_cfg.suit.max), hunter.label, false)
			await _sim(0.1)
		"flicker":
			var d := _door("medbay", 0.7)
			_open_medbay_door()
			ambush.fired = true
			await _stand_at(_door_side(d, -1.0, 0.9), _door_side(d, -1.0, 6.0))
			flashlight._beam.visible = bool(shot.beam)
			await _sim(0.3)
		"ring":
			ambush.fired = true
			await _stand_at(layout.point_in("junction", [0.5, 0.2]), layout.point_in("junction", [0.5, 0.9]))
			operator.scripted = {"keys": shot.keys, "crouch": shot.get("crouch", false), "sprint": shot.get("sprint", false)}
			await _sim(0.9 if shot.get("crouch", false) else 0.7)
		"fire":
			ambush.fired = true
			await _stand_at(layout.point_in("junction", [0.5, 0.5]), layout.point_in("junction", [0.5, 0.1]))
			await _sim(0.5)
			operator.scripted = {"fire": true}
			await operator.rifle.fired
			operator.scripted = {}
			await _sim(float(shot.wait))
		"tense":
			await _tense_shot(hunter, bed)
		"kit_frame":
			await _kit_frame(String(shot.frame), hunter, behind, infront)
			set_kit_view(String(shot.view))
			await _sim(0.25)
		"kit_door":
			await _kit_door(shot)
		"kit_cutaway":
			ambush.fired = true
			rig.set_cutaway_mode(String(shot.mode))
			set_kit_view(String(shot.get("view", "off")))
			var r2: Rect2 = layout.space_rect("cargo")
			await _stand_at(Vector2(r2.get_center().x, r2.end.y - 1.2), r2.get_center())
			rig.snap()
			await _sim(0.3)
		"kit_tell":
			ambush.fired = true
			var c := bulkhead.panel_center()
			var p := c + Vector2(float(deck_data.grid_m) * 5.0, 3.5)
			await _stand_at(p, c)
			await _sim(0.2)
			await _stand_at(p, p + Vector2(4.0, 4.0))
		"kit_room":
			ambush.fired = true
			set_kit_view("off")
			await _stand_at(layout.point_in(String(shot.space), shot.at), layout.point_in(String(shot.space), [0.5, 0.1]))
			await _sim(0.3)
	Engine.time_scale = 0.0


## The same stands the T006 frames A006 painted over were taken from.
func _kit_frame(frame: String, hunter: Node, behind: Vector2, infront: Vector2) -> void:
	match frame:
		"01b":
			await _open_medbay_door()
			await _stand_at(behind, behind + Vector2(-float(pack.cfg.lunge.range_m), 0))
		"02b":
			await _crouch_at(behind, infront)
		"03c":
			await _bash_shot(hunter, 0.6)
		"04b":
			var d := _door("medbay", 0.7)
			await _open_medbay_door()
			var p := _door_side(d, -1.0, 2.0)
			await _stand_at(p, p + Vector2(0, -6.0))


func _kit_door(shot: Dictionary) -> void:
	ambush.fired = true
	var d := _door(String(shot.space), float(shot.at))
	set_kit_view("off")
	var from: Vector2 = _door_side(d, 1.0, 2.2)
	# Light off and aimed at it, so the look-ahead centres the door and only the deck's lights show it.
	flashlight.set_on(false)
	var along := Vector2(1.5, 0.0) if d.along_x else Vector2(0.0, 1.5)
	await _stand_at(_door_side(d, 1.0, 1.6) + along, d.opening.get_center())
	match String(shot.state):
		"open":
			d.door_state.progress = 1.0
			d.door_state.state = d.door_state.State.OPEN
			d.tick(0.0, [])
		"locked":
			d.reset("locked")
		"bashed":
			d.bash(float(d.cfg.bash.break_s) * 0.6, _door_side(d, -1.0, 2.2))
		"broken":
			d.bash(float(d.cfg.bash.break_s) + 1.0, from)
	sight.refresh_occluders()
	await _sim(0.25)


## A005-06b: low suit, standing in acid, low on rounds, tucked in behind the overturned bed with a
## stalker across the room.
func _tense_shot(hunter: Node, bed: TipBed) -> void:
	ambush.fired = true
	await _open_medbay_door()
	var r: Rect2 = bed.footprint()
	var me := Vector2(r.position.x - 0.6, r.get_center().y)
	var far := Vector2(r.end.x + float(pack.cfg.spit.short_range_m) * 1.5, r.get_center().y)
	await _crouch_at(me, far)
	pack.spits.add_puddle(me, hunter.label)
	_hunt_from(hunter, far, me)
	hunter.brain._lunge_cd = INF
	hunter.brain._spit_cd = INF
	operator.rifle.state.mag = maxi(int(hud.cfg.ammo.low_rounds) / 2, 1)
	suit.integrity = float(_health_cfg.suit.max) * float(hud.cfg.suit.low_fraction) * 0.5 + float(_health_cfg.acid.puddle_dps)
	await _sim(0.5)


## Mid-dash, a stride after it set off.
func _until_dash(s: Node) -> void:
	var left := float(pack.cfg.dash.pause_max_s) + float(pack.cfg.stalk.replan_s) * 2.0
	while left > 0.0 and s.brain.velocity.length() < float(pack.cfg.dash.speed_m_s) * 0.5:
		await get_tree().process_frame
		left -= get_process_delta_time()
	await _sim(float(pack.cfg.dash.min_s) * 0.25)


## From inside the medbay, the shut door with a stalker on the far side. It walks up and bangs for
## real; `done` then jumps its progress, since nobody needs eight seconds in a capture.
func _bash_shot(s: Node, done: float) -> void:
	var d := _door("medbay", 0.7)
	var inside := _door_side(d, -1.0, 3.0)
	await _stand_at(inside, d.opening.get_center())
	s.place_hunting(_door_side(d, 1.0, 2.2), inside)
	var left := float(d.cfg.bash.break_s)
	while left > 0.0 and not s.brain.bashing:
		await get_tree().process_frame
		left -= get_process_delta_time()
	d.door_state.bash_progress = done - float(pack.cfg.nav.cell_m) * 0.01 if done < 1.0 else 1.0 - float(pack.cfg.nav.cell_m) * 0.001
	if done < 1.0:
		await _sim(float(d.cfg.bash.bang_interval_s))
		d.bang()
		await _sim(float(d.cfg.bash.shake_s) * 0.2)
	else:
		await _sim(0.1)


func _crouch_at(p: Vector2, look: Vector2) -> void:
	await _stand_at(p, look)
	operator.scripted = {"crouch": true}
	await _sim(float(operator.model.cfg.crouch.down_s) + 0.1)


func _stand_at(p: Vector2, look: Vector2) -> void:
	await _stand(p, look)
	rig.aim_dir = operator.aim_dir()


func _open_medbay_door() -> void:
	var d := _door("medbay", 0.7)
	if d.door_state.blocks():
		d.door_state.progress = 1.0
		d.door_state.state = d.door_state.State.OPEN
		d.tick(0.0, [])


## Puts a stalker somewhere facing `at`, already knowing about it.
func _hunt_from(s: Node, from: Vector2, at: Vector2) -> void:
	s.place_hunting(from, at)


## The same moment each time: past the panel, facing away, it bursts; the player turns at once.
## The turn takes what the turn takes, so the frames show how late they are.
func _ambush_shot(wait: float) -> void:
	var c := bulkhead.panel_center()
	var past := float(_ambush_cfg.past_m)
	var p := c + Vector2(float(deck_data.grid_m) * 2.0, -past)
	await _stand_at(p, p + Vector2(0, -past))
	await _sim(0.05)
	check_ambush_fired()
	operator.aim_point = Vector3(c.x, _aim_height, c.y)
	await _sim(wait)


## The trigger's own rule fires it; if not, the shot would be a lie, so say so.
func check_ambush_fired() -> void:
	if not ambush.fired:
		push_error("stalker_deck: the ambush capture didn't trigger")


## Measuring window: both stalkers awake and hunting the player in the medbay doorway. The suit
## refills, so the window measures two active stalkers the whole way.
func _demo_step(delta: float) -> void:
	var d := _door("medbay", 0.7)
	if _demo_t == 0.0:
		_open_medbay_door()
		var p := _door_side(d, -1.0, 2.0)
		operator.global_position = Vector3(p.x, 0, p.y)
		rig.snap()
		fire_ambush()
		ambush.fired = true
		var cargo: Node = pack.stalkers[0]
		_hunt_from(cargo, p + Vector2(-float(pack.cfg.spit.max_range_m) * 0.8, 0), p)
	_demo_t += delta
	suit.reset()
	var phase := fmod(_demo_t, 4.0)
	operator.scripted = {"keys": Vector2(-1, 0) if phase < 1.0 else (Vector2(1, 0) if phase < 2.0 else Vector2.ZERO)}
	operator.aim_point = _ahead(-90.0 + sin(_demo_t * 1.5) * 90.0)
