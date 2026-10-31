extends "res://tests/test_case.gd"
## T012: salvage and its carry rules, the hold and LEAVE, the oxygen clock, the tiers, the big prize,
## the HUD's real numbers and the run log, on data's numbers and on the real deck.

const SalvageRules := preload("res://src/salvage/salvage_rules.gd")
const CarryState := preload("res://src/salvage/carry_state.gd")
const ShiftState := preload("res://src/shift/shift_state.gd")
const SpawnPicker := preload("res://src/enemies/spawn_picker.gd")
const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const OperatorModel := preload("res://src/player/operator_model.gd")
const SuitOs := preload("res://src/hud/suit_os.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs_shift"
const P := 1

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


func _salvage() -> Dictionary:
	return (Data.load_data("salvage") as Dictionary).duplicate(true)


func _shift_cfg() -> Dictionary:
	return (Data.load_data("shift") as Dictionary).duplicate(true)


func _rules(cfg := {}) -> SalvageRules:
	return SalvageRules.new(_salvage() if cfg.is_empty() else cfg)


func _item(rules: SalvageRules, kind: String, id := 1) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + id
	return rules.roll(kind, id, rng)


func _take(c: CarryState, item: RefCounted) -> void:
	check_eq(c.begin_take(item), CarryState.OK, "took %s" % item.word)
	c.step(c.busy_left())


func _shift(cfg := {}) -> ShiftState:
	var s := ShiftState.new(_shift_cfg() if cfg.is_empty() else cfg, _rules())
	s.add_player(P)
	return s


func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.dir = TEST_DIR
	await tree.process_frame
	return scene


func _run(scene: Node, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in roundi(seconds / DT):
		await tree.physics_frame
		scene.simulate_world(DT)
		scene.operator.simulate(DT)


func _at(scene: Node, p: Vector2, look := Vector2.INF) -> void:
	scene.operator.global_position = Vector3(p.x, 0, p.y)
	var to: Vector2 = look if look != Vector2.INF else p + Vector2(0, -3)
	scene.operator.face_now(Vector3(to.x, 1.2, to.y))
	scene.sight.update_sight(p, scene.operator.gun_yaw(), true, DT, true)


func _first(scene: Node, klass: String) -> RefCounted:
	for item: RefCounted in scene.field.items:
		if String(item.klass) == klass and not item.prize:
			return item
	return null


func _prize(scene: Node) -> RefCounted:
	return scene.field.items.filter(func(i: RefCounted) -> bool: return i.prize)[0]


## Stands on an item and lifts it for real.
func _lift(scene: Node, item: RefCounted) -> void:
	_at(scene, item.at)
	scene.interact()
	await _run(scene, float(scene.field.rules.class_of(item).pickup_s) + DT * 2.0)


func _quiet_all(scene: Node) -> void:
	scene.ambush.fired = true
	for s: Node in scene.pack.stalkers:
		s.global_position = Vector3(1000.0, 0, 1000.0)
		s.set_process(false)
		s.brain.take_hit(1000000.0, Vector2.ZERO)


# --- what's on the deck ---

func test_the_deck_has_the_salvage_the_packet_asks_for() -> void:
	var cfg := _salvage()
	var counts := {"small": 0, "medium": 0, "heavy": 0}
	var prizes := 0
	for p: Dictionary in cfg.placements:
		var spec: Dictionary = cfg.kinds[String(p.kind)]
		if bool(spec.get("prize", false)):
			prizes += 1
		else:
			counts[String(spec.class)] += 1
	check_eq(counts.small, 20, "about 20 small")
	check_eq(counts.medium, 8, "about 8 medium")
	check_eq(counts.heavy, 4, "about 4 heavy")
	check_eq(prizes, 1, "one big prize")


func test_every_item_lies_on_open_floor_you_can_walk_to() -> void:
	var scene: Node = await _scene()
	var layout: DeckLayout = scene.layout
	var r := float(Data.value("player", "radius_m"))
	var seen: Array = []
	for item: RefCounted in scene.field.items:
		check(layout.is_free(item.at, r), "%s at %s is on open floor" % [item.word, str(item.at)])
		for door: Dictionary in layout.doors:
			check(not (door.rect as Rect2).grow(r).has_point(item.at), "%s at %s clear of a door" % [item.word, str(item.at)])
		for bed: Node in scene.beds:
			check(bed.distance_to_point(item.at) > r, "%s at %s clear of a bed" % [item.word, str(item.at)])
		check(not scene.airlock.has_point(item.at), "%s isn't already in the hold" % item.word)
		for other: Vector2 in seen:
			check(other.distance_to(item.at) > 0.5, "%s at %s isn't on top of another" % [item.word, str(item.at)])
		seen.append(item.at)
	var start: Vector2 = scene.airlock.rect.get_center()
	for item: RefCounted in scene.field.items:
		check(layout.path_cells(start, item.at, r, float(layout.data.grid_m)) >= 0, "you can walk to %s at %s" % [item.word, str(item.at)])
	check_eq(layout.space_at(scene.airlock.rect.get_center()), "junction", "the airlock is on the deck")
	check(scene.airlock.has_point(scene._eye()), "and you start in it: the spawn end")


func test_values_fall_in_their_class_range_with_the_hidden_spread() -> void:
	var cfg := _salvage()
	var rules := _rules(cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var spread := float(cfg.value_spread)
	var differs := false
	for klass: String in ["small", "medium", "heavy"]:
		var c: Dictionary = cfg.classes[klass]
		for i in 200:
			var kinds: Array = (cfg.kinds as Dictionary).keys().filter(func(k: String) -> bool:
				return String(cfg.kinds[k].class) == klass and not bool(cfg.kinds[k].get("prize", false)))
			var it: RefCounted = rules.roll(String(kinds[0]), i, rng)
			check(it.base >= int(c.value_min) and it.base <= int(c.value_max), "%s base %d in range" % [klass, it.base])
			check(absf(it.value - it.base) <= it.base * spread + 1.0, "%s value %d within the spread of %d" % [klass, it.value, it.base])
			differs = differs or it.value != it.base
	check(differs, "the true value isn't the estimate")
	var prize: RefCounted = rules.roll("black_box", 1, rng)
	check(prize.prize and prize.klass == "heavy", "the black box is heavy and a prize")
	check(prize.base >= int(cfg.kinds.black_box.value_min), "and worth its own range")


func test_a_new_shift_seeds_and_resets_the_salvage() -> void:
	var scene: Node = await _scene()
	scene.next_seed = 99
	scene.respawn()
	var first: Array = scene.field.items.map(func(i: RefCounted) -> int: return i.value)
	await _lift(scene, _first(scene, "heavy"))
	scene.next_seed = 99
	scene.respawn()
	var again: Array = scene.field.items.map(func(i: RefCounted) -> int: return i.value)
	check_eq(again, first, "same seed, same ship")
	check_eq(scene.field.on_floor().size(), (scene.field.items as Array).size(), "everything's back on the floor")
	check(scene.shift.carry(P).in_hand == null, "and your hands are empty")
	check_eq(scene.operator.model.speed_mult, 1.0, "and the weight's off")


## E takes the nearest thing, so nobody lifts the black box by accident.
func test_the_prize_is_far_from_home_and_nothing_shares_its_reach() -> void:
	var scene: Node = await _scene()
	var prize := _prize(scene)
	var reach := float(_salvage().reach_m)
	for item: RefCounted in scene.field.items:
		if item != prize:
			check(item.at.distance_to(prize.at) > reach * 2.0, "%s is well clear of the prize" % item.word)
	var layout: DeckLayout = scene.layout
	var r := float(Data.value("player", "radius_m"))
	var cell := float(layout.data.grid_m)
	var to_prize: int = layout.path_cells(scene.airlock.rect.get_center(), prize.at, r, cell)
	var farther := 0
	for item: RefCounted in scene.field.items:
		if layout.path_cells(scene.airlock.rect.get_center(), item.at, r, cell) > to_prize:
			farther += 1
	check(farther <= 3, "it's among the furthest things from the airlock (%d further, %d cells)" % [farther, to_prize])


# --- carry rules ---

func test_the_pocket_limit_comes_from_data() -> void:
	var cfg := _salvage()
	cfg.pocket_limit = 2
	var rules := _rules(cfg)
	var c := CarryState.new(rules, P)
	_take(c, _item(rules, "fuse", 1))
	_take(c, _item(rules, "fuse", 2))
	check_eq(c.begin_take(_item(rules, "fuse", 3)), CarryState.POCKETS_FULL, "the third won't go")
	check_eq(c.pockets.size(), 2, "still two")
	var real := CarryState.new(_rules(), P)
	for i in int(_salvage().pocket_limit):
		_take(real, _item(_rules(), "fuse", i))
	check_eq(real.can_take(_item(_rules(), "fuse", 50)), CarryState.POCKETS_FULL, "six by default")
	check_eq(int(_salvage().pocket_limit), 6, "as the design says")


func test_pockets_cost_nothing_and_hands_hold_one() -> void:
	var rules := _rules()
	var c := CarryState.new(rules, P)
	_take(c, _item(rules, "fuse", 1))
	check_eq(c.penalties().speed_mult, 1.0, "a pocket costs no speed")
	check(bool(c.penalties().can_sprint), "or the sprint")
	_take(c, _item(rules, "relay", 2))
	check_eq(c.begin_take(_item(rules, "relay", 3)), CarryState.HANDS_FULL, "one at a time in hand")
	check_eq(c.begin_take(_item(rules, "cargo_pod", 4)), CarryState.HANDS_FULL, "and not a heavy on top")
	check_eq(c.can_take(_item(rules, "fuse", 5)), CarryState.OK, "pockets still work with your hands full")


func test_the_carry_penalties_come_from_data() -> void:
	var cfg := _salvage()
	cfg.classes.medium.speed_mult = 0.5
	cfg.classes.medium.cone_extra_deg = 11.0
	cfg.classes.heavy.speed_mult = 0.25
	var rules := _rules(cfg)
	var c := CarryState.new(rules, P)
	_take(c, _item(rules, "relay", 1))
	check_eq(c.penalties().speed_mult, 0.5, "medium speed is the data's")
	check_eq(c.penalties().cone_extra_deg, 11.0, "medium cone is the data's")
	check(bool(c.penalties().can_fire), "medium fires")
	check(not bool(c.penalties().can_sprint), "medium doesn't sprint")
	c.drop()
	c.step(float(cfg.classes.medium.drop_s))
	_take(c, _item(rules, "cargo_pod", 2))
	check_eq(c.penalties().speed_mult, 0.25, "heavy speed is the data's")
	check(not bool(c.penalties().can_fire), "heavy doesn't fire")
	check(not bool(c.penalties().can_sprint), "heavy doesn't sprint")
	var d := _salvage()
	check_eq(float(d.classes.medium.speed_mult), 0.85, "shipped: -15%")
	check_eq(float(d.classes.heavy.speed_mult), 0.65, "shipped: -35%")


func test_the_operator_obeys_the_carry() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var op: Node = scene.operator
	var cfg := _salvage()
	var walk := float(op.model.cfg.move.walk_speed_m_s)
	await _lift(scene, _first(scene, "medium"))
	check_eq(op.model.speed_mult, float(cfg.classes.medium.speed_mult), "medium in hand")
	op.scripted = {"keys": Vector2(0, -1), "sprint": true}
	await _run(scene, 1.0)
	check(not op.model.sprinting, "no sprint with a medium")
	check(absf(op.model.speed - walk * float(cfg.classes.medium.speed_mult)) < 0.01, "walks at -15%% (%.2f)" % op.model.speed)
	var medium_spread: float = op.rifle.cone.spread_deg
	op.scripted = {}
	await _run(scene, float(op.rifle.cone.cfg.settle_s) + 1.0)
	check(absf(op.rifle.cone.spread_deg - float(op.rifle.cone.cfg.tight_deg) - float(cfg.classes.medium.cone_extra_deg)) < 0.01,
			"a settled one-handed cone is the tight cone plus the data's extra (%.2f, moving %.2f)" % [op.rifle.cone.spread_deg, medium_spread])
	var mag: int = op.rifle.state.mag
	op.scripted = {"fire": true}
	await _run(scene, 0.3)
	check(op.rifle.state.mag < mag, "fires one-handed")
	op.scripted = {}
	scene.drop_item()
	await _run(scene, float(cfg.classes.medium.drop_s) + DT * 2.0)
	check_eq(op.model.speed_mult, 1.0, "free again after the drop")
	await _run(scene, float(op.rifle.cone.cfg.settle_s) + 1.0)
	check(absf(op.rifle.cone.spread_deg - float(op.rifle.cone.cfg.tight_deg)) < 0.01, "and the cone comes back with no drift")
	await _lift(scene, _first(scene, "heavy"))
	op.scripted = {"keys": Vector2(0, -1), "sprint": true}
	await _run(scene, 1.0)
	check(absf(op.model.speed - walk * float(cfg.classes.heavy.speed_mult)) < 0.01, "walks at -35%% (%.2f)" % op.model.speed)
	mag = op.rifle.state.mag
	op.scripted = {"fire": true}
	await _run(scene, 0.5)
	check_eq(op.rifle.state.mag, mag, "heavy: not a round")
	check(scene.hud.status_now().any(func(w: Dictionary) -> bool: return w.word == String(scene.hud.cfg.words.hands_full)), "and the suit says why")


# --- timing ---

func test_lifting_takes_the_data_time_and_holds_you() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var item := _first(scene, "medium")
	_at(scene, item.at)
	var need := float(_salvage().classes.medium.pickup_s)
	scene.interact()
	check(scene.operator.control_held(), "committed at once")
	check(scene.shift.carry(P).in_hand == null, "not yet in hand")
	await _run(scene, need - DT * 3.0)
	check(scene.shift.carry(P).in_hand == null, "still not, just before the time")
	check(scene.shift.carry(P).busy(), "still lifting")
	await _run(scene, DT * 4.0)
	check(scene.shift.carry(P).in_hand == item, "in hand on the time")
	check(not scene.operator.control_held(), "and you have yourself back")


func test_a_medium_drop_is_committed_a_heavy_drop_is_instant_and_loud() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var cfg := _salvage()
	var medium := _first(scene, "medium")
	await _lift(scene, medium)
	var quiet_at: float = scene.noise_ring.state.radius
	scene.drop_item()
	check(scene.operator.control_held(), "a medium drop holds you")
	check(scene.shift.carry(P).in_hand == medium, "and hasn't let go yet")
	await _run(scene, float(cfg.classes.medium.drop_s) + DT * 2.0)
	check(scene.shift.carry(P).in_hand == null, "gone after the drop time")
	check_eq(float(cfg.classes.medium.drop_s), 0.2, "shipped: 0.2 s")
	check(scene.field.nearest(scene._eye()) == medium, "and it's on the floor to pick up again")
	var heavy := _first(scene, "heavy")
	await _lift(scene, heavy)
	var was := quiet_at
	var near: Node = scene.pack.stalkers[0]
	near.brain = StalkerBrain.new(near.cfg, near.patrol)
	near._cs.disabled = false
	var thud_m := float(near.cfg.senses.thud_m)
	var spot: Vector2 = scene.layout.point_in("junction", [0.5, 0.75])
	_at(scene, spot)
	near.global_position = Vector3(spot.x, 0, spot.y - (thud_m - 1.0))
	scene.drop_item()
	check(scene.shift.carry(P).in_hand == null, "a heavy drop is instant")
	check(not scene.operator.control_held(), "and leaves you free")
	check(scene.field.nearest(scene._eye()) == heavy, "the pod lies where you stood")
	check_eq(near.brain.state, StalkerBrain.State.INVESTIGATE, "a stalker at %.1f m heard the thud" % (thud_m - 1.0))
	await _run(scene, float(scene.hud.cfg.ring.bloom_s))
	check(scene.noise_ring.state.radius > was, "the ring blooms with it")
	check(absf(scene.noise_ring.state.radius - thud_m) < 0.5, "out to the thud's own radius (%.1f)" % scene.noise_ring.state.radius)


# --- hold and leave ---

func test_walking_into_the_airlock_deposits_and_it_adds_up() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var small := _first(scene, "small")
	var medium := _first(scene, "medium")
	await _lift(scene, small)
	await _lift(scene, medium)
	check_eq(scene.shift.hold.estimate(), 0, "nothing banked out here")
	_at(scene, scene.airlock.rect.get_center())
	await _run(scene, DT)
	check_eq(scene.shift.hold.items.size(), 2, "both went in")
	check_eq(scene.shift.hold.estimate(), small.base + medium.base, "the estimate adds up")
	check_eq(scene.shift.hold.actual(), small.value + medium.value, "and the truth, kept apart")
	check(scene.shift.carry(P).carried().is_empty(), "your hands are empty")
	check_eq(scene.operator.model.speed_mult, 1.0, "and the weight's off")
	check_eq(scene.hud.hold_estimate, small.base + medium.base, "the HUD has it")
	check_eq(scene.shift.hold.by_class().medium.count, 1, "by class")
	check(not scene.shift.ended(), "depositing isn't leaving")
	var oxygen: float = scene.shift.oxygen_left
	await _run(scene, 1.0)
	check(scene.shift.oxygen_left < oxygen, "and the hold doesn't refill the clock")


func test_leave_needs_the_full_hold_in_the_airlock_and_logs_the_shift() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	scene.run_log.enabled = true
	var need := float(_shift_cfg().leave.hold_s)
	check_eq(need, 1.5, "1.5 s")
	var item := _first(scene, "medium")
	await _lift(scene, item)
	scene.operator.scripted = {"leave": true}
	await _run(scene, need + 0.5)
	check(not scene.shift.ended(), "not outside the airlock")
	_at(scene, scene.airlock.rect.get_center())
	await _run(scene, need * 0.5)
	scene.operator.scripted = {}
	await _run(scene, DT)
	check_eq(scene.shift.leave_share(P), 0.0, "letting go starts it over")
	scene.operator.scripted = {"leave": true}
	await _run(scene, need - DT * 3.0)
	check(not scene.shift.ended(), "not a moment early")
	check(scene.hud.action.word == String(_shift_cfg().words.leaving), "and the suit shows it happening")
	await _run(scene, DT * 5.0)
	check(scene.shift.ended(), "LEAVE ends the shift")
	check_eq(scene.shift.outcome, ShiftState.EXTRACTED, "as an extraction")
	check(not scene.hud.banner.is_empty(), "and says so")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.run_log.last_path))
	check_eq(d.ended, "left", "the log says it ended by leaving")
	check_eq(d.shift_outcome, "extracted", "the outcome")
	check_eq(int(d.deposited_items), 1, "what went in")
	check_eq(int(d.banked_value), item.value, "the true value, banked")
	check_eq(d.survivors, [float(P)], "who got out")
	var oxygen: float = scene.shift.oxygen_left
	await _run(scene, 1.0)
	check_eq(scene.shift.oxygen_left, oxygen, "the clock's stopped")
	scene.respawn()
	check(not scene.shift.ended(), "a respawn is the next shift")
	check_eq(scene.shift.hold.estimate(), 0, "with an empty hold")
	check_eq(scene.shift.oxygen_left, float(_shift_cfg().oxygen_s), "and a full clock")
	check(scene.hud.banner.is_empty(), "and no banner")


func test_dying_loses_the_haul_and_drops_what_you_carried() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	scene.run_log.enabled = true
	var banked := _first(scene, "small")
	await _lift(scene, banked)
	_at(scene, scene.airlock.rect.get_center())
	await _run(scene, DT)
	var held := _first(scene, "medium")
	await _lift(scene, held)
	var fell: Vector2 = scene._eye()
	scene._hurt("lunge", float(scene._health_cfg.suit.max), "cargo stalker", false)
	check(scene.suit.dead, "dead")
	check_eq(scene.shift.outcome, ShiftState.WIPED, "the whole crew's down")
	check_eq(scene.shift.banked(), 0, "and the haul's lost")
	check(held.at.distance_to(fell) < 1.0, "what you carried is where you fell")
	check(scene.field.on_floor().has(held), "on the floor")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.run_log.last_path))
	check_eq(d.shift_outcome, "wiped", "logged")
	check_eq(d.cause_of_death, "lunge", "with the cause")
	check_eq(int(d.deposited_items), 1, "what had been deposited")
	check_eq(int(d.banked_value), 0, "none of it banked")
	check_eq(int(d.items_lost), 1, "and one item lost")
	check_eq(int(d.items_lost_value), held.value, "worth this")


func test_a_respawn_mid_shift_logs_an_abandoned_shift() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	scene.run_log.enabled = true
	await _run(scene, 0.1)
	scene.respawn()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.run_log.last_path))
	check_eq(d.ended, "respawn", "the old life ended by respawn")
	check_eq(d.shift_outcome, "abandoned", "and its shift is abandoned")


# --- oxygen ---

func test_oxygen_is_the_data_clock_and_drives_the_suit_os() -> void:
	var cfg := _shift_cfg()
	check_eq(float(cfg.oxygen_s), 480.0, "8:00")
	var scene: Node = await _scene()
	_quiet_all(scene)
	check_eq(scene.hud.os_state.oxygen_text(), "08:00", "the ticker reads the shift")
	await _run(scene, 1.0)
	check(absf(scene.shift.oxygen_left - 479.0) < 0.05, "and it drains in real seconds (%.3f)" % scene.shift.oxygen_left)
	await _run(scene, 0.5)
	check_eq(scene.hud.os_state.oxygen_text(), "07:59", "the ticker follows")
	scene.hud.os_state.step(100.0)
	check(absf(scene.hud.os_state.oxygen_left - scene.shift.oxygen_left) < 0.01, "the suit counts nothing itself")
	var other := SuitOs.new((Data.load_data("hud") as Dictionary))
	other.step(10.0)
	check_eq(other.oxygen_text(), "06:30", "decks with no shift keep the placeholder")


func test_oxygen_runs_out_then_the_suit_drains_at_the_data_rate() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var rate := float(_shift_cfg().out_of_air.suit_fraction_per_s)
	check_eq(rate, 0.02, "2%/s")
	var full: float = scene.suit.integrity
	scene.shift.oxygen_left = 0.5
	await _run(scene, 0.4)
	check_eq(scene.suit.integrity, full, "no loss while there's air")
	await _run(scene, 0.2)
	check(scene.shift.oxygen_out(), "the tank's empty")
	check(scene.hud.urgent_alerts.has("o2_out"), "the alarm strip says so")
	var after: float = scene.suit.integrity
	await _run(scene, 1.0)
	var lost: float = (after - scene.suit.integrity) / float(scene._health_cfg.suit.max)
	check(absf(lost - rate) < 0.001, "loses 2%% a second (%.4f)" % lost)
	check(not scene.suit.staggered(), "a drain doesn't stagger")
	scene.suit.integrity = float(scene._health_cfg.suit.max) * rate * 0.5
	scene.run_log.enabled = true
	await _run(scene, 1.0)
	check(scene.suit.dead, "and it does kill")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.run_log.last_path))
	check_eq(d.cause_of_death, "oxygen", "cause: oxygen")
	check_eq(d.killed_by.suit, String(_shift_cfg().out_of_air.who), "killed by no stalker")
	check_eq(int(d.hits_in_open), 0, "it isn't a hit")
	check_eq(float(d.oxygen_at_exit_s), 0.0, "and the log has the tank at nothing")


func test_oxygen_at_zero_with_a_sprint_home_is_survivable() -> void:
	var s := _shift()
	s.oxygen_left = 0.0
	var steps := 0
	var lost := 0.0
	while steps < roundi(30.0 / DT):
		s.step(DT)
		lost += s.suit_loss(DT)
		steps += 1
	check(absf(lost - 0.6) < 0.01, "30 s out of air costs 60%% of a suit (%.3f): costly, not instant" % lost)


# --- tiers ---

func test_tiers_fire_at_their_thresholds_once_each_from_data() -> void:
	var cfg := _shift_cfg()
	cfg.tiers[0].at_oxygen = 0.75
	var s := _shift(cfg)
	s.oxygen_left = float(cfg.oxygen_s) * 0.76
	check(s.step(0.0).is_empty(), "above the line: nothing")
	var ev: Array = s.step(float(cfg.oxygen_s) * 0.02)
	check_eq(ev.size(), 1, "crossing it: one")
	check_eq(ev[0].type, ShiftState.EV_TIER, "a tier")
	check_eq(int(ev[0].index), 1, "the first")
	check(s.step(DT).is_empty(), "and only once")
	var real := _shift_cfg()
	check_eq(float(real.tiers[0].at_oxygen), 0.6, "shipped: 60%")
	check_eq(float(real.tiers[1].at_oxygen), 0.3, "shipped: 30%")
	var both := _shift()
	var at_once: Array = both.step(float(real.oxygen_s) * 0.8)
	check_eq(at_once.size(), 2, "a big step can't skip one")


func test_tier_1_spawns_a_stalker_out_of_sight_and_announces() -> void:
	var scene: Node = await _scene()
	var n: int = scene.pack.stalkers.size()
	var heard: Array = []
	scene.tier_fired.connect(func(i: int, _s: Dictionary) -> void: heard.append(i))
	scene.shift.oxygen_left = float(_shift_cfg().oxygen_s) * float(_shift_cfg().tiers[0].at_oxygen) + DT * 0.5
	await _run(scene, DT * 2.0)
	check_eq(heard, [1], "tier 1 landed")
	check_eq(scene.pack.stalkers.size(), n + 1, "one more stalker")
	check_eq(scene.hud.os_state.announcement(), String(_shift_cfg().tiers[0].announce), "announced")
	check(not scene._player_sees(scene.pack.stalkers[-1].floor_position()), "out of sight")
	check(scene.pack.stalkers[-1].floor_position().distance_to(scene._eye()) >= float(scene.pack._spawn_cfg.min_player_m), "and not close")
	check(scene.tracer.bodies.has(scene.pack.stalkers[-1]), "and your rounds can find it")
	await _run(scene, 1.0)
	check(scene.pack.stalkers[-1].brain.alive(), "and it's up and about")
	scene.respawn()
	check_eq(scene.pack.stalkers.size(), n, "a new shift takes it away again")
	check_eq(scene.tracer.bodies.size(), n, "from the shot tracer too")


## The packet's own check: look straight at a spawn point when it wants to use it.
func test_a_spawn_point_being_looked_at_is_never_picked() -> void:
	var scene: Node = await _scene()
	var points: Array = scene.pack.spawn_points()
	var rng := RandomNumberGenerator.new()
	var seen_any := false
	for i in points.size():
		var p: Vector2 = points[i]
		var d: Vector2 = scene.layout.point_in(String(scene.pack._spawn_specs[i].space), [0.5, 0.5])
		_at(scene, d, p)
		var open: bool = scene._player_sees(p)
		for t in 40:
			rng.seed = 100 + t
			var got := SpawnPicker.pick(points, [scene._player_sees], [scene._eye()], [], float(scene.pack._spawn_cfg.min_player_m), rng)
			check(got >= 0, "somewhere's free")
			if got >= 0:
				check(not scene._player_sees(points[got]), "%d picked is out of sight, looking at %d" % [got, i])
				if open:
					seen_any = true
					check(got != i, "never the one being looked at (%d)" % i)
	check(seen_any, "at least one point was really in view")


func test_with_every_spawn_in_sight_it_waits_then_uses_one_that_clears() -> void:
	var points := [Vector2(0, 0), Vector2(10, 0)]
	var rng := RandomNumberGenerator.new()
	var everything := func(_p: Vector2) -> bool: return true
	check_eq(SpawnPicker.pick(points, [everything], [], [], 0.0, rng), -1, "all watched: none")
	var one := func(p: Vector2) -> bool: return p.x < 5.0
	check_eq(SpawnPicker.pick(points, [one], [], [], 0.0, rng), 1, "picks the other")
	var other := func(p: Vector2) -> bool: return p.x > 5.0
	check_eq(SpawnPicker.pick(points, [one, other], [], [], 0.0, rng), -1, "any player's sight counts, per player")
	check_eq(SpawnPicker.pick(points, [], [Vector2(9, 0)], [], 3.0, rng), 0, "too close to someone: the other")
	check_eq(SpawnPicker.pick(points, [], [], [0], 0.0, rng), 1, "a used one isn't used twice")
	var scene: Node = await _scene()
	var s: Variant = scene.pack.spawn_out_of_view([everything], [scene._eye()], rng)
	check(s == null, "the pack refuses when all are in view")
	scene._spawns_owed = 1
	scene._spawn_wait = 0.0
	var n: int = scene.pack.stalkers.size()
	await _run(scene, DT)
	check_eq(scene.pack.stalkers.size(), n + 1, "the deck's next try gets one in")
	check_eq(scene._spawns_owed, 0, "and owes no more")


func test_tier_2_spawns_another_and_a_section_goes_dark_with_a_flicker() -> void:
	var cfg := _shift_cfg()
	var scene: Node = await _scene()
	var n: int = scene.pack.stalkers.size()
	var woke: Array = []
	scene.wake_hooks["custodian"] = func(i: int) -> void: woke.append(i)
	scene.shift.oxygen_left = float(cfg.oxygen_s) * float(cfg.tiers[1].at_oxygen) + DT * 0.5
	await _run(scene, DT * 2.0)
	check_eq(scene.shift.tier_reached, 2, "both tiers landed")
	await _run(scene, float(scene.pack._spawn_cfg.retry_s) + DT)
	check_eq(scene.pack.stalkers.size(), n + 2, "two more stalkers by now")
	check_eq(woke, [2], "CUSTODIAN's hook fired, at the data's tier")
	var failing: Array = (cfg.tiers[1].lights as Array).filter(func(sp: String) -> bool: return scene.section.state_of(sp) != "on")
	check_eq(failing.size(), 1, "one section fails")
	var space := String(failing[0])
	check_eq(scene.section.state_of(space), "flicker", "with a flicker")
	check(scene.section.light_count(space) > 0, "%s has lights" % space)
	check(scene.section.fixture_count(space) > 0, "and strips")
	check(scene.hud.os_state.announcement().contains(String(cfg.section_words[space])), "the suit names it")
	var flips := 0
	var was: int = scene.section.lit_lights(space)
	for i in roundi(float(cfg.lights.flicker_s) * 0.8 / DT):
		scene.section.tick(DT)
		var now: int = scene.section.lit_lights(space)
		if now != was:
			flips += 1
		was = now
	check(flips >= 2, "it really flickers (%d flips)" % flips)
	scene.section.tick(float(cfg.lights.flicker_s))
	check_eq(scene.section.state_of(space), "off", "then it's off")
	check_eq(scene.section.lit_lights(space), 0, "every light in it")
	for other: String in scene.layout.space_order:
		if other != space and scene.section.light_count(other) > 0:
			check(scene.section.lit_lights(other) == scene.section.light_count(other), "%s keeps its lights" % other)
	var energy := float((scene.section._sections[space].lights as Array)[0].energy)
	scene.respawn()
	check_eq(scene.section.state_of(space), "on", "a new shift has power")
	check_eq(scene.section.lit_lights(space), scene.section.light_count(space), "all of it")
	check_eq(((scene.section._sections[space].lights as Array)[0].light as Light3D).light_energy, energy, "at full energy")


# --- the prize ---

func test_the_prize_trips_the_alarm_and_stalkers_converge() -> void:
	var cfg := _shift_cfg()
	var scene: Node = await _scene()
	var prize := _prize(scene)
	var side: Node = scene._door("side_corridor", 0.8)
	side.door_state.progress = 1.0
	side.door_state.state = side.door_state.State.OPEN
	side.tick(0.0, [])
	scene._on_door_changed(side)
	var cargo_door: Node = scene._door("cargo", 0.6)
	cargo_door.door_state.progress = 1.0
	cargo_door.door_state.state = cargo_door.door_state.State.OPEN
	cargo_door.tick(0.0, [])
	scene._on_door_changed(cargo_door)
	check(not scene.shift.prize_taken, "not yet")
	check(scene.pack.stalkers[1].brain.state == StalkerBrain.State.DORMANT, "the panel stalker sleeps")
	await _lift(scene, prize)
	check(scene.shift.prize_taken, "the prize is lifted")
	check(scene.shift.alarm_left > 0.0, "the alarm is on")
	check(scene.marker.on, "the marker shows")
	check(absf(float(scene.marker.time_left) - float(cfg.alarm.reveal_s)) < 0.2, "for the data's %.0f s" % float(cfg.alarm.reveal_s))
	check_eq(scene.hud.os_state.announcement(), String(cfg.alarm.announce), "the suit says so")
	check(scene.hud.urgent_alerts.has("alarm"), "and the strip")
	check(scene.ambush.fired, "the panel blew")
	check(Audio.looping("alarm"), "the siren")
	var carrier: Vector2 = scene._eye()
	var awake: Node = scene.pack.stalkers[0]
	check(awake.brain.hunting(), "the prowler's hunting")
	check(awake.brain.last_known.distance_to(carrier) < 0.5, "and it knows where")
	var a0: float = scene.marker.alpha()
	await _run(scene, 0.25)
	check(scene.marker.alpha() != a0, "the marker pulses")
	check(absf(scene.marker.global_position.x - carrier.x) < 0.01, "on the carrier")
	# From the far end of the ship, so closing in is a real journey and not a stalker circling at 7 m.
	var far: Vector2 = scene.layout.point_in("junction", [0.5, 0.8])
	awake.global_position = Vector3(far.x, 0, far.y)
	var far0: float = far.distance_to(carrier)
	var closest: float = far0
	var panel_closest := INF
	for i in 8:
		scene.suit.reset()
		await _run(scene, 1.0)
		closest = minf(closest, awake.floor_position().distance_to(carrier))
		panel_closest = minf(panel_closest, scene.pack.stalkers[1].floor_position().distance_to(carrier))
		check(awake.brain.hunting(), "it's still hunting at %d s" % i)
	scene.suit.reset()
	check(scene.pack.stalkers[1].brain.state != StalkerBrain.State.DORMANT, "the panel stalker's out")
	check(closest < far0 * 0.5, "the far stalker crossed the ship (%.1f to %.1f m)" % [far0, closest])
	check(panel_closest < INF, "and the panel stalker's on its way (%.1f m)" % panel_closest)
	await _run(scene, float(cfg.alarm.reveal_s))
	check(not scene.marker.on, "the marker's done")
	check_eq(scene.shift.alarm_left, 0.0, "and so's the alarm")
	check(not scene.hud.urgent_alerts.has("alarm"), "the strip clears")


func test_the_alarm_goes_off_once_and_a_second_lift_doesnt_retrigger() -> void:
	var s := _shift()
	check(s.trip_alarm(P), "first: yes")
	s.step(float(_shift_cfg().alarm.reveal_s) + 1.0)
	check_eq(s.alarm_left, 0.0, "runs out")
	check(not s.trip_alarm(P), "second: no")
	check_eq(s.alarm_left, 0.0, "still out")


func test_an_ordinary_heavy_trips_nothing() -> void:
	var scene: Node = await _scene()
	await _lift(scene, _first(scene, "heavy"))
	check(not scene.shift.prize_taken, "no prize")
	check(not scene.marker.on, "no marker")


func test_stalker_alert_leaves_the_dead_and_dormant_alone() -> void:
	var cfg: Dictionary = (Data.load_data("enemies") as Dictionary).stalker
	var dormant := StalkerBrain.new(cfg, [Vector2.ZERO], true)
	dormant.alert(Vector2(3, 3))
	check_eq(dormant.state, StalkerBrain.State.DORMANT, "dormant stays")
	var live := StalkerBrain.new(cfg, [Vector2.ZERO])
	live.alert(Vector2(3, 3))
	check_eq(live.state, StalkerBrain.State.STALK, "a prowler hunts")
	check_eq(live.last_known, Vector2(3, 3), "where it was told")
	check(live.knows, "and knows it")


# --- HUD ---

func test_the_hud_shows_the_carry_and_a_hold_estimate() -> void:
	var scene: Node = await _scene()
	_quiet_all(scene)
	var os: SuitOs = scene.hud.os_state
	check(os.hold_text(1240).begins_with(String(scene.hud.cfg.salvage.approx)), "the hold reads as an estimate")
	check(os.hold_text(1240).ends_with("1,240"), "and grouped")
	check_eq(int(scene.hud.carry.slots_max), int(_salvage().pocket_limit), "slots from data")
	check_eq(scene.hud.carry.in_hand, "", "hands free")
	var small := _first(scene, "small")
	await _lift(scene, small)
	check_eq(int(scene.hud.carry.slots_used), 1, "one pocket used")
	var heavy := _first(scene, "heavy")
	await _lift(scene, heavy)
	check_eq(scene.hud.carry.in_hand, heavy.word, "the item in hand")
	check_eq(scene.hud.carry.class_word, String(_salvage().classes.heavy.word), "and its value class")
	check(scene.hud.hands_full, "hands full")


func test_announcements_fade_and_new_ones_replace_old() -> void:
	var cfg: Dictionary = (Data.load_data("hud") as Dictionary)
	var os := SuitOs.new(cfg)
	check_eq(os.announcement(), "", "quiet")
	os.announce("ONE")
	check_eq(os.announcement(), "ONE", "says it")
	os.announce("TWO")
	check_eq(os.announcement(), "TWO", "replaced")
	os.step(float(cfg.announce.life_s) + 0.1)
	check_eq(os.announcement(), "", "gone after its life")


func test_the_alert_strip_puts_urgent_first() -> void:
	var cfg: Dictionary = (Data.load_data("hud") as Dictionary)
	var os := SuitOs.new(cfg)
	var words: Array = os.alerts(true, 0, ["alarm", "o2_out"]).map(func(a: Dictionary) -> String: return a.word)
	check_eq(words, [String(cfg.words.alarm), String(cfg.words.o2_out), String(cfg.words.acid), String(cfg.words.low_ammo)], "order")


# --- run log ---

func test_the_run_log_has_the_new_fields() -> void:
	var log := RunLog.new(TEST_DIR)
	log.enabled = true
	var plain: Dictionary = log.to_dict("quit")
	for key: String in ["shift_outcome", "oxygen_at_exit_s", "deposited_by_class", "deposited_items", "deposited_value",
			"banked_value", "items_lost", "items_lost_value", "prize_taken", "tier_reached", "survivors", "cause_of_death"]:
		check(plain.has(key), "%s is in every log" % key)
	var s := _shift()
	var rules := _rules()
	var item := _item(rules, "cargo_pod", 3)
	s.note_taken(item)
	s.carry(P).in_hand = item
	s.oxygen_left = 200.0
	s.trip_alarm(P)
	s.step(0.0)
	check_eq(s.deposit(P).size(), 1, "deposit")
	s.step_leave(P, float(_shift_cfg().leave.hold_s), true, true)
	log.shift_report = s.report
	var d: Dictionary = log.to_dict("left")
	check_eq(d.shift_outcome, "extracted", "outcome")
	check_eq(d.oxygen_at_exit_s, 200.0, "oxygen at exit")
	check_eq(int(d.deposited_by_class.heavy.count), 1, "items by class")
	check_eq(int(d.deposited_by_class.heavy.value), item.value, "and value")
	check_eq(int(d.deposited_value), item.value, "total")
	check_eq(int(d.banked_value), item.value, "banked")
	check_eq(int(d.items_lost), 0, "nothing lost")
	check(bool(d.prize_taken), "prize taken")
	check_eq(int(d.tier_reached), 1, "tier reached")
	check_eq(d.survivors, [P], "survivors")
	var path := log.write("left")
	check(path != "", "it writes")
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(int(back.deposited_by_class.heavy.count), 1, "and survives JSON")


# --- data, not literals ---

func test_the_deck_script_keeps_its_numbers_in_data() -> void:
	var rx := RegEx.create_from_string("(?<![\\w.\"#%])(\\d+\\.\\d+|\\d+)(?![\\w\"])")
	var allowed := ["0", "1", "2", "0.0", "1.0", "2.0", "0.5"]
	var text := FileAccess.get_file_as_string("res://src/shift/shift_deck.gd")
	var rules_part := text.get_slice("# --- capture hooks", 0)
	var strip := RegEx.create_from_string("\"[^\"]*\"")
	var n := 0
	for raw in rules_part.split("\n"):
		n += 1
		var line: String = strip.sub(raw.get_slice("#", 0), "\"\"", true)
		for m in rx.search_all(line):
			if not allowed.has(m.get_string(1)):
				check(false, "shift_deck.gd:%d has the literal %s" % [n, m.get_string(1)])


func test_changing_the_data_changes_the_shift() -> void:
	var cfg := _shift_cfg()
	cfg.oxygen_s = 100.0
	cfg.leave.hold_s = 0.25
	cfg.alarm.reveal_s = 3.0
	cfg.out_of_air.suit_fraction_per_s = 0.5
	var s := _shift(cfg)
	check_eq(s.oxygen_left, 100.0, "oxygen")
	check(not s.step_leave(P, 0.2, true, true), "leave's not done")
	check(s.step_leave(P, 0.1, true, true), "leave's done on the new time")
	var t := _shift(cfg)
	t.trip_alarm(P)
	check_eq(t.alarm_left, 3.0, "reveal")
	t.oxygen_left = 0.0
	t.step(0.0)
	check_eq(t.suit_loss(1.0), 0.5, "drain")
