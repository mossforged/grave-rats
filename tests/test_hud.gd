extends "res://tests/test_case.gd"
## T008 suit OS: the noise ring against the real ears, the readouts, every number from data.

const NoiseState := preload("res://src/hud/noise_state.gd")
const SuitOs := preload("res://src/hud/suit_os.gd")
const SuitOsHud := preload("res://src/hud/suit_os_hud.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _hud_cfg() -> Dictionary:
	return (Data.load_data("hud") as Dictionary).duplicate(true)


func _deck(path: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load(path) as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	if "run_log" in scene:
		scene.set_physics_process(false)
		scene.operator.set_physics_process(false)
		scene.run_log.dir = TEST_DIR
	await tree.process_frame
	return scene


func _settle(state: NoiseState, kind: String) -> void:
	for i in 600:
		state.step(DT, kind)


## Stands the scene's stalker `d` metres from the operator in open floor, and returns its brain.
func _prowler_at(scene: Node, d: float) -> StalkerBrain:
	var s: Node = scene.pack.stalkers[0]
	var at: Vector2 = scene.layout.point_in("cargo", [0.5, 0.5])
	s.global_position = Vector3(at.x + d, 0, at.y)
	s.brain = StalkerBrain.new(s.cfg, s.patrol)
	scene.operator.global_position = Vector3(at.x, 0, at.y)
	return s.brain


func test_the_ring_is_exactly_what_the_stalkers_hear() -> void:
	var scene: Node = await _deck("res://scenes/enemies/stalker_deck.tscn")
	var state: NoiseState = scene.noise_ring.state
	var senses: Dictionary = scene.pack.cfg.senses
	for kind: String in ["walk", "crouch", "sprint"]:
		_settle(state, kind)
		check_eq(state.radius, float(senses[kind + "_m"]), "%s: ring at the data's radius" % kind)
		check_eq(state.radius, StalkerBrain.hearing_radius(scene.pack.cfg, kind), "%s: the ring is the brain's radius" % kind)
		var at := Vector2(100, 100)
		var near := _prowler_at(scene, 0.0)
		check(near.hear(kind, at, at - Vector2(state.radius - 0.05, 0)), "%s: heard just inside the ring" % kind)
		var far := _prowler_at(scene, 0.0)
		check(not far.hear(kind, at, at - Vector2(state.radius + 0.05, 0)), "%s: not heard just outside" % kind)
	_settle(state, "")
	check_eq(state.radius, 0.0, "standing still: no ring")
	state.fire()
	for i in roundi(float(state.cfg.bloom_s) / DT) + 1:
		state.step(DT, "")
	check_eq(state.radius, float(senses.gunfire_m), "a shot blooms to the gunfire radius")
	var heard_near := _prowler_at(scene, 0.0)
	check(heard_near.hear("gunfire", Vector2.ZERO, Vector2(state.radius - 0.05, 0)), "gunfire: heard just inside")
	var heard_far := _prowler_at(scene, 0.0)
	check(not heard_far.hear("gunfire", Vector2.ZERO, Vector2(state.radius + 0.05, 0)), "gunfire: not heard just outside")


func test_the_ring_shares_the_numbers_it_never_copies_them() -> void:
	var scene: Node = await _deck("res://scenes/enemies/stalker_deck.tscn")
	var senses: Dictionary = scene.pack.cfg.senses
	var was := float(senses.sprint_m)
	senses.sprint_m = was + 2.0
	var state: NoiseState = scene.noise_ring.state
	_settle(state, "sprint")
	var got := state.radius
	senses.sprint_m = was
	check_eq(got, was + 2.0, "editing the AI's number moves the ring")


func test_the_pirate_deck_ring_shows_the_pirates_ears() -> void:
	var scene: Node = await _deck("res://scenes/pirates/pirate_deck.tscn")
	var senses: Dictionary = Data.value("pirates", "senses")
	var state: NoiseState = scene.noise_ring.state
	for kind: String in ["walk", "crouch", "sprint"]:
		_settle(state, kind)
		check_eq(state.radius, float(senses[kind + "_m"]), "pirates, %s" % kind)
	state.fire()
	for i in roundi(float(state.cfg.bloom_s) / DT) + 1:
		state.step(DT, "")
	check_eq(state.radius, float(senses.gunfire_m), "pirates, gunfire")


func test_it_swells_blooms_and_shrinks_back_on_data_times() -> void:
	var cfg := _hud_cfg()
	var senses := {"walk_m": 3.0, "crouch_m": 1.5, "sprint_m": 9.0, "gunfire_m": 20.0}
	var s := NoiseState.new(cfg.ring, senses)
	s.fire()
	s.step(float(cfg.ring.bloom_s) * 0.5, "")
	check(absf(s.radius - 10.0) < 0.01, "halfway through the bloom, halfway out (%.2f)" % s.radius)
	check(s.ripple > 0.0, "and a pulse is running out")
	for i in roundi((float(cfg.ring.bloom_s) * 0.5 + float(cfg.ring.hold_s)) / DT) - 1:
		s.step(DT, "")
	check_eq(s.radius, 20.0, "holds at the full radius")
	s.step(DT * 2.0, "")
	s.step(float(cfg.ring.shrink_s) * 0.5, "")
	check(absf(s.radius - 10.0) < 0.5, "shrinks back at the data's rate (%.2f)" % s.radius)
	for i in roundi(float(cfg.ring.shrink_s) / DT):
		s.step(DT, "")
	check_eq(s.radius, 0.0, "all the way")
	check_eq(s.ripple, -1.0, "and the pulse is done")
	check(s.alpha_at(3.0) < s.alpha_at(9.0) and s.alpha_at(9.0) < s.alpha_at(20.0), "faint when quiet, stronger when loud")
	cfg.ring.bloom_s = float(cfg.ring.bloom_s) * 2.0
	var slow := NoiseState.new(cfg.ring, senses)
	slow.fire()
	slow.step(float(cfg.ring.bloom_s) * 0.25, "")
	check(absf(slow.radius - 5.0) < 0.01, "an edited bloom time is used")


func test_your_feet_make_the_noise_the_ring_shows_and_the_ai_hears() -> void:
	var scene: Node = await _deck("res://scenes/enemies/stalker_deck.tscn")
	var op: Node = scene.operator
	scene.ambush.fired = true
	check_eq(op.model.noise_kind(), "", "standing still you make none")
	op.scripted = {"keys": Vector2(0, 1)}
	for i in 30:
		op.simulate(DT)
	check_eq(op.model.noise_kind(), "walk", "walking")
	op.scripted = {"keys": Vector2(0, 1), "sprint": true}
	for i in 30:
		op.simulate(DT)
	check_eq(op.model.noise_kind(), "sprint", "sprinting")
	op.scripted = {"keys": Vector2(0, 1), "crouch": true}
	for i in 60:
		op.simulate(DT)
	check_eq(op.model.noise_kind(), "crouch", "crouch-walking")
	var heard := _prowler_at(scene, float(scene.pack.cfg.senses.crouch_m) - 0.2)
	scene._sprint_noise_left = 0.0
	scene.pack.noise("crouch", scene._eye())
	check_eq(heard.state, StalkerBrain.State.INVESTIGATE, "a stalker inside the crouch radius hears it")
	var missed := _prowler_at(scene, float(scene.pack.cfg.senses.crouch_m) + 0.3)
	scene.pack.noise("crouch", scene._eye())
	check_eq(missed.state, StalkerBrain.State.PROWL, "one just outside doesn't")


func test_a_real_shot_blooms_the_ring() -> void:
	var scene: Node = await _deck("res://scenes/enemies/stalker_deck.tscn")
	var state: NoiseState = scene.noise_ring.state
	check_eq(state.radius, 0.0, "fixture: quiet")
	scene.operator.rifle.fired.emit(Vector3.ZERO, Vector3(0, 0, 1), Vector3(0, 0, 1), null)
	scene.noise_ring.tick(DT, scene.operator.global_position, "")
	check(state.radius > 0.0, "the rifle's own signal starts it")
	check(scene.noise_ring.visible, "and it shows")
	scene.respawn()
	check_eq(state.radius, 0.0, "a respawn clears it")
	scene.noise_ring.tick(DT, scene.operator.global_position, "")
	check(not scene.noise_ring.visible, "quiet: nothing drawn at all")


func test_every_deck_has_the_suit_os_and_h_toggles_the_help() -> void:
	for path: String in ["res://scenes/player/weight_deck.tscn", "res://scenes/sight/sight_deck.tscn",
			"res://scenes/enemies/stalker_deck.tscn", "res://scenes/pirates/pirate_deck.tscn"]:
		var scene: Node = await _deck(path)
		check(scene.hud is SuitOsHud, "%s runs the suit OS" % path)
		check(scene.noise_ring != null, "%s has the ring" % path)
		var was: bool = scene.hud.help_on
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = KEY_H
		scene._unhandled_input(key)
		check(scene.hud.help_on != was, "%s: H toggles the help" % path)
	check(not FileAccess.file_exists("res://src/player/player_hud.gd"), "the grey-box HUD is gone")


func _facts(over := {}) -> Dictionary:
	var f := {"in_cover": false, "lock": "", "crouched": false, "sprinting": false, "reloading": false, "empty": false, "light_off": false}
	f.merge(over, true)
	return f


func _words(list: Array) -> Array:
	return list.map(func(i: Dictionary) -> String: return i.word)


func test_the_states_read_as_the_packet_says() -> void:
	var os := SuitOs.new(_hud_cfg())
	check(os.status(_facts()).is_empty(), "nothing to say: says nothing")
	check_eq(_words(os.status(_facts({"crouched": true, "in_cover": true}))), ["IN COVER", "CROUCHED"], "crouched in cover")
	check_eq(_words(os.status(_facts({"crouched": true, "in_cover": true, "lock": "locked"}))), ["IN COVER", "LOCKED"], "locked replaces crouched")
	check_eq(_words(os.status(_facts({"lock": "exposed"}))), ["LOCKED: EXPOSED"], "exposed says so")
	check_eq(_words(os.status(_facts({"light_off": true}))), ["LIGHT OFF"], "light off")
	check_eq(_words(os.status(_facts({"reloading": true, "empty": true}))), ["RELOADING"], "a reload outranks empty")


func test_the_alarms_and_the_placeholders() -> void:
	var cfg := _hud_cfg()
	var os := SuitOs.new(cfg)
	var low := int(cfg.ammo.low_rounds)
	check(os.alerts(false, low + 1).is_empty(), "no alarm with rounds left")
	check_eq(_words(os.alerts(false, low)), ["LOW AMMO"], "low ammo at the data's number")
	check_eq(_words(os.alerts(true, low + 1)), ["ACID ALARM"], "acid")
	check_eq(_words(os.alerts(true, low)), ["ACID ALARM", "LOW AMMO"], "both, as in A005-06b")
	check(os.suit_low(float(cfg.suit.low_fraction)), "suit low at the data's share")
	check(not os.suit_low(float(cfg.suit.low_fraction) + 0.01), "and not above it")
	check_eq(os.oxygen_text(), "06:40", "the oxygen ticker starts where the data says")
	os.step(10.0)
	check_eq(os.oxygen_text(), "06:30", "and counts down")
	os.step(100000.0)
	check_eq(os.oxygen_text(), "00:00", "and stops at nothing")
	os.reset()
	check_eq(os.oxygen_text(), "06:40", "a new life is a new tank")
	check_eq(os.credits_text(1240), "1,240", "credits, grouped")
	check_eq(os.credits_text(999), "999", "small ones aren't")
	check_eq(os.credits_text(1000000), "1,000,000", "nor do big ones break")


func test_hud_numbers_and_words_come_from_data() -> void:
	var cfg := _hud_cfg()
	cfg.ammo.low_rounds = 20
	cfg.words.low_ammo = "NEARLY OUT"
	cfg.oxygen.start_s = 90.0
	cfg.suit.low_fraction = 0.9
	var os := SuitOs.new(cfg)
	check_eq(_words(os.alerts(false, 20)), ["NEARLY OUT"], "edited threshold and word")
	check_eq(os.oxygen_text(), "01:30", "edited tank")
	check(os.suit_low(0.85), "edited suit share")


func test_the_hud_reads_the_scene_it_is_in() -> void:
	var scene: Node = await _deck("res://scenes/pirates/pirate_deck.tscn")
	var hud: SuitOsHud = scene.hud
	check_eq(hud.suit, scene.suit, "the suit dock is the real suit")
	check_eq(hud.suit_fraction(), 1.0, "full")
	scene.suit.integrity = float(scene.suit.cfg.suit.max) * 0.5
	check_eq(hud.suit_fraction(), 0.5, "and follows it")
	check_eq(hud.mark, scene.mark, "the shields are the cover module's")
	var low: Rect2 = scene._piece_rect(5)
	var me := Vector2(low.position.x - 0.8, low.get_center().y)
	scene.operator.global_position = Vector3(me.x, 0, me.y)
	check(scene.driver.press(), "fixture: locks to cover")
	check_eq(scene.driver.state_word(), "locked", "the driver reports it")
	hud.lock_state = scene.driver.state_word()
	check(_words(hud.status_now()).has(String(hud.cfg.words.locked)), "and the HUD says it")
	scene.driver.release()


func test_the_font_is_there_and_its_licence_with_it() -> void:
	var cfg := _hud_cfg()
	for key: String in ["regular", "bold"]:
		check(ResourceLoader.exists(String(cfg.font[key])), "%s font imported" % key)
	check(FileAccess.file_exists("res://assets/game/fonts/OFL.txt"), "the licence travels with it")
	for c: String in cfg.colors:
		check(Color.html_is_valid(String(cfg.colors[c])), "colour %s parses" % c)
