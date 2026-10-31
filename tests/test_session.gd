extends "res://tests/test_case.gd"
## T018: the co-op groundwork. Players, commands, authority and the seed, solo and with two players on
## the real deck. No network. See src/session/CONTRACT.md.

const Session := preload("res://src/session/session.gd")
const Commands := preload("res://src/session/commands.gd")
const ShiftState := preload("res://src/shift/shift_state.gd")
const QuotaState := preload("res://src/shift/quota_state.gd")
const SalvageRules := preload("res://src/salvage/salvage_rules.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const MateBot := preload("res://src/session/mate_bot.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs_session"
const A := 1
const B := 2

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _deck(players := 2) -> Node:
	var scene: Node = (load("res://src/shift/shift_deck.gd") as GDScript).new()
	_nodes.append(scene)
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.run_log.dir = TEST_DIR
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	if players > 1:
		scene.join_player(B, "grave_rats", Session.SOURCE_REMOTE)
	await (Engine.get_main_loop() as SceneTree).process_frame
	return scene


func _op(scene: Node, id: int) -> Node3D:
	return scene.session.player(id).operator


func _put(scene: Node, id: int, at: Vector2) -> void:
	_op(scene, id).global_position = Vector3(at.x, 0.0, at.y)


func _quiet(scene: Node) -> void:
	scene.ambush.fired = true
	for s: Node in scene.pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(scene.layout.bounds.end.x + 50.0, 0.0, scene.layout.bounds.end.y + 50.0)


func _item_of(scene: Node, klass: String) -> RefCounted:
	for item: RefCounted in scene.field.items:
		if String(item.klass) == klass and not item.prize and item.taken_by == 0:
			return item
	return null


func _lift(scene: Node, id: int, item: RefCounted) -> void:
	_put(scene, id, item.at)
	scene.session.send(Commands.take(id))
	for i in int(ceilf(float(scene.field.rules.class_of(item).pickup_s) / DT)) + 2:
		_op(scene, id).simulate(DT)
		scene.simulate_world(DT)


func _kill(scene: Node, id: int) -> void:
	scene.hurt_player(id, "lunge", float(scene._health_cfg.suit.max), "test", false)


func _leave(scene: Node, id: int) -> void:
	_put(scene, id, scene.airlock.rect.get_center())
	if id == scene.player_id:
		_op(scene, id).scripted = {"leave": true}
	else:
		scene.session.send(Commands.leave(id, true))
	for i in int(float(scene._cfg.leave.hold_s) / DT) + 3:
		scene.simulate_world(DT)


# --- the session, on its own ---

func test_a_session_is_a_list_of_players_with_id_crew_and_source() -> void:
	var s := Session.new(Data.load_data("session"))
	s.add_player(A, "grave_rats", Session.SOURCE_LOCAL)
	s.add_player(B, "prior_claim", Session.SOURCE_SCRIPTED)
	check_eq(s.ids(), [A, B], "both on the list")
	check_eq(s.player(B).crew, "prior_claim", "crew")
	check_eq(s.player(B).source, Session.SOURCE_SCRIPTED, "source")
	check_eq(s.local().id, A, "the local player")
	check(s.add_player(A, "x", "y") == null, "an ID can't be taken twice")


func test_the_crew_size_comes_from_data() -> void:
	var cfg: Dictionary = (Data.load_data("session") as Dictionary).duplicate(true)
	cfg.max_players = 3
	var s := Session.new(cfg)
	for id in 3:
		check(s.add_player(id + 1, "c", "local") != null, "room for %d" % (id + 1))
	check(s.add_player(9, "c", "local") == null, "a full crew")


func test_one_session_seed_gives_the_same_rolls() -> void:
	var a := Session.new(Data.load_data("session"))
	var b := Session.new(Data.load_data("session"))
	a.reseed(4242)
	b.reseed(4242)
	check_eq(a.rng.randi(), b.rng.randi(), "the main RNG")
	check_eq(a.seed_for("rifle:2"), b.seed_for("rifle:2"), "a named stream")
	check(a.seed_for("rifle:1") != a.seed_for("rifle:2"), "streams differ")
	var before := a.rng.state
	a.seed_for("anything")
	check_eq(a.rng.state, before, "a stream doesn't draw on the main RNG")
	check(a.reseed() != 0, "0 rolls a seed")


func test_every_command_carries_a_player_id_and_all_the_packets_actions_exist() -> void:
	var made: Array = [Commands.move(B, Vector2.ZERO, false, 0.0), Commands.aim(B, Vector3.ZERO), Commands.fire(B, true),
			Commands.reload_gun(B), Commands.crouch(B, true), Commands.interact(B), Commands.take(B), Commands.drop(B),
			Commands.door(B), Commands.tip(B), Commands.leave(B, true), Commands.lock(B)]
	for cmd: Dictionary in made:
		check_eq(int(cmd.player_id), B, "%s has the ID" % cmd.type)
	check_eq(made.map(func(c: Dictionary) -> String: return c.type), Commands.ALL, "one of each")


func test_a_command_from_nobody_goes_nowhere() -> void:
	var s := Session.new(Data.load_data("session"))
	check(not s.send(Commands.take(9)), "no such player")


func test_shift_state_takes_everyone_in_the_airlock_and_leaves_the_rest() -> void:
	var cfg: Dictionary = Data.load_data("shift")
	var s := ShiftState.new(cfg, SalvageRules.new(Data.load_data("salvage")))
	s.add_player(A)
	s.add_player(B)
	s.add_player(3)
	s.set_aboard(B, true)
	s.set_aboard(3, false)
	check(s.step_leave(A, float(cfg.leave.hold_s) + DT, true, true), "LEAVE completes")
	check_eq(s.survivors, [A, B], "whoever's in the airlock")
	check_eq(s.left_behind, [3], "anyone not aboard is left behind")
	check_eq(s.report().left_behind, [3], "and it's on file")


func test_oxygen_is_read_per_player_while_the_tiers_run_on_the_clock() -> void:
	var s := ShiftState.new(Data.load_data("shift"), SalvageRules.new(Data.load_data("salvage")))
	s.add_player(A)
	s.add_player(B)
	s.set_tank_extra(B, 60.0)
	s.oxygen_left = 0.0
	check_eq(s.oxygen_of(A), 0.0, "A is out")
	check_eq(s.oxygen_of(B), 60.0, "B's own air")
	check(s.suit_loss(DT, A) > 0.0, "A's suit drains")
	check_eq(s.suit_loss(DT, B), 0.0, "B's doesn't")


func test_a_held_log_waits_for_the_shift_then_writes_once() -> void:
	var log := RunLog.new(TEST_DIR)
	log.player_id = B
	log.crew = "grave_rats"
	log.hold_back = true
	check_eq(log.write("death"), "", "held")
	var path := log.flush_held()
	check(path != "", "written once it's known")
	check_eq(log.flush_held(), "", "and not twice")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(data.ended, "death", "as what it was")
	check_eq(int(data.player_id), B, "whose")
	check_eq(data.crew, "grave_rats", "which crew")


# --- solo ---

func test_solo_is_a_session_of_one_and_the_operator_is_its_local_player() -> void:
	var scene: Node = await _deck(1)
	check_eq(scene.session.ids(), [A], "one player")
	check(scene.session.local().operator == scene.operator, "the operator")
	check(scene.session.local().suit == scene.suit, "the suit")
	check(scene.session.local().sight == scene.sight, "the sight")
	check(scene.session.local().run_log == scene.run_log, "the log")
	check(scene.rng == scene.session.rng, "the deck's RNG is the session's")


func test_local_input_goes_through_the_command_layer() -> void:
	var scene: Node = await _deck(1)
	var seen: Array = []
	var real: Callable = scene.operator.send_command
	scene.operator.send_command = func(cmd: Dictionary) -> void:
		seen.append(String(cmd.type))
		real.call(cmd)
	scene.operator.scripted = {"keys": Vector2(0, -1), "crouch": true, "fire": true}
	scene.operator.simulate(DT)
	for type: String in [Commands.MOVE, Commands.CROUCH, Commands.FIRE]:
		check(seen.has(type), "%s went as a command" % type)
	check(scene.operator.model.velocity.length() > 0.0, "and it moved")


func test_e_and_g_go_through_the_command_layer() -> void:
	var scene: Node = await _deck(1)
	_quiet(scene)
	var before: int = scene.session.commands_sent
	scene.interact()
	scene.drop_item()
	check_eq(scene.session.commands_sent, before + 2, "both sent")


# --- two players ---

func test_both_spawn_apart_with_their_own_operator() -> void:
	var scene: Node = await _deck()
	check_eq(scene.session.ids(), [A, B], "both on the list")
	check(_op(scene, A) != _op(scene, B), "two operators")
	var gap: float = _op(scene, A).global_position.distance_to(_op(scene, B).global_position)
	check(is_equal_approx(gap, float(scene.session.cfg.spawn_spacing_m)), "a step apart, from data (got %f)" % gap)
	check(scene.layout.is_free(scene.player_pos(scene.session.player(B)), _op(scene, B).body_radius()), "on open floor")
	check(scene.join_player(B, "c", "x") == null, "the one spawn path won't take an ID twice")


func test_a_new_shift_puts_both_back_at_the_spawn() -> void:
	var scene: Node = await _deck()
	var home: Vector3 = _op(scene, B).global_position
	_put(scene, B, Vector2(home.x + 3.0, home.z - 3.0))
	_kill(scene, B)
	scene.respawn()
	check_eq(_op(scene, B).global_position, home, "back where it spawned")
	check(not scene.session.player(B).suit.dead, "alive again")
	check(not _op(scene, B).control_held(), "on its feet")
	check(scene.shift.alive(B), "and on the roster")


func test_a_command_moves_only_the_player_it_names() -> void:
	var scene: Node = await _deck()
	var a0: Vector3 = _op(scene, A).global_position
	var b0: Vector3 = _op(scene, B).global_position
	scene.session.send(Commands.move(B, Vector2(0, -1), false, 0.0))
	for i in 20:
		_op(scene, A).simulate(DT)
		_op(scene, B).simulate(DT)
	check(_op(scene, B).global_position.distance_to(b0) > 0.0, "B walked")
	check_eq(_op(scene, A).global_position, a0, "A didn't")


func test_a_remote_player_ignores_scripted_input_and_obeys_commands() -> void:
	var scene: Node = await _deck()
	var b: Node3D = _op(scene, B)
	var b0: Vector3 = b.global_position
	b.scripted = {"keys": Vector2(1, 0)}
	for i in 10:
		b.simulate(DT)
	check_eq(b.global_position, b0, "nothing moves it but a command")
	scene.session.send(Commands.crouch(B, true))
	scene.session.send(Commands.aim(B, Vector3(40.0, 1.0, 0.0)))
	for i in 30:
		b.simulate(DT)
	check(b.model.crouch_amount > 0.0, "crouch")
	check(b.aim_point.x == 40.0, "aim")
	var mag: int = b.rifle.state.mag
	scene.session.send(Commands.fire(B, true))
	for i in 30:
		b.simulate(DT)
	check(b.rifle.state.mag < mag, "fire")
	scene.session.send(Commands.fire(B, false))
	scene.session.send(Commands.reload_gun(B))
	check(b.rifle.state.reloading(), "reload")


func test_each_has_their_own_sight() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var a: RefCounted = scene.session.player(A)
	var b: RefCounted = scene.session.player(B)
	check(a.sight != b.sight, "two sight systems")
	check(a.sight.grid != b.sight.grid, "two memories")
	var medbay: Vector2 = scene.layout.point_in("medbay", [0.5, 0.45])
	var cargo: Vector2 = scene.layout.point_in("cargo", [0.55, 0.55])
	_put(scene, A, cargo + Vector2(0.0, 2.0))
	_op(scene, A).face_now(Vector3(cargo.x, 1.0, cargo.y))
	_put(scene, B, medbay + Vector2(0.0, 2.0))
	_op(scene, B).face_now(Vector3(medbay.x, 1.0, medbay.y))
	a.sight.forget()
	b.sight.forget()
	scene._update_sight(0.0, true)
	scene.update_player_sight(b, 0.0, true)
	check(b.sight.grid.state_at(medbay) != b.sight.grid.UNKNOWN, "B knows the medbay")
	check_eq(a.sight.grid.state_at(medbay), a.sight.grid.UNKNOWN, "A doesn't")
	check(a.sight.grid.state_at(cargo) != a.sight.grid.UNKNOWN, "A knows cargo")
	check_eq(b.sight.grid.state_at(cargo), b.sight.grid.UNKNOWN, "B doesn't")
	check(scene._sees_from(medbay, b), "B sees it")
	check(not scene._sees_from(medbay, a), "A doesn't")
	check(not scene._player_knows(medbay), "and this screen's fog is A's")


func test_only_the_local_sight_decides_what_shows_on_this_screen() -> void:
	var scene: Node = await _deck()
	var a: RefCounted = scene.session.player(A)
	var b: RefCounted = scene.session.player(B)
	var cargo: Vector2 = scene.layout.space_rect("cargo").get_center()
	var seen: Node = _op(scene, B).get_node("SightTarget")
	_put(scene, B, cargo)
	scene._update_sight(0.0, true)
	scene.update_player_sight(b, 0.0, true)
	check(not seen.seen, "A can't see B in cargo, whatever B's own sight says")
	_put(scene, B, scene.player_pos(a) + Vector2(0.0, -2.0))
	_op(scene, A).face_now(_op(scene, B).global_position)
	scene._update_sight(0.0, true)
	check(seen.seen, "and can when in the beam")


func test_each_has_their_own_carry_and_the_weight_lands_on_the_right_one() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "heavy")
	await _lift(scene, B, item)
	check(scene.shift.carry(B).in_hand == item, "in B's hands")
	check(scene.shift.carry(A).in_hand == null, "not in A's")
	check(not _op(scene, B).can_fire(), "B can't fire under a heavy")
	check(_op(scene, A).can_fire(), "A still can")
	check(_op(scene, B).model.speed_mult < 1.0, "B is slow")
	check_eq(_op(scene, A).model.speed_mult, 1.0, "A isn't")


func test_two_players_cant_lift_one_item() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "medium")
	_put(scene, A, item.at)
	_put(scene, B, item.at + Vector2(0.1, 0.0))
	scene.session.send(Commands.take(A))
	scene.session.send(Commands.take(B))
	check(scene.shift.carry(A).busy(), "A got there first")
	check(not scene.shift.carry(B).busy(), "B gets nothing")
	check(not _op(scene, B).control_held(), "and isn't held")


func test_a_dropped_item_can_be_carried_on_by_a_crewmate() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "heavy")
	await _lift(scene, A, item)
	scene.session.send(Commands.drop(A))
	check(scene.shift.carry(A).in_hand == null, "A let go")
	_op(scene, A).release_control()
	await _lift(scene, B, item)
	check(scene.shift.carry(B).in_hand == item, "B has it now")


func test_the_hold_is_shared_and_either_can_fill_it() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var one := _item_of(scene, "medium")
	await _lift(scene, A, one)
	_put(scene, A, scene.airlock.rect.get_center())
	scene.simulate_world(DT)
	var two := _item_of(scene, "heavy")
	await _lift(scene, B, two)
	_put(scene, B, scene.airlock.rect.get_center() + Vector2(1.0, 0.0))
	scene.simulate_world(DT)
	check(scene.session.hold() == scene.shift.hold, "one hold")
	check_eq(scene.session.hold().items.size(), 2, "both went in")
	check_eq(scene.hud.hold_estimate, int(one.base) + int(two.base), "the HUD reads the crew's")


func test_the_hud_reads_the_local_players_carry_and_suit() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	await _lift(scene, B, _item_of(scene, "heavy"))
	scene.simulate_world(DT)
	check_eq(String(scene.hud.carry.in_hand), "", "B's heavy isn't in A's readout")
	check(not scene.hud.hands_full, "or A's hands")
	scene.hurt_player(B, "lunge", 1.0, "test", false)
	check_eq(scene.suit.integrity, float(scene._health_cfg.suit.max), "B's hurt isn't A's suit")
	check(scene.session.player(B).suit.integrity < float(scene._health_cfg.suit.max), "it's B's")


func test_one_going_down_doesnt_end_the_shift_and_drops_only_their_haul() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "medium")
	await _lift(scene, B, item)
	_kill(scene, B)
	check(not scene.shift.alive(B), "B's down")
	check(not scene.shift.ended(), "the shift goes on")
	check(not scene.suit.dead, "A's fine")
	check(_op(scene, B).control_held(), "B's body stays down")
	check(scene.field.on_floor().has(item), "what B carried is on the deck")
	check_eq(scene.suit_hud.visible and scene.killed_by_text != "", false, "A sees no death screen")


func test_if_anyone_extracts_the_haul_counts() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "medium")
	await _lift(scene, A, item)
	_put(scene, A, scene.airlock.rect.get_center())
	scene.simulate_world(DT)
	_kill(scene, A)
	check(not scene.shift.ended(), "the crew's still going")
	_leave(scene, B)
	check_eq(scene.shift.outcome, ShiftState.EXTRACTED, "B got out")
	check_eq(scene.shift.survivors, [B], "B alone")
	check(scene.session.haul_counts(), "so it counts")
	check_eq(scene.session.banked(), int(item.value), "everything A put in the hold")


func test_the_same_with_the_other_player_down() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "medium")
	await _lift(scene, B, item)
	_put(scene, B, scene.airlock.rect.get_center())
	scene.simulate_world(DT)
	_kill(scene, B)
	_leave(scene, A)
	check_eq(scene.session.banked(), int(item.value), "B's deposit counts when A gets out")


func test_both_dying_loses_the_haul() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var item := _item_of(scene, "medium")
	await _lift(scene, A, item)
	_put(scene, A, scene.airlock.rect.get_center())
	scene.simulate_world(DT)
	check_eq(scene.session.hold().items.size(), 1, "it's in the hold")
	_kill(scene, A)
	check(not scene.shift.ended(), "one down")
	_kill(scene, B)
	check_eq(scene.shift.outcome, ShiftState.WIPED, "both down")
	check(not scene.session.haul_counts(), "it doesn't count")
	check_eq(scene.session.banked(), 0, "the haul's gone")
	check_eq(scene.shift.report().banked_value, 0, "on file too")


func test_leaving_takes_everyone_in_the_airlock_and_leaves_the_rest_behind() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	_put(scene, B, scene.airlock.rect.get_center() + Vector2(1.0, 0.0))
	_leave(scene, A)
	check_eq(scene.shift.survivors, [A, B], "both aboard")
	scene.respawn()
	_quiet(scene)
	var far: Vector2 = scene.layout.point_in("junction", [0.5, 0.2])
	_put(scene, B, far)
	_leave(scene, A)
	check_eq(scene.shift.survivors, [A], "only A")
	check_eq(scene.shift.left_behind, [B], "B's left behind")
	check(scene.session.haul_counts(), "and the haul still counts")


func test_a_death_log_waits_until_the_shift_ends_and_says_how() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	scene.run_log.enabled = true
	var b: RefCounted = scene.session.player(B)
	b.run_log.enabled = true
	_kill(scene, B)
	check_eq(b.run_log.last_path, "", "B's log is waiting")
	_leave(scene, A)
	check(b.run_log.last_path != "", "written when the shift ended")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(b.run_log.last_path))
	check_eq(data.ended, "death", "B died")
	check_eq(int(data.player_id), B, "B's")
	check_eq(data.shift_outcome, ShiftState.EXTRACTED, "and knows the crew got out")


func test_the_ship_and_the_pack_can_hurt_either_player() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var full := float(scene._health_cfg.suit.max)
	scene._on_custodian_hit(B, "cutter", 1.0, Vector2.ZERO, "cutter")
	check_eq(scene.session.player(B).suit.integrity, full - 1.0, "the ship's burn lands on who it names")
	check_eq(scene.suit.integrity, full, "not on A")
	check_eq(scene._custodian_players().map(func(p: Dictionary) -> int: return p.id), [A, B], "it's told about both")
	var s: Node = scene.pack.stalkers[0]
	var at_b: Vector2 = scene.player_pos(scene.session.player(B))
	s.place_hunting(at_b + Vector2(1.0, 0.0), at_b)
	_put(scene, A, at_b + Vector2(-12.0, 0.0))
	scene._sync_target()
	check_eq(scene._hunted_id, B, "the pack hunts the nearest")
	scene._on_player_hit("lunge", 1.0, s, false)
	check_eq(scene.session.player(B).suit.integrity, full - 2.0, "and its hit lands on them")
	_kill(scene, B)
	scene._sync_target()
	check_eq(scene._hunted_id, A, "a dead player isn't hunted")


func test_spawns_stay_out_of_every_players_sight() -> void:
	var scene: Node = await _deck()
	check_eq(scene._viewers().size(), 2, "two pairs of eyes")
	check_eq(scene._player_points().size(), 2, "two places to keep clear")
	_kill(scene, B)
	check_eq(scene._viewers().size(), 1, "the dead don't count")


func test_rounds_pass_through_the_crew() -> void:
	var scene: Node = await _deck()
	check(_op(scene, A).rifle.exclude.has(_op(scene, B).get_rid()), "A's rounds skip B")
	check(_op(scene, B).rifle.exclude.has(_op(scene, A).get_rid()), "B's skip A")
	check(_op(scene, B).rifle.exclude.has(_op(scene, B).get_rid()), "B's skip B")
	check(scene._custodian_trace.exclude.has(_op(scene, B).get_rid()), "the cutter's line ignores the capsule the same way")


func test_doors_hold_for_any_player_in_the_doorway() -> void:
	var scene: Node = await _deck()
	var d: Node3D = scene.doors.doors[0]
	_put(scene, B, d.opening.get_center())
	scene._process(DT)
	var there := false
	for a: Dictionary in scene.doors.actors:
		there = there or (a.position as Vector2).is_equal_approx(d.opening.get_center())
	check(there, "B counts as in the doorway")


# --- authority ---

func test_without_authority_nothing_shared_changes() -> void:
	var scene: Node = await _deck()
	_quiet(scene)
	var s: RefCounted = scene.session
	var item := _item_of(scene, "medium")
	_put(scene, B, item.at)
	var door: Node3D = scene.doors.doors[0]
	var door_state: int = door.door_state.state
	_put(scene, A, door.opening.get_center())
	var o2: float = scene.shift.oxygen_left
	var full: float = float(scene._health_cfg.suit.max)
	var net: int = scene.quota.banked
	var stalkers: int = scene.pack.stalkers.size()
	scene._spawns_owed = 1
	s.authority = false
	# Damage
	scene._hurt("lunge", 1.0, "test", false)
	scene.hurt_player(B, "lunge", 1.0, "test", false)
	check_eq(scene.suit.integrity, full, "no damage to A")
	check_eq(s.player(B).suit.integrity, full, "or to B")
	# Loot
	s.send(Commands.take(B))
	check(not scene.shift.carry(B).busy() and item.taken_by == 0, "no loot")
	# Doors
	s.send(Commands.door(A))
	door.bash(1.0, Vector2.ZERO)
	check_eq(door.door_state.state, door_state, "no door")
	check_eq(door.door_state.bash_progress, 0.0, "no bashing")
	check_eq(scene.doors.interact(door.opening.get_center()), "", "the door system answers nothing")
	# The clock and spawns
	for i in 10:
		scene.simulate_world(DT)
	check_eq(scene.shift.oxygen_left, o2, "no clock")
	scene._step_spawns(1.0)
	check_eq(scene.pack.stalkers.size(), stalkers, "no spawns")
	# The alarm and the shift
	scene._trip_alarm(B)
	check(not scene.shift.prize_taken, "no alarm")
	var the_shift: RefCounted = scene.shift
	var first_item: RefCounted = scene.field.items[0]
	scene.respawn()
	check(scene.field.items[0] == first_item and the_shift.outcome == ShiftState.RUNNING, "no new ship")
	# The quota
	check_eq(s.close_quota(500, QuotaState.LEFT), scene.quota.verdict, "the quota answers")
	check_eq(scene.quota.banked, net, "and doesn't move")
	s.authority = true
	scene.hurt_player(B, "lunge", 1.0, "test", false)
	check_eq(s.player(B).suit.integrity, full - 1.0, "with authority it works")


func test_is_authority_is_true_for_now() -> void:
	var scene: Node = await _deck(1)
	check(scene.session.is_authority(), "always, until there's a network")


# --- no code path assumes one player: a grep, kept honest ---

func _sources(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_sources(dir.path_join(sub)))
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func _hits(path: String, rx: RegEx) -> PackedStringArray:
	var out := PackedStringArray()
	var n := 0
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		n += 1
		var code := raw.get_slice("#", 0)
		if rx.search(code) != null:
			out.append("%s:%d %s" % [path, n, code.strip_edges()])
	return out


func test_no_code_finds_the_player_by_a_global_shortcut() -> void:
	var rx := RegEx.create_from_string("get_first_node_in_group|group\\(\\s*&?\"player|is_in_group\\(\\s*&?\"player|get_node\\(\"/root/(Player|Operator)|%Player|\\$Operator\\b")
	for path: String in _sources("res://src"):
		for hit: String in _hits(path, rx):
			check(false, "a shortcut to 'the' player: %s" % hit)
	var autoloads := FileAccess.get_file_as_string("res://project.godot").get_slice("[autoload]", 1).get_slice("\n[", 0)
	for word: String in ["Player", "Operator", "Session"]:
		check(not autoloads.contains(word + "="), "no singleton holds %s" % word)


## Inside the shift's rules, a player is always named: `player_id` (the local player) may only appear
## in what this screen shows, and in the three local-only entry points. The capture hooks stage scenes.
func test_the_shift_rules_key_on_a_player_not_on_the_local_one() -> void:
	const SCREEN_ONLY := ["_ready", "join_player", "_make_custodian", "_is_local", "interact", "drop_item", "_sync_hud",
			"_action_now", "_update_prompt", "_on_custodian_hit", "_on_player_hit", "hurt_player", "_trip_alarm"]
	var rx := RegEx.create_from_string("(?<![\\w.)])(player_id\\b|operator\\.)")
	var text := FileAccess.get_file_as_string("res://src/shift/shift_deck.gd").get_slice("# --- capture hooks", 0)
	var fn := ""
	var n := 0
	for raw: String in text.split("\n"):
		n += 1
		if raw.begins_with("func "):
			fn = raw.trim_prefix("func ").get_slice("(", 0)
		var code := raw.get_slice("#", 0)
		if rx.search(code) != null and not raw.begins_with("var "):
			check(SCREEN_ONLY.has(fn), "shift_deck.gd:%d in %s assumes the local player: %s" % [n, fn, code.strip_edges()])


func test_the_session_owns_who_changes_the_quota_and_the_clock() -> void:
	var text := FileAccess.get_file_as_string("res://src/shift/shift_deck.gd").get_slice("# --- capture hooks", 0)
	check(not text.contains("quota.close_shift"), "the quota moves through session.close_quota")
	check_eq(text.count("suit.take("), 1, "one place in the deck takes damage")
	var hurt := text.get_slice("func hurt_player", 1)
	check(hurt.find("is_authority") < hurt.find("suit.take("), "behind the guard")
	var session := FileAccess.get_file_as_string("res://src/session/session.gd")
	var close := session.get_slice("func close_quota", 1)
	check(close.find("is_authority") < close.find("close_shift"), "the guard comes first")


# --- all randomness from the session's seed ---

## Global-RNG calls and fresh unseeded RNGs that run the simulation. Each exemption says why: these
## look only on this screen (no rule reads them), or they aren't on the shift deck at all.
const RANDOM_EXEMPT := {
	"res://src/enemies/stalker_deck.gd": "camera shake, this screen only",
	"res://src/pirates/pirate_deck.gd": "camera shake on the pirate deck",
	"res://src/pirates/pirate_brain.gd": "src/pirates isn't on the shift deck; parked",
	"res://src/pirates/pirate_squad.gd": "src/pirates isn't on the shift deck; parked",
	"res://src/enemies/stalker.gd": "randomize() at reset, reseeded from the session as the shift starts",
	"res://src/weapons/rifle_state.gd": "randomize() at _init, reseeded from the session as the shift starts",
}


func test_nothing_in_the_game_rolls_outside_the_sessions_seed() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize|pick_random)\\(|\\.randomize\\(\\)|\\.shuffle\\(\\)|\\.pick_random\\(\\)")
	for path: String in _sources("res://src"):
		if RANDOM_EXEMPT.has(path) or path == "res://src/session/session.gd":
			continue
		for hit: String in _hits(path, rx):
			check(false, "rolls outside the session: %s" % hit)
	check(_hits("res://src/shift/shift_deck.gd", RegEx.create_from_string("get_ticks")).is_empty(), "no clock as a seed")


## What the run left: every roll that matters, and where everything ended up.
func _run_a_shift(seed_value: int) -> Dictionary:
	# No frame goes by: physics frames land by the wall clock, and that's no part of the seed.
	var scene: Node = (load("res://src/shift/shift_deck.gd") as GDScript).new()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.run_log.enabled = false
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.join_player(B, "grave_rats", Session.SOURCE_REMOTE)
	scene.session.player(B).run_log.enabled = false
	var s: RefCounted = scene.session
	scene.next_seed = seed_value
	scene.respawn()
	var a: Node3D = _op(scene, A)
	var b: Node3D = _op(scene, B)
	a.scripted = {"keys": Vector2(0, -1), "fire": true}
	s.send(Commands.move(B, Vector2(1, -1), false, 0.0))
	s.send(Commands.fire(B, true))
	var trail: Array = []
	var yaws: Array = []
	a.rifle.fired.connect(func(_f: Vector3, _t: Vector3, d: Vector3, _h: Object) -> void: yaws.append(d))
	b.rifle.fired.connect(func(_f: Vector3, _t: Vector3, d: Vector3, _h: Object) -> void: yaws.append(d))
	# Past the first two tiers: stalkers spawn, a section fails.
	scene.shift.oxygen_left = float(scene._cfg.oxygen_s) * float(scene._cfg.tiers[0].at_oxygen) + DT * 30.0
	for i in 240:
		a.simulate(DT)
		b.simulate(DT)
		scene.simulate_world(DT)
		if i % 40 == 0:
			for st: Node in scene.pack.stalkers:
				trail.append(st.global_position)
	var out := {
		"items": scene.field.items.map(func(item: RefCounted) -> int: return item.value),
		"sections": scene.section.state_of("cargo"),
		"stalkers": scene.pack.stalkers.size(),
		"trail": trail,
		"shots": yaws,
		"a": a.global_position,
		"b": b.global_position,
		"seed": s.seed_value,
		"next": s.rng.randi(),
	}
	scene.free()
	return out


func test_two_runs_with_one_seed_match() -> void:
	var one: Dictionary = _run_a_shift(90210)
	var two: Dictionary = _run_a_shift(90210)
	for key: String in one:
		check_eq(two[key], one[key], "same seed, same %s" % key)
	check(one.shots.size() > 0, "shots were fired")
	check(one.stalkers > 2, "the tier brought one in (%d)" % one.stalkers)
	var other: Dictionary = _run_a_shift(90211)
	check(other.items != one.items or other.shots != one.shots, "another seed, another run")


func test_the_session_seed_reaches_the_rifles_and_stalkers() -> void:
	var scene: Node = await _deck()
	scene.next_seed = 5150
	scene.respawn()
	var s: RefCounted = scene.session
	check_eq(s.seed_value, 5150, "the deck's seed is the session's")
	check_eq(_op(scene, B).rifle.state.rng.seed, s.seed_for("rifle:%d" % B), "B's rifle")
	check(_op(scene, A).rifle.state.rng.seed != _op(scene, B).rifle.state.rng.seed, "A's rifle has its own")
	check_eq(scene.pack.stalkers[0].brain.rng.seed, s.seed_for("stalker:0"), "the stalkers")


func test_the_session_scripts_keep_their_numbers_in_data() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	var allowed := ["0", "1", "2", "0.0", "1.0", "2.0", "0.5"]
	var strip := RegEx.create_from_string("\"[^\"]*\"")
	for f: String in ["commands", "session", "session_player", "player_sight", "mate_bot"]:
		var n := 0
		for raw: String in FileAccess.get_file_as_string("res://src/session/%s.gd" % f).split("\n"):
			n += 1
			for m in rx.search_all(strip.sub(raw.get_slice("#", 0), "\"\"", true)):
				if not allowed.has(m.get_string(1)):
					check(false, "%s.gd:%d has the literal %s" % [f, n, m.get_string(1)])


# --- the debug launch ---

func test_the_two_player_scene_has_two_and_the_bot_fills_the_hold_through_commands() -> void:
	var scene: Node = (load("res://scenes/session/two_player_deck.tscn") as PackedScene).instantiate()
	_nodes.append(scene)
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.run_log.enabled = false
	scene.session.player(B).run_log.enabled = false
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.next_seed = 77
	scene.respawn()
	_quiet(scene)
	check_eq(scene.session.ids(), [A, B], "two players")
	check(not scene.session_live, "plain shifts: no forms")
	var seen_taken := 0
	var sent_before: int = scene.session.commands_sent
	var bot: MateBot = scene.bot
	bot.leave_when_done = true
	var b: Node3D = _op(scene, B)
	var steps := 0
	while not scene.shift.ended() and steps < 7200:
		steps += 1
		b.simulate(DT)
		scene.simulate_world(DT)
		bot.step(DT)
		seen_taken = maxi(seen_taken, scene.session.hold().items.size())
	check(seen_taken > 0, "it lifted something and carried it home (%d in %d steps)" % [seen_taken, steps])
	check(scene.session.commands_sent > sent_before, "by commands")
	check_eq(scene.shift.outcome, ShiftState.EXTRACTED, "then left")
	check_eq(scene.shift.survivors, [A, B] if scene.airlock.has_point(scene._eye()) else [B], "with whoever's aboard")
	check(scene.session.banked() > 0, "and it counts")
