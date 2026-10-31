extends "res://tests/test_case.gd"
## T017: the bank and its files, cooldowns, the buses and the limiter, the cue rules, and on the real deck:
## every gameplay event plays its cue, the drone, the cutter and the spit never sound without their
## visual twins, and the noise ring doesn't care what you can hear.

const AudioBank := preload("res://src/audio/audio_bank.gd")
const SoundRules := preload("res://src/audio/sound_rules.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const CutterBrain := preload("res://src/custodian/cutter_brain.gd")
const Door := preload("res://src/doors/door.gd")
const DT := 1.0 / 60.0
const COOLDOWN_CLEAR := 5.0

var _nodes: Array[Node] = []
var _heard: Array[String] = []
var _at := {}
var _pitch := {}


func before_each() -> void:
	# The tests step the clock themselves, so a cooldown lasts what it says whatever the frame rate.
	Audio.set_process(false)
	Audio.reset()
	_heard.clear()
	_at.clear()
	_pitch.clear()
	Audio.played.connect(_on_played)


func after_each() -> void:
	Audio.played.disconnect(_on_played)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Audio.reset()
	Audio.set_process(true)


func _on_played(cue: String, at: Vector3, pitch: float) -> void:
	_heard.append(cue)
	_at[cue] = at
	_pitch[cue] = pitch


## Forgets what was heard and lets every cooldown run out.
func _clear() -> void:
	Audio.advance(COOLDOWN_CLEAR)
	_heard.clear()


func _scene(path := "res://scenes/shift/shift_deck.tscn") -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load(path) as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.enabled = false
	await tree.physics_frame
	await tree.physics_frame
	return scene


func _sim(scene: Node, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < seconds:
		await tree.physics_frame
		scene.simulate_world(DT)
		scene.operator.simulate(DT)
		Audio.advance(DT)
		t += DT


func _quiet(scene: Node) -> void:
	for s: Node in scene.pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(scene.layout.bounds.end.x + 50.0, 0.0, scene.layout.bounds.end.y + 50.0)


## A spot `reach` away from `p` with nothing tall between them.
func _open_spot(scene: Node, p: Vector2, reach: float) -> Vector2:
	for i in 16:
		var q := p + Vector2.from_angle(TAU * float(i) / 16.0) * reach
		if scene.layout.space_at(q) != "" and not scene.pack.plan_blocked.call(q, p):
			return q
	check(false, "somewhere open near %s" % p)
	return p


func _stand_in(scene: Node, space: String) -> void:
	var p: Vector2 = scene.layout.point_in(space, [0.5, 0.5])
	scene.operator.global_position = Vector3(p.x, 0.0, p.y)


# --- the bank ---

func test_every_cue_has_its_fields_and_its_file_loads() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	check(cfg.cues.size() > 0, "a bank")
	for cue: String in cfg.cues:
		var c: Dictionary = cfg.cues[cue]
		for key: String in ["file", "volume_db", "pitch_variance", "max_distance_m", "cooldown_s", "bus"]:
			check(c.has(key), "%s has %s" % [cue, key])
		check(ResourceLoader.exists(String(c.file)), "%s: %s" % [cue, c.file])
		check(load(String(c.file)) is AudioStream, "%s loads" % cue)
		check(Audio.streams.has(cue), "%s is ready to play" % cue)
		check(cfg.buses.has(String(c.bus)), "%s goes to a bus that exists" % cue)
		check(bool(c.get("placeholder", false)) and String(c.file).get_file().begins_with("ph_"), "%s says it's a placeholder" % cue)


func test_packet_list_is_all_in_the_bank() -> void:
	for cue: String in ["step_deck", "step_grate", "step_wet", "crouch_rustle", "suit_breath", "pickup_small", "pickup_medium",
			"pickup_heavy", "drop_small", "drop_medium", "drop_heavy", "rifle_body_1", "rifle_dry", "rifle_mag_out", "rifle_mag_in",
			"rifle_charge", "tink_deck_1", "stalker_click", "stalker_chirp", "stalker_spit_windup", "stalker_spit", "stalker_lunge",
			"stalker_hit", "stalker_death", "stalker_scuttle", "stalker_bash", "cutter_warm", "cutter_burn", "drone_chirp",
			"custodian_chime", "amb_medbay", "amb_cargo", "amb_junction", "door_open", "door_close", "door_locked", "door_break",
			"lights_fail", "alarm_siren", "oxygen_warning", "stamp_accept", "stamp_acknowledge", "ledger_tick"]:
		check(Audio.bank.has(cue), "%s is in the bank" % cue)


func test_every_cue_named_elsewhere_in_the_data_is_in_the_bank() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	var named: Array = [cfg.breathing.cue, cfg.ledger.cue]
	named.append_array(cfg.footsteps.cues.values())
	named.append_array(cfg.ambience.rooms.values())
	named.append_array(cfg.carry.pickup.values())
	named.append_array(cfg.carry.drop.values())
	named.append_array(cfg.paper_stamps.values())
	for s: Dictionary in cfg.reload_stages:
		if s.has("cue"):
			named.append(s.cue)
	for cue: Variant in named:
		check(Audio.bank.has(String(cue)), "%s is in the bank" % cue)
	for surface: String in cfg.footsteps.surfaces.values():
		check(cfg.footsteps.cues.has(surface), "%s has a footstep" % surface)
	check(cfg.footsteps.cues.has(String(cfg.footsteps.default_surface)), "and so does the default")


func test_the_rooms_and_salvage_classes_are_all_covered() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	for space: Dictionary in Data.value("deck", "spaces"):
		check(cfg.ambience.rooms.has(String(space.name)), "%s has a room tone" % space.name)
		check(cfg.footsteps.surfaces.has(String(space.name)), "%s has a surface" % space.name)
	for klass: String in Data.value("salvage", "classes"):
		check(cfg.carry.pickup.has(klass) and cfg.carry.drop.has(klass), "%s has a pick-up and a drop" % klass)


func test_cooldowns_hold() -> void:
	var bank := AudioBank.new({"cues": {"a": {"cooldown_s": 0.5, "max_distance_m": 0.0}}})
	check(bank.take("a"), "first")
	check(not bank.take("a"), "still resting")
	bank.advance(0.4)
	check(not bank.take("a"), "still resting at 0.4 s")
	bank.advance(0.11)
	check(bank.take("a"), "ready at 0.51 s")
	check(not bank.take("nothing"), "a cue that isn't there")


func test_every_cooldown_in_the_bank_holds_through_the_player() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	for cue: String in cfg.cues:
		if bool(cfg.cues[cue].get("loop", false)):
			continue
		_clear()
		var rest := float(cfg.cues[cue].cooldown_s)
		check(Audio.play(cue), "%s plays" % cue)
		if rest > 0.0:
			check(not Audio.play(cue), "%s rests" % cue)
			Audio.advance(rest * 0.5)
			check(not Audio.play(cue), "%s rests at half its cooldown" % cue)
			Audio.advance(rest * 0.5 + DT)
			check(Audio.play(cue), "%s is ready after %.2f s" % [cue, rest])


func test_loops_loop_and_one_shots_dont() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	for cue: String in cfg.cues:
		var w := Audio.streams[cue] as AudioStreamWAV
		check(w != null, "%s is a wav for now" % cue)
		if w != null:
			var looped := bool(cfg.cues[cue].get("loop", false))
			check_eq(w.loop_mode != AudioStreamWAV.LOOP_DISABLED, looped, "%s loop mode" % cue)


func test_voices_are_a_fixed_pool_and_a_loop_keeps_its_voice() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	Audio.loop("hold", "cutter_warm", Vector3.ZERO)
	var voice: Node = Audio._loops["hold"].voice
	for i in int(cfg.voices.positional) * 2:
		var other: Node = Audio._voice_for("rifle_body_1", Vector3.ZERO, 1.0, 0.0)
		other.play()
		check(other != voice, "a one-shot doesn't take a loop's voice")
	check_eq(Audio._positional.size(), int(cfg.voices.positional), "the pool stayed its size")
	Audio.stop_loop("hold")


# --- buses, limiter, listener ---

func test_buses_exist_and_the_master_has_a_limiter() -> void:
	var cfg: Dictionary = Data.load_data("audio")
	for bus: String in cfg.buses:
		check(AudioServer.get_bus_index(bus) > 0, "%s exists" % bus)
	var found: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			found = AudioServer.get_bus_effect(0, i)
	check(found != null, "a limiter on the master bus")
	if found != null:
		check_eq(found.ceiling_db, float(cfg.master.limiter.ceiling_db), "its ceiling is the data's")
		check(found.ceiling_db < 0.0, "under full scale")


func test_bus_sliders_in_f1_move_the_bus_live() -> void:
	var entries: Array = Data.value("debug", "tuning").filter(func(e: Dictionary) -> bool: return e.get("file", "") == "audio")
	var top: Array = (Data.value("audio", "buses") as Dictionary).values().filter(func(b: Dictionary) -> bool: return not b.has("send"))
	check_eq(entries.size(), 1 + top.size(), "one slider per bus and the master; the range filters follow SFX")
	var cfg: Dictionary = Audio.cfg
	var was := float(cfg.buses.SFX.volume_db)
	cfg.buses.SFX.volume_db = was - 7.0
	Audio._apply_bus_volumes()
	check_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), was - 7.0, "the bus moved")
	cfg.buses.SFX.volume_db = was
	Audio._apply_bus_volumes()


func test_the_mix_has_the_rifle_and_alarm_on_top_and_ambience_low() -> void:
	var cues: Dictionary = (Data.load_data("audio") as Dictionary).cues
	var ambience: Array = []
	for cue: String in cues:
		if String(cues[cue].bus) == "Ambience":
			ambience.append(cue)
	check(ambience.size() >= 3, "three room tones")
	for cue: String in ambience:
		check(float(cues[cue].volume_db) < float(cues.alarm_siren.volume_db) - 12.0, "%s is well under the alarm" % cue)
		check(float(cues[cue].volume_db) < float(cues.rifle_body_1.volume_db) - 12.0, "%s is well under the rifle" % cue)
	for cue: String in ["step_deck", "crouch_rustle", "stalker_click", "rifle_mag_in", "door_open"]:
		check(float(cues[cue].volume_db) < float(cues.rifle_body_1.volume_db), "%s is under the rifle" % cue)


func test_listener_is_at_the_player_turned_with_the_camera() -> void:
	var scene: Node = await _scene()
	check(Audio.listener.is_current(), "the listener's in charge")
	_stand_in(scene, "cargo")
	Audio._place_listener()
	var p: Vector3 = scene.operator.global_position
	check(Audio.listener.global_position.distance_to(p + Vector3.UP * float(Audio.cfg.listener.height_m)) < 0.01, "at the player")
	var cam: Camera3D = scene.get_viewport().get_camera_3d()
	check(Audio.listener.global_basis.is_equal_approx(cam.global_basis), "turned with the camera")
	scene.free()
	check(not Audio.listener.is_current(), "the deck's gone, so is the listener")
	check(not Audio.looping("breath"), "and the loops")


# --- rules ---

func test_footfalls_come_by_distance() -> void:
	var clock := SoundRules.StepClock.new()
	var steps := 0
	for i in 100:
		if clock.advance(0.1, 0.95):
			steps += 1
	check_eq(steps, 10, "10 m at 0.95 m a stride")
	check_eq(SoundRules.gait(false, true), "sprint", "sprint")
	check_eq(SoundRules.gait(true, false), "crouch", "crouch")
	check_eq(SoundRules.gait(false, false), "walk", "walk")


func test_breath_quickens_with_low_suit_and_low_oxygen() -> void:
	var b: Dictionary = Data.value("audio", "breathing")
	check_eq(SoundRules.breath_stress(b, 1.0, 1.0), 0.0, "calm")
	check_eq(SoundRules.breath_stress(b, float(b.low_suit), 1.0), 0.0, "calm at the suit's line")
	check(SoundRules.breath_stress(b, float(b.low_suit) * 0.5, 1.0) > 0.0, "low suit")
	check(SoundRules.breath_stress(b, 1.0, float(b.low_oxygen) * 0.5) > 0.0, "low oxygen")
	check_eq(SoundRules.breath_stress(b, 0.0, 1.0), 1.0, "suit gone")
	check_eq(SoundRules.breath_stress(b, 1.0, 0.0), 1.0, "air gone")
	Audio.breathe(1.0, 1.0)
	var calm := Audio.loop_pitch("breath")
	Audio.breathe(float(b.low_suit) * 0.25, 1.0)
	check(Audio.loop_pitch("breath") > calm, "faster on low suit")
	Audio.breathe(1.0, float(b.low_oxygen) * 0.25)
	check(Audio.loop_pitch("breath") > calm, "faster on low oxygen")
	Audio.breathe(0.0, 0.0)
	check(absf(Audio.loop_pitch("breath") - float(b.max_rate)) < 0.001, "the data's top rate")


func test_reload_stages_cross_once() -> void:
	var stages: Array = [{"at": 0.4, "cue": "a"}, {"at": 0.8, "cue": "b"}]
	check_eq(SoundRules.stages_crossed(stages, 0.0, 0.3).size(), 0, "nothing yet")
	check_eq(SoundRules.stages_crossed(stages, 0.3, 0.5)[0].cue, "a", "the first")
	check_eq(SoundRules.stages_crossed(stages, 0.5, 0.6).size(), 0, "not again")
	check_eq(SoundRules.stages_crossed(stages, 0.3, 1.0).size(), 2, "both in one step")


func test_room_tones_crossfade() -> void:
	var shares := {"a": 1.0, "b": 0.0}
	SoundRules.fade_rooms(shares, "b", 0.5, 1.0)
	check_eq(shares.a, 0.5, "falling")
	check_eq(shares.b, 0.5, "rising")
	SoundRules.fade_rooms(shares, "b", 5.0, 1.0)
	check_eq(shares.a, 0.0, "gone")
	check_eq(shares.b, 1.0, "there")


# --- player, on the deck ---

func test_footsteps_by_surface_and_gait() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var cues: Dictionary = Audio.cfg.footsteps.cues
	var surfaces: Dictionary = Audio.cfg.footsteps.surfaces
	for space: String in ["medbay", "junction", "side_corridor"]:
		_stand_in(scene, space)
		scene.operator.scripted = {"keys": Vector2(1.0, 0.0)}
		_clear()
		# Just the feet: the walls don't matter to this and neither does where they end up.
		for i in 45:
			scene.operator.model.step(DT, Vector2.ZERO, 0.0, false, false)
			scene.operator.model.speed = float(scene.operator._cfg.move.walk_speed_m_s)
			scene.operator._foot_sounds(DT, false)
			Audio.advance(DT)
		var want := String(cues[surfaces[space]])
		check(_heard.has(want), "%s walks on %s" % [space, want])
		for other: String in cues.values():
			check(other == want or not _heard.has(other), "%s has no %s" % [space, other])
	var walked := _heard.count(String(cues[surfaces["side_corridor"]]))
	check(walked >= 2, "a footfall every stride (%d in 0.75 s)" % walked)
	_clear()
	scene.operator.model.speed = 0.0
	scene.operator._foot_sounds(1.0, false)
	check(_heard.is_empty(), "standing still is silent")


func test_crouch_rustles_going_down_and_coming_up() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	_clear()
	scene.operator.scripted = {"crouch": true}
	await _sim(scene, 0.1)
	check_eq(_heard.count("crouch_rustle"), 1, "going down")
	_clear()
	await _sim(scene, 0.3)
	check_eq(_heard.count("crouch_rustle"), 0, "not while staying down")
	scene.operator.scripted = {"crouch": false}
	await _sim(scene, 0.1)
	check_eq(_heard.count("crouch_rustle"), 1, "coming up")


func test_pick_up_and_drop_by_class_heavy_is_the_loud_one() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var cues: Dictionary = Audio.cfg.cues
	check(float(cues.drop_heavy.volume_db) > float(cues.drop_medium.volume_db) + 3.0, "the heavy thud is well over a medium drop")
	check(float(cues.drop_heavy.volume_db) > float(cues.drop_small.volume_db) + 3.0, "and a small one")
	for klass: String in ["small", "medium", "heavy"]:
		var item: RefCounted = scene._first_of(klass)
		_clear()
		scene._on_carry_event({"type": "taken", "item": item, "noise": ""})
		check(_heard.has("pickup_%s" % klass), "picking up %s" % klass)
		_clear()
		scene._on_carry_event({"type": "dropped", "item": item, "noise": ""})
		check(_heard.has("drop_%s" % klass), "dropping %s" % klass)


func test_a_heavy_drop_still_makes_the_noise_ring_fire_and_the_sound_is_separate() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var item: RefCounted = scene._first_of("heavy")
	_clear()
	var ring_state: RefCounted = scene.noise_ring.state
	ring_state.reset()
	scene._on_carry_event({"type": "dropped", "item": item, "noise": "thud"})
	check(_heard.has("drop_heavy"), "you hear it")
	check(ring_state._blooming, "and the ring fires, as it did")
	# And the other way: a cue played on its own is nothing to the AI or the ring.
	var s: Node = scene.pack.stalkers[0]
	s.brain.state = StalkerBrain.State.PROWL
	s.global_position = scene.operator.global_position + Vector3(2.0, 0.0, 0.0)
	var noise_left: float = s.brain._noise_left
	ring_state.reset()
	_clear()
	Audio.play("drop_heavy", s.global_position)
	Audio.play("rifle_body", s.global_position)
	check_eq(s.brain._noise_left, noise_left, "a stalker doesn't hear the audio module")
	check_eq(s.brain.state, StalkerBrain.State.PROWL, "and goes on prowling")
	check(not ring_state._blooming, "the ring doesn't either")


func test_breathing_runs_on_a_shift_and_stops_with_a_form_or_a_death() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	await _sim(scene, 0.05)
	check(Audio.looping("breath"), "breathing on shift")
	var calm := Audio.loop_pitch("breath")
	scene.suit.integrity = float(scene.suit.cfg.suit.max) * 0.1
	await _sim(scene, 0.05)
	check(Audio.loop_pitch("breath") > calm, "faster with the suit nearly gone")
	scene._open_form("briefing", {})
	check(not Audio.looping("breath"), "not behind a form")
	scene._close_form()
	await _sim(scene, 0.05)
	check(Audio.looping("breath"), "back on after it")
	scene._hurt("lunge", 10000.0, "test", false)
	await _sim(scene, 0.05)
	check(not Audio.looping("breath"), "not after dying")


# --- weapons ---

func _body_heard() -> bool:
	return _heard.any(func(c: String) -> bool: return c.begins_with("rifle_body_"))


func _tink_heard() -> bool:
	return _heard.any(func(c: String) -> bool: return c.begins_with("tink_"))


func test_shot_casing_dry_fire_and_reload_stages() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var op: Node = scene.operator
	_clear()
	op.scripted = {"fire": true}
	await _sim(scene, 0.05)
	check(_body_heard(), "the shot")
	check(not _tink_heard(), "the casing lands later")
	op.scripted = {}
	await _sim(scene, 1.2)
	check(_tink_heard(), "and there it is")
	op.scripted = {}
	op.rifle.state.mag = 0
	await _sim(scene, 0.2)
	_clear()
	op.scripted = {"fire": true}
	await _sim(scene, 0.05)
	check(_heard.has("rifle_dry"), "dry fire on an empty magazine")
	check(not _body_heard(), "and no shot")
	var dry := _heard.count("rifle_dry")
	await _sim(scene, 0.1)
	check_eq(_heard.count("rifle_dry"), dry, "the trigger held doesn't machine-gun it")
	op.scripted = {}
	await _sim(scene, 0.05)
	_clear()
	check(op.request_reload(), "reload")
	check(not _heard.has("rifle_mag_out"), "the mag comes out when the hand gets there")
	await _sim(scene, float(op.rifle.state.reload_total) * 0.3)
	check(_heard.has("rifle_mag_out"), "and there it is")
	check(not _heard.has("rifle_mag_in"), "mag in not yet")
	await _sim(scene, float(op.rifle.state.reload_total) * 0.3)
	check(_heard.has("rifle_mag_in"), "mag in in the middle")
	check(not _heard.has("rifle_charge"), "no charge yet")
	await _sim(scene, float(op.rifle.state.reload_total) * 0.45)
	check(_heard.has("rifle_charge"), "the charge at the end")
	check_eq(_heard.count("rifle_mag_in"), 1, "each once")
	check_eq(_heard.count("rifle_charge"), 1, "each once")


func test_a_cancelled_reload_goes_quiet() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var op: Node = scene.operator
	op.rifle.state.mag = 1
	op.request_reload()
	_clear()
	op.rifle.tick(DT, true, Vector3.ZERO, 0.0, Vector3.ZERO)
	await _sim(scene, float(op.rifle.state.cfg.reload_s))
	check(not _heard.has("rifle_mag_in"), "no mag in")
	check(not _heard.has("rifle_charge"), "no charge")


# --- stalker ---

func test_stalker_cues_and_the_spit_has_its_twin() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var s: Node = scene.pack.stalkers[0]
	_stand_in(scene, "cargo")
	scene._sync_target()
	var eye: Vector2 = scene._eye()
	s.place_hunting(_open_spot(scene, eye, 4.0), eye)
	s.brain.force_spit()
	_clear()
	await _sim(scene, DT)
	check(_heard.has("stalker_spit_windup"), "the wind-up hisses")
	check(s.brain.state != StalkerBrain.State.SPIT or s.body._glow.visible, "and glows: its twin")
	check(_at["stalker_spit_windup"].distance_to(s.mouth()) < 0.5, "from its mouth")
	check_eq(_heard.count("stalker_spit"), 0, "no spit yet")
	var hisses := _heard.count("stalker_spit_windup")
	var tree := Engine.get_main_loop() as SceneTree
	for i in 60:
		await tree.physics_frame
		scene.simulate_world(DT)
		if _heard.has("stalker_spit"):
			break
	check_eq(_heard.count("stalker_spit_windup"), hisses, "one hiss to a wind-up")
	check(_heard.has("stalker_spit"), "the spit")
	check(scene.pack.spits.glob_count() > 0, "and a glob the same step: its twin")
	_clear()
	s.brain.force_lunge()
	scene.pack._handle(StalkerBrain.EV_LUNGE_START, s, scene.pack.target_body())
	check(_heard.has("stalker_lunge"), "the lunge screech")
	_clear()
	s.brain.state = StalkerBrain.State.STALK
	s.brain.health = 10000.0
	s.take_hit({"damage": 1.0, "point": Vector3.ZERO, "direction": Vector3.FORWARD})
	check(_heard.has("stalker_hit"), "hit")
	check(not _heard.has("stalker_death"), "not dead")
	_clear()
	s.brain.health = 1.0
	s.take_hit({"damage": 10.0, "point": Vector3.ZERO, "direction": Vector3.FORWARD})
	check(_heard.has("stalker_death"), "dead")
	check(not _heard.has("stalker_hit"), "and only that")


func test_real_brain_spit_also_hisses_with_its_glow() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var s: Node = scene.pack.stalkers[0]
	_stand_in(scene, "cargo")
	scene._sync_target()
	var eye: Vector2 = scene._eye()
	s.place_hunting(_open_spot(scene, eye, 4.0), eye)
	s.brain.yaw = s.brain.yaw_to(s.floor_position(), eye)
	s.brain._spit_cd = 0.0
	s.brain._lunge_cd = 100.0
	_clear()
	var tree := Engine.get_main_loop() as SceneTree
	var saw_glow_with_hiss := false
	var hissed := false
	for i in 300:
		await tree.physics_frame
		scene.simulate_world(DT)
		if hissed and s.brain.state == StalkerBrain.State.SPIT and s.body._glow.visible:
			saw_glow_with_hiss = true
		if not hissed and _heard.has("stalker_spit_windup"):
			hissed = true
			check_eq(s.brain.state, StalkerBrain.State.SPIT, "the hiss only comes in the wind-up")
		if _heard.has("stalker_spit"):
			break
	check(hissed, "it hissed on its own")
	check(_heard.has("stalker_spit"), "and spat")
	check(saw_glow_with_hiss, "and the glow showed in between")


func test_idle_clicks_and_chirps_only_from_an_awake_living_stalker() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var s: Node = scene.pack.stalkers[0]
	_clear()
	for i in 60:
		Audio.advance(1.0)
		s._voice(0.0)
		s.brain.state = StalkerBrain.State.DORMANT
		s.simulate(1.0, scene.pack)
	check(not _heard.has("stalker_click") and not _heard.has("stalker_chirp"), "a dormant stalker is silent")
	s.brain.state = StalkerBrain.State.DEAD
	_clear()
	for i in 60:
		Audio.advance(1.0)
		s.simulate(1.0, scene.pack)
	check(not _heard.has("stalker_click") and not _heard.has("stalker_chirp"), "so's a dead one")
	s.brain.state = StalkerBrain.State.PROWL
	_clear()
	for i in 60:
		Audio.advance(1.0)
		s._voice(1.0)
	check(_heard.has("stalker_click"), "a prowler clicks")
	check(_heard.has("stalker_chirp"), "and chirps")
	check(_heard.size() < 60, "now and then, not all the time")


func test_vents_scuttle_when_a_stalker_comes_in() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	_clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s: Node = scene.pack.spawn_out_of_view([], [scene._eye()], rng)
	check(s != null, "one came")
	check(_heard.has("stalker_scuttle"), "scuttling")
	check(_at["stalker_scuttle"].distance_to(s.global_position) < 0.1, "from where it came")


func test_door_banging_and_breaking() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var s: Node = scene.pack.stalkers[0]
	var d: Node = scene.doors.doors[0]
	s.door = d
	_clear()
	scene.pack._handle(StalkerBrain.EV_BANG, s, scene.pack.target_body())
	check(_heard.has("stalker_bash"), "the banging")
	check(_at["stalker_bash"].distance_to(d.door_point()) < 0.01, "at the door")
	_clear()
	d.reset("closed")
	d.bash(float(d.cfg.bash.break_s) + 1.0, d.opening.get_center())
	check(_heard.has("door_break"), "and it breaks")


func test_the_ambush_bang() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	_clear()
	scene.fire_ambush()
	check(_heard.has("bulkhead_burst"), "the panel")


# --- CUSTODIAN ---

func _wake_cutter(scene: Node) -> Node:
	_quiet(scene)
	var c: Node = scene.custodian.cutters[0]
	for other: Node in scene.custodian.drones:
		other.global_position = Vector3(scene.layout.bounds.end.x + 50.0, 0.0, scene.layout.bounds.end.y + 50.0)
	return c


## Puts the player in the cutter's sight, its first aim about to start.
func _aim(scene: Node, c: Node) -> void:
	c.wake()
	var home := Vector2(-sin(c.brain.yaw), -cos(c.brain.yaw))
	var p: Vector2 = c.floor_position() + home * 3.0
	scene.operator.global_position = Vector3(p.x, 0.0, p.y)


func _cutter_players(p: Vector2) -> Array:
	return [{"id": 1, "pos": p, "body": Vector3(p.x, 1.2, p.y), "alive": true}]


func _clear_trace(from: Vector3, to: Vector3) -> Dictionary:
	return {"clear": true, "point": to}


func _blocked_trace(from: Vector3, _to: Vector3) -> Dictionary:
	return {"clear": false, "point": from}


func test_cutter_hum_rises_with_the_ring_and_only_shows_with_it() -> void:
	var scene: Node = await _scene()
	var c: Node = await _wake_cutter(scene)
	c.wake()
	var p: Vector2 = c.floor_position() + Vector2(-sin(c.brain.yaw), -cos(c.brain.yaw)) * 3.0
	_clear()
	var last_pitch := 0.0
	var rises := 0
	var steps := 0
	var hummed := false
	for i in 400:
		c.tick(DT, _cutter_players(p), _clear_trace)
		Audio.advance(DT)
		steps += 1
		var on := Audio.looping(c.warm_key())
		check_eq(on, c.brain.aiming(), "the hum is on exactly while it aims (step %d)" % i)
		if on:
			hummed = true
			check(c.mount_ring.visible and c.target_ring.visible, "and the rings show: its twin")
			check(c.line_mesh.visible, "and the line")
			var pitch := Audio.loop_pitch(c.warm_key())
			if pitch > last_pitch:
				rises += 1
			last_pitch = pitch
		if _heard.has("cutter_burn"):
			break
	check(hummed, "it hummed")
	check(rises > 10, "the pitch climbed with the ring (%d rises)" % rises)
	check(_heard.has("cutter_burn"), "then the burn")
	check(c.beam_mesh.visible, "with the beam: its twin")
	check(not Audio.looping(c.warm_key()), "and the hum's off")
	var want := SoundRules.warm_pitch(Audio.cfg.cutter_warm, 1.0)
	check(absf(last_pitch - want) < 0.1, "it ended near the top (%.2f, want %.2f)" % [last_pitch, want])


func test_breaking_the_line_stops_the_hum() -> void:
	var scene: Node = await _scene()
	var c: Node = await _wake_cutter(scene)
	c.wake()
	var p: Vector2 = c.floor_position() + Vector2(-sin(c.brain.yaw), -cos(c.brain.yaw)) * 3.0
	for i in 400:
		c.tick(DT, _cutter_players(p), _clear_trace)
		if c.brain.aiming():
			break
	check(Audio.looping(c.warm_key()), "humming")
	c.tick(DT, _cutter_players(p), _blocked_trace)
	check(not c.brain.aiming(), "line broken")
	check(not Audio.looping(c.warm_key()), "the hum stops with the ring")
	check(not c.mount_ring.visible, "the ring's gone too")
	_clear()
	check(not _heard.has("cutter_burn"), "no burn")


func test_drone_chirps_rise_per_bar_with_the_bars_lit() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var d: Node = scene.custodian.drones[0]
	d.wake()
	var p: Vector2 = d.floor_position() + Vector2(-sin(d.brain.yaw), -cos(d.brain.yaw)) * 3.0
	var pitches: Array = []
	var v: RefCounted = scene.sight.visibility
	_clear()
	for i in 1200:
		d.tick(DT, _cutter_players(p), _clear_trace, v)
		Audio.advance(DT)
		if _heard.has("drone_chirp"):
			pitches.append(_pitch["drone_chirp"])
			_heard.clear()
			check(d.brain.calling(), "a chirp means it's calling")
			var lit := 0
			for b: MeshInstance3D in d.bars:
				if b.material_override != d._bar_dim:
					lit += 1
			check_eq(lit, pitches.size(), "and that many bars lit: its twin")
		if pitches.size() >= int(d.cfg.bars):
			break
	check_eq(pitches.size(), int(d.cfg.bars), "one chirp a bar")
	for i in range(1, pitches.size()):
		check(pitches[i] > pitches[i - 1], "each higher than the last")


func test_a_chime_comes_with_each_voice_line_and_not_otherwise() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var lines: Array[String] = []
	scene.custodian.spoke.connect(func(l: String) -> void: lines.append("%s" % l))
	_clear()
	scene.custodian.voice.reset()
	scene.custodian._say("detect")
	check_eq(lines.size(), 1, "it spoke")
	check_eq(_heard.count("custodian_chime"), 1, "with the chime")
	scene.custodian._say("detect")
	check_eq(lines.size(), 1, "resting")
	check_eq(_heard.count("custodian_chime"), 1, "no line, no chime")
	check_eq(String(Audio.cfg.cues.custodian_chime.bus), "VoicePlaceholder", "on the voice bus")


# --- ship ---

func test_ambience_follows_the_room() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var rooms: Dictionary = Audio.cfg.ambience.rooms
	for space: String in rooms:
		var cue := String(rooms[space])
		check(Audio.looping("room:%s" % cue), "%s is going" % cue)
	for space: String in ["medbay", "cargo", "junction"]:
		_stand_in(scene, space)
		await _sim(scene, DT)
		Audio.advance(float(Audio.cfg.ambience.fade_s) + 0.1)
		var cue := String(rooms[space])
		check_eq(Audio.current_room_tone(), cue, "in the %s" % space)
		check_eq(Audio.room_share(cue), 1.0, "%s is all the way up" % cue)
		for other: String in rooms.values():
			if other != cue:
				check_eq(Audio.room_share(other), 0.0, "%s is out in the %s" % [other, space])


func test_doors_open_close_and_buzz() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var d: Node = scene.doors.doors[0]
	d.reset("closed")
	_clear()
	check_eq(d.interact([]), "opening", "open")
	check(_heard.has("door_open"), "the open sound")
	d.tick(float(d.cfg.open_s) + 0.1, [])
	_clear()
	check_eq(d.interact([]), "closing", "close")
	check(_heard.has("door_close"), "the close sound")
	_clear()
	d.reset("locked")
	check(_heard.is_empty(), "a reset is silent")
	check_eq(d.interact([]), "locked", "locked")
	check(_heard.has("door_locked"), "the buzz")
	check(not _heard.has("door_open"), "and nothing else")


func test_the_tier_warns_and_lights_failing_clunk() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	var tiers: Array = scene._cfg.tiers
	var lights_tier := -1
	for i in tiers.size():
		if tiers[i].has("lights"):
			lights_tier = i
	check(lights_tier >= 0, "a tier with lights")
	_clear()
	scene._on_tier(lights_tier + 1, tiers[lights_tier])
	check(_heard.has("oxygen_warning"), "the oxygen tone")
	check(_heard.has("lights_fail"), "the clunk")
	check(scene.hud.os_state.announcement() != "", "and the suit says so: its twin")


func test_oxygen_out_repeats_the_warning_at_its_cooldown() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	scene.shift.oxygen_left = 0.0
	_clear()
	await _sim(scene, 0.05)
	check(scene.shift.oxygen_out(), "out of air")
	check_eq(_heard.count("oxygen_warning"), 1, "the warning")
	check(scene.hud.urgent_alerts.has("o2_out"), "with its strip")
	await _sim(scene, 0.2)
	check_eq(_heard.count("oxygen_warning"), 1, "resting")
	Audio.advance(float(Audio.cfg.cues.oxygen_warning.cooldown_s))
	await _sim(scene, 0.05)
	check_eq(_heard.count("oxygen_warning"), 2, "again after its cooldown")


func test_the_alarm_runs_with_the_alarm_and_stops_with_it() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	check(not Audio.looping("alarm"), "quiet")
	scene._trip_alarm()
	check(Audio.looping("alarm"), "the siren")
	check(scene.marker.on, "and the marker: its twin")
	scene.shift.alarm_left = 0.001
	await _sim(scene, 0.1)
	check(not Audio.looping("alarm"), "stops when the alarm's over")
	scene.respawn()
	scene._trip_alarm()
	check(Audio.looping("alarm"), "the next shift's prize trips it again")
	scene.respawn()
	check(not Audio.looping("alarm"), "a new shift starts quiet")


func test_ui_stamps_and_the_ledger_tick() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	_clear()
	scene.paper.open("briefing", {})
	scene._on_paper_pressed("accept")
	check(_heard.has("stamp_accept"), "accept stamps")
	_clear()
	scene.quota.begin()
	scene._on_paper_pressed("confirm_decline")
	check(_heard.has("stamp_acknowledge"), "declining stamps")
	scene._close_form()
	_clear()
	scene.quota.begin()
	scene.paper.open("payslip", {})
	scene.paper.screen_name = "payslip"
	scene._on_paper_pressed("acknowledge")
	check(_heard.has("stamp_acknowledge"), "acknowledge stamps")
	scene._close_form()
	_clear()
	var l: Dictionary = Audio.cfg.ledger
	scene._tick_ledger(5)
	check(_heard.is_empty(), "ticks come in a run, not at once")
	for i in 5:
		Audio.advance(float(l.gap_s) + 0.001)
	check_eq(_heard.count(String(l.cue)), 5, "one a line")
	_clear()
	scene._tick_ledger(int(l.max_ticks) + 40)
	Audio.advance(float(l.gap_s) * (float(l.max_ticks) + 41.0))
	check_eq(_heard.count(String(l.cue)), int(l.max_ticks), "a long ledger stops at the data's most")


func test_a_real_payslip_ticks_its_ledger() -> void:
	var scene: Node = await _scene()
	_quiet(scene)
	scene.start_session()
	scene._on_paper_pressed("accept")
	_clear()
	scene.abandon_shift()
	check(scene.paper.is_open(), "the payslip's up")
	var rows: int = scene.paper.doc.ledger.size()
	check(rows > 0, "with rows")
	for i in rows + 2:
		Audio.advance(float(Audio.cfg.ledger.gap_s))
	check_eq(_heard.count(String(Audio.cfg.ledger.cue)), mini(rows, int(Audio.cfg.ledger.max_ticks)), "ticking through them")
	scene._close_form()
