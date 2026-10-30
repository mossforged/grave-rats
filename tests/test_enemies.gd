extends "res://tests/test_case.gd"
## T005 stalker: senses and states, the spit's arc against cover, the ambush rule, paths, and the
## whole scene: stalkers moving, a bed tipped, the burst, a death, a run log, a respawn.

const StalkerBrain := preload("res://src/enemies/stalker_brain.gd")
const StalkerNav := preload("res://src/enemies/stalker_nav.gd")
const SpitArc := preload("res://src/enemies/spit_arc.gd")
const AmbushTrigger := preload("res://src/enemies/ambush_trigger.gd")
const CoverField := preload("res://src/cover/cover_field.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Engine.time_scale = 1.0
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _cfg() -> Dictionary:
	return ((Data.load_data("enemies") as Dictionary).stalker as Dictionary).duplicate(true)


func _brain(dormant := false, cfg := {}) -> StalkerBrain:
	return StalkerBrain.new(_cfg() if cfg.is_empty() else cfg, [Vector2(0, 0), Vector2(5, 0)], dormant)


## Quiet senses at `pos`, player far off. Override with `over`.
func _senses(pos: Vector2, over := {}) -> Dictionary:
	var s := {"pos": pos, "player": Vector2(100, 100), "alive": true, "sees": false, "clear": true,
		"ground_clear": true, "next_point": pos + Vector2(1, 0), "stalk_point": pos, "lit": false, "dodge_point": pos,
		"door_ahead": false, "door_at": pos, "door_face": pos, "at_door": false}
	s.merge(over, true)
	return s


func _steps(b: StalkerBrain, seconds: float, s: Dictionary) -> Array:
	var events: Array = []
	for i in roundi(seconds / DT):
		events.append_array(b.step(DT, s))
	return events


func test_it_prowls_until_something_happens() -> void:
	var b := _brain()
	_steps(b, 0.5, _senses(Vector2(3, 0)))
	check_eq(b.state, StalkerBrain.State.PROWL, "prowling")
	check(b.wants_move, "walking its patrol")


func test_it_patrols_between_points() -> void:
	var b := _brain()
	var cfg := b.cfg
	var first: Vector2 = b.patrol[0]
	_steps(b, float(cfg.prowl.pause_s) + 0.1, _senses(first))
	b.step(DT, _senses(first))
	check(b.goal == b.patrol[1], "after pausing at a point it heads for the next")


func test_a_shot_it_hears_sends_it_to_investigate() -> void:
	var b := _brain()
	var cfg := b.cfg
	var near := Vector2(float(cfg.senses.gunfire_m) - 1.0, 0)
	check(b.hear("gunfire", near, Vector2.ZERO), "hears gunfire in radius")
	check_eq(b.state, StalkerBrain.State.INVESTIGATE, "hears a shot -> investigate")
	check_eq(b.goal, near, "goes to the noise")
	b.step(DT, _senses(Vector2.ZERO))
	check(b.wants_move, "and walks there")


func test_noise_out_of_radius_is_not_heard_and_sprinting_is_shorter() -> void:
	var b := _brain()
	var cfg := b.cfg
	check(not b.hear("gunfire", Vector2(float(cfg.senses.gunfire_m) + 1.0, 0), Vector2.ZERO), "too far")
	check_eq(b.state, StalkerBrain.State.PROWL, "still prowling")
	check(float(cfg.senses.sprint_m) < float(cfg.senses.gunfire_m), "boots are quieter than a rifle")
	check(not b.hear("sprint", Vector2(float(cfg.senses.sprint_m) + 1.0, 0), Vector2.ZERO), "sprint has its own radius")
	check(b.hear("sprint", Vector2(float(cfg.senses.sprint_m) - 1.0, 0), Vector2.ZERO), "and is heard inside it")


func test_investigate_gives_up_and_goes_back_to_prowling() -> void:
	var b := _brain()
	var cfg := b.cfg
	b.hear("gunfire", Vector2(2, 0), Vector2.ZERO)
	_steps(b, float(cfg.investigate.linger_s) + 0.1, _senses(Vector2(2, 0)))
	check_eq(b.state, StalkerBrain.State.PROWL, "nothing there: back to the patrol")


func test_seeing_the_player_starts_the_stalk() -> void:
	var b := _brain()
	b.step(DT, _senses(Vector2.ZERO, {"sees": true, "player": Vector2(9, 0)}))
	check_eq(b.state, StalkerBrain.State.STALK, "sees the player -> stalk")
	check(b.knows, "knows")
	check_eq(b.last_known, Vector2(9, 0), "and where")


func test_it_loses_you_when_memory_runs_out() -> void:
	var b := _brain()
	var cfg := b.cfg
	b.step(DT, _senses(Vector2.ZERO, {"sees": true, "player": Vector2(50, 0)}))
	_steps(b, float(cfg.senses.memory_s) + 0.1, _senses(Vector2.ZERO, {"clear": false}))
	check_eq(b.state, StalkerBrain.State.INVESTIGATE, "out of sight long enough -> goes to the last place")
	check_eq(b.goal, Vector2(50, 0), "the last known place")


func test_sight_is_a_forward_cone_that_walls_and_low_cover_stop() -> void:
	var cfg := _cfg()
	var ahead := Vector2(0, -float(cfg.senses.sight_range_m) + 1.0)  # yaw 0 faces -Z
	check(StalkerBrain.perceives(cfg, Vector2.ZERO, 0.0, ahead, false, false), "in the cone")
	check(not StalkerBrain.perceives(cfg, Vector2.ZERO, PI, ahead, false, false), "not behind it")
	check(not StalkerBrain.perceives(cfg, Vector2.ZERO, 0.0, ahead, true, false), "not through a wall or shut door")
	check(not StalkerBrain.perceives(cfg, Vector2.ZERO, 0.0, ahead, false, true), "not through low cover")
	var close := Vector2(float(cfg.senses.close_sense_m) * 0.5, 0)
	check(StalkerBrain.perceives(cfg, Vector2.ZERO, PI, close, false, true), "right beside it, it feels you")
	check(not StalkerBrain.perceives(cfg, Vector2.ZERO, PI, close, true, false), "but not through a wall")


func test_in_range_it_spits_with_a_telegraphed_windup() -> void:
	var b := _brain()
	var cfg := b.cfg
	var d := float(cfg.spit.max_range_m) - 1.0
	var player := Vector2(0, -d)
	var s := _senses(Vector2.ZERO, {"sees": true, "player": player, "ground_clear": false})
	b.yaw = 0.0
	_steps(b, float(cfg.spit.first_delay_s) + 0.05, s)
	check_eq(b.state, StalkerBrain.State.SPIT, "in spit range -> spit")
	b.step(DT, s)
	check(b.windup > 0.0, "the wind-up shows")
	var events := _steps(b, float(cfg.spit.windup_s) * 0.5, s)
	check(not events.has(StalkerBrain.EV_SPIT), "nothing leaves before the wind-up's done")
	events = _steps(b, float(cfg.spit.windup_s) * 0.6, s)
	check(events.has(StalkerBrain.EV_SPIT), "then the glob goes")
	check_eq(b.state, StalkerBrain.State.RECOVER, "and it recovers")


func test_close_up_it_lunges_then_recovers_vulnerable() -> void:
	var b := _brain()
	var cfg := b.cfg
	var d := float(cfg.lunge.range_m) - 0.5
	var pos := Vector2(0, d)
	var s := _senses(pos, {"sees": true, "player": Vector2.ZERO})
	_steps(b, float(cfg.lunge.first_delay_s) + 0.05, s)
	check_eq(b.state, StalkerBrain.State.LUNGE, "in range -> lunge")
	check(b.velocity == Vector2.ZERO, "stands still through the wind-up")
	_steps(b, float(cfg.lunge.windup_s) * 0.9, s)
	check(not b.charging, "not before the 0.4 s wind-up ends")
	_steps(b, float(cfg.lunge.windup_s) * 0.2, s)
	check(b.charging, "then it charges")
	check(b.velocity.length() > float(cfg.dash.speed_m_s), "faster than its dash")
	var near := s.duplicate()
	near.pos = Vector2(0, float(cfg.lunge.hit_reach_m) - 0.1)
	var ev: Array = b.step(DT, near)
	check(ev.has(StalkerBrain.EV_LUNGE_HIT), "a hit when it reaches you")
	check_eq(b.state, StalkerBrain.State.RECOVER, "then recovery")
	check(b.vulnerable(), "where it's vulnerable")
	var before := b.health
	check_eq(b.take_hit(10.0, Vector2.ZERO), 10.0 * float(cfg.vulnerable_damage_mult), "and takes more")
	check_eq(before - b.health, 10.0 * float(cfg.vulnerable_damage_mult), "health follows")
	_steps(b, float(cfg.lunge.recover_s) + 0.05, near)
	check(b.state != StalkerBrain.State.RECOVER, "the recovery ends after recover_s")


func test_it_will_not_lunge_through_cover_but_will_spit() -> void:
	var b := _brain()
	var cfg := b.cfg
	var d := float(cfg.lunge.range_m) - 0.5
	var s := _senses(Vector2(0, d), {"sees": true, "player": Vector2.ZERO, "ground_clear": false})
	b.yaw = 0.0
	_steps(b, float(cfg.spit.first_delay_s) + 0.05, s)
	check_eq(b.state, StalkerBrain.State.SPIT, "a box in the way: it spits instead")


func test_it_turns_slowly_prowling_and_fast_lunging() -> void:
	var cfg := _cfg()
	check(float(cfg.turn.lunge_deg_s) > float(cfg.turn.prowl_deg_s) * 2.0, "the rule it breaks is in the numbers")
	var b := _brain()
	b.yaw = 0.0
	var s := _senses(Vector2(3, 0), {"next_point": Vector2(8, 5)})
	b.step(DT, s)
	var prowl := absf(b.yaw)
	check(absf(rad_to_deg(prowl) - float(cfg.turn.prowl_deg_s) * DT) < 0.01, "prowl turn is capped (%.3f deg)" % rad_to_deg(prowl))
	var c := _brain()
	c.force_lunge()
	c.yaw = 0.0
	c.step(DT, _senses(Vector2.ZERO, {"player": Vector2(0, 5), "sees": true}))
	check(absf(c.yaw) > prowl * 2.0, "lunge wind-up turn is far faster")


func test_a_hit_flinches_and_alerts_and_rifle_hits_to_kill_are_in_range() -> void:
	var b := _brain()
	var dmg := float(Data.value("weapons", "rifle").damage)
	b.take_hit(dmg, Vector2(7, 7))
	check(b.flinch_left > 0.0, "a hit flinches")
	check_eq(b.state, StalkerBrain.State.STALK, "and it knows now")
	check_eq(b.last_known, Vector2(7, 7), "where it came from")
	var hits := 1
	while b.alive():
		b.take_hit(dmg, Vector2(7, 7))
		hits += 1
		if hits > 50:
			break
	check(hits >= 6 and hits <= 8, "dies in 6 to 8 rifle hits (%d)" % hits)
	check_eq(b.state, StalkerBrain.State.DEAD, "dead")


func test_numbers_come_from_data() -> void:
	var cfg := _cfg()
	cfg.spit.windup_s = 5.0
	cfg.spit.first_delay_s = 0.0
	var b := StalkerBrain.new(cfg, [Vector2.ZERO])
	b.yaw = 0.0
	var s := _senses(Vector2.ZERO, {"sees": true, "player": Vector2(0, -6), "ground_clear": false})
	b.step(DT, s)
	var ev := _steps(b, 1.0, s)
	check(not ev.has(StalkerBrain.EV_SPIT), "edited windup_s is used")


func _cover() -> CoverField:
	return CoverField.new(Data.load_data("cover"))


## A crouched body at the origin, a low box 0.6 m east of it, a mouth `d` m east.
func _spit_blocked(d: float) -> bool:
	var c := _cover()
	c.set_piece("bed", Rect2(0.6, -1.0, 0.4, 2.0), CoverField.LOW)
	var cfg := _cfg()
	return SpitArc.blocked_by_cover(cfg.spit, c, Vector3(d, float(cfg.mouth_m), 0), Vector3(0, c.torso_height(1.0, false), 0))


func test_a_spit_is_blocked_by_low_cover_at_long_range_and_arcs_over_at_short_range() -> void:
	var cfg := _cfg()
	check(_spit_blocked(float(cfg.spit.long_range_m) + 1.0), "long range: low cover stops the glob")
	check(not _spit_blocked(float(cfg.spit.short_range_m) - 1.0), "short range: it arcs over")


func test_a_flying_glob_ends_on_cover_or_on_the_body() -> void:
	var cfg := _cfg()
	var c := _cover()
	c.set_piece("bed", Rect2(0.6, -1.0, 0.4, 2.0), CoverField.LOW)
	var none := func(_a: Vector2, _b: Vector2) -> bool: return false
	var body := Vector3(0, c.torso_height(1.0, false), 0)
	var far := SpitArc.new(cfg.spit, Vector3(float(cfg.spit.long_range_m) + 1.0, float(cfg.mouth_m), 0), body)
	var r := SpitArc.FLYING
	while r == SpitArc.FLYING:
		r = far.step(DT, c, none, body)
	check_eq(r, SpitArc.COVER, "the far glob splashes on the cover")
	check(far.position.x >= 0.6, "on its thrower's side")
	var near := SpitArc.new(cfg.spit, Vector3(float(cfg.spit.short_range_m) - 1.0, float(cfg.mouth_m), 0), body)
	r = SpitArc.FLYING
	while r == SpitArc.FLYING:
		r = near.step(DT, c, none, body)
	check_eq(r, SpitArc.HIT, "the near glob comes down on you")


func test_a_wall_stops_a_glob_and_a_dodged_glob_lands() -> void:
	var cfg := _cfg()
	var c := _cover()
	var wall := func(_a: Vector2, _b: Vector2) -> bool: return true
	var none := func(_a: Vector2, _b: Vector2) -> bool: return false
	var aim := Vector3(0, 0.8, 0)
	var g := SpitArc.new(cfg.spit, Vector3(5, 1, 0), aim)
	check_eq(g.step(DT, c, wall, aim), SpitArc.WALL, "a wall stops it")
	var dodged := SpitArc.new(cfg.spit, Vector3(5, 1, 0), aim)
	var r := SpitArc.FLYING
	var away := Vector3(0, 0.8, 20)
	while r == SpitArc.FLYING:
		r = dodged.step(DT, c, none, away)
	check_eq(r, SpitArc.LANDED, "if you moved, it lands where you were")


func _trigger() -> AmbushTrigger:
	return AmbushTrigger.new((Data.load_data("enemies") as Dictionary).ambush, Vector2.ZERO)


func test_the_ambush_fires_once_only_behind_the_player() -> void:
	var t := _trigger()
	var past := Vector2(1, -float(t.cfg.past_m) - 1.0)  # pass_dir is north
	var north := Vector2(0, -1)
	var south := Vector2(0, 1)
	check(not t.check(Vector2(1, 2), north), "not before they've passed it")
	check(not t.check(past, south), "not while they're looking at it")
	check(t.check(past, north), "past it, with it behind them: fires")
	check(not t.check(past, north), "only once")
	t.reset()
	check(t.check(past, north), "a respawn arms it again")


func test_the_ambush_needs_the_player_near() -> void:
	var t := _trigger()
	check(not t.check(Vector2(0, -float(t.cfg.max_range_m) - 1.0), Vector2(0, -1)), "not from across the ship")


func _layout() -> DeckLayout:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	return DeckLayout.new(deck, float(deck.room_scale))


func test_paths_go_around_walls_and_stop_at_shut_doors() -> void:
	var lay := _layout()
	var nav := StalkerNav.new(_cfg(), lay)
	var a := lay.space_rect("cargo").get_center() + Vector2(4, 4)
	var b := lay.space_rect("medbay").get_center()
	var door_rects: Array = lay.doors.map(func(d: Dictionary) -> Rect2: return d.rect)
	var open_path := nav.path(a, b)
	check(not open_path.is_empty(), "there's a way with the doors open")
	for i in door_rects.size():
		nav.set_blocker(i, door_rects[i])
	check(nav.path(a, b).is_empty(), "no way with every door shut")
	nav.set_blocker(0, Rect2())
	nav.set_blocker(1, Rect2())
	check(not nav.path(a, b).is_empty(), "two doors opened, a way again")


func test_the_stalk_does_not_come_in_a_straight_line() -> void:
	var lay := _layout()
	var cfg := _cfg()
	var nav := StalkerNav.new(cfg, lay)
	var player := lay.point_in("cargo", [0.2, 0.85])
	var from := lay.point_in("cargo", [0.85, 0.85])
	var line := (player - from).normalized()
	var no_hiding := func(_p: Vector2) -> bool: return false
	var pos := from
	var furthest := 0.0
	for i in 6:
		var goal := nav.stalk_point(pos, player, 1.0, no_hiding)
		var off := absf((goal - from).dot(line.orthogonal()))
		furthest = maxf(furthest, off)
		pos = goal
	check(furthest >= 1.0, "it swings at least a metre off the direct line (%.2f m)" % furthest)
	check(pos.distance_to(player) < from.distance_to(player), "and still closes in")


func test_the_stalk_prefers_points_you_cannot_see() -> void:
	var lay := _layout()
	var nav := StalkerNav.new(_cfg(), lay)
	var player := lay.point_in("cargo", [0.3, 0.5])
	var from := lay.point_in("cargo", [0.8, 0.5])
	# Everything south of the player counts as hidden.
	var hidden := func(p: Vector2) -> bool: return p.y > player.y + 1.0
	var goal := nav.stalk_point(from, player, 1.0, hidden)
	check(hidden.call(goal), "it goes where you can't see it: %s" % str(goal))


func test_the_breach_is_cut_only_in_a_deck_that_asks_for_one() -> void:
	var deck: Dictionary = (Data.load_data("deck") as Dictionary).duplicate(true)
	var a: Dictionary = (Data.load_data("enemies") as Dictionary).ambush
	(deck.spaces as Array).append(a.closet)
	deck.breaches = [a.breach]
	var lay := DeckLayout.new(deck, float(deck.room_scale))
	var r: Rect2 = lay.breaches[0].rect
	for w: Rect2 in lay.walls:
		check(not w.intersects(r), "no wall stands in the breach")
	var plain := DeckLayout.new(Data.load_data("deck"), 1.0)
	check(plain.breaches.is_empty(), "the shared deck has none: other scenes keep their walls")
	check(lay.path_cells(lay.space_rect("bulkhead_closet").get_center(), lay.space_rect("junction").get_center(), float(_cfg().radius_m), 0.1) >= 0, "a stalker fits through it")


# --- the scene ---

func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/enemies/stalker_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.dir = TEST_DIR
	await tree.process_frame
	return scene


## World and operator together, one per physics frame, since move_and_slide reads the frame's delta.
func _run(scene: Node, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in roundi(seconds / DT):
		await tree.physics_frame
		scene.simulate_world(DT)
		scene.operator.simulate(DT)


func _at(scene: Node, p: Vector2, look: Vector2) -> void:
	scene.operator.global_position = Vector3(p.x, 0, p.y)
	scene.operator.face_now(Vector3(look.x, 1.2, look.y))
	scene.sight.update_sight(p, scene.operator.gun_yaw(), true, DT, true)


func test_scene_builds_with_two_stalkers_three_beds_and_a_sealed_panel() -> void:
	var scene: Node = await _scene()
	check_eq(scene.pack.stalkers.size(), 2, "two stalkers")
	check_eq(scene.pack.stalkers[0].brain.state, StalkerBrain.State.PROWL, "one prowling")
	check_eq(scene.pack.stalkers[1].brain.state, StalkerBrain.State.DORMANT, "one waiting")
	check_eq(scene.beds.size(), 3, "three beds")
	check(scene.targets.is_empty(), "no dummies")
	check(scene.bulkhead.sealed, "the panel is sealed")
	check(scene.bulkhead.blocks_sight(), "and blocks sight")


func test_the_prowling_stalker_really_walks_and_doors_hold_it() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var start: Vector2 = s.floor_position()
	_at(scene, scene.layout.point_in("junction", [0.5, 0.9]), scene.layout.point_in("junction", [0.5, 0.1]))
	await _run(scene, 4.0)
	check(s.floor_position().distance_to(start) > 0.5, "it moved along its patrol")
	check(s.floor_position().distance_to(start) < float(s.cfg.speed.prowl_m_s) * 4.0 + 0.1, "slowly")
	# All doors shut: a shot next to it brings it to the door, no further.
	scene.pack.noise("gunfire", scene.layout.point_in("cargo", [0.05, 0.6]))
	check_eq(s.brain.state, StalkerBrain.State.INVESTIGATE, "it heard")
	await _run(scene, 8.0)
	check(scene.layout.space_at(s.floor_position()) == "cargo", "still in cargo with the doors shut")


func test_tipping_a_bed_in_the_scene_holds_you_and_gives_low_cover() -> void:
	var scene: Node = await _scene()
	var bed: Node = scene.beds[0]
	var c: Vector2 = bed.upright_rect.get_center()
	var p: Vector2 = c + Vector2(bed.upright_rect.size.x, 0)
	_at(scene, p, p + Vector2(0, -3))
	check(scene.bed_in_reach(p) == bed, "the bed is in reach")
	scene.operator.scripted = {"keys": Vector2(1, 0)}
	scene.interact()
	check(scene.operator.control_held(), "committed the same step")
	await _run(scene, 0.4)
	check(scene.operator.global_position.distance_to(Vector3(p.x, 0, p.y)) < 0.01, "can't walk off while tipping")
	check_eq(scene.cover.kind_of(bed), "none", "no cover yet")
	await _run(scene, 0.45)
	check(not scene.operator.control_held(), "free after the tip")
	check_eq(scene.cover.kind_of(bed), "low", "low cover now")
	check(bed.footprint().end.x <= bed.upright_rect.position.x + 0.001, "fell away from the player")
	var low_from_west: bool = scene.cover.line_blocked(Vector3(bed.footprint().position.x - 6.0, 1.0, c.y), Vector3(p.x - 0.8, 0.8, c.y))
	check(low_from_west, "a crouched body on the player's side is covered from the far side")
	scene.respawn()
	check_eq(scene.cover.kind_of(bed), "none", "a respawn stands it up again")


func test_a_big_hit_staggers_in_the_scene() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var yaw_before: float = scene.operator.model.torso_yaw
	scene.operator.scripted = {"keys": Vector2(1, 0), "fire": true}
	scene.operator.aim_point = scene.operator.global_position + Vector3(4, 1.2, 4)
	scene._on_player_hit("lunge", float(s.cfg.lunge.damage), s, false)
	check(scene.suit.staggered(), "a lunge is a big hit")
	check(scene.operator.control_held(), "control's gone")
	check(scene.operator.rifle.cone.spread_deg >= float(scene._health_cfg.stagger.cone_deg), "the cone blows wide")
	var mag: int = scene.operator.rifle.state.mag
	await _run(scene, float(scene._health_cfg.stagger.control_loss_s) * 0.8)
	check_eq(scene.operator.model.torso_yaw, yaw_before, "the body doesn't turn")
	check_eq(int(scene.operator.rifle.state.mag), mag, "the gun doesn't fire")
	await _run(scene, float(scene._health_cfg.stagger.control_loss_s) * 0.4)
	check(not scene.operator.control_held(), "and control comes back")
	check_eq(scene.run_log.damage_by_source.lunge, float(s.cfg.lunge.damage), "the log has the damage")


func test_standing_in_a_puddle_costs_suit_in_the_scene() -> void:
	var scene: Node = await _scene()
	var p: Vector2 = scene._eye()
	scene.pack.spits.add_puddle(p, "cargo stalker")
	await _run(scene, 1.0)
	var lost := float(scene._health_cfg.suit.max) - float(scene.suit.integrity)
	check(absf(lost - float(scene._health_cfg.acid.puddle_dps)) < 0.5, "about puddle_dps a second (%.2f)" % lost)
	check(scene.run_log.damage_by_source.puddle > 0.0, "logged as puddle")


func test_the_mark_is_per_shooter_not_per_box() -> void:
	var scene: Node = await _scene()
	var door: Node = scene._door("medbay", 0.7)
	scene._open_medbay_door()
	var bed: Node = scene.beds[2]
	check_eq(scene.cover.kind_of(bed), "low", "the third bed starts overturned")
	var r: Rect2 = bed.footprint()
	var behind := Vector2(r.position.x - 0.6, r.get_center().y)
	var far := Vector2(r.end.x + float(scene.pack.cfg.spit.long_range_m), r.get_center().y)
	_at(scene, behind, far)
	scene.operator.scripted = {"crouch": true}
	await _run(scene, 0.5)
	var s: Node = scene.pack.stalkers[0]
	check(door != null, "door there")
	check(scene.pack.shooter_lines().is_empty(), "behind a box with nobody hunting: no mark")
	s.place_hunting(far, behind)
	check_eq(scene.pack.shooter_lines(), [true], "a far shooter behind the bed's line: protected")
	# The same stalker on the other side of the bed: the bed doesn't cover that way.
	s.place_hunting(behind + Vector2(-float(scene.pack.cfg.spit.long_range_m), 0), behind)
	check_eq(scene.pack.shooter_lines(), [false], "the same crouch, from behind: open")
	# Up close the arc clears it, and the mark says so.
	var close := Vector2(r.end.x + float(scene.pack.cfg.spit.short_range_m) * 0.25, r.get_center().y)
	s.place_hunting(close, behind)
	check_eq(scene.pack.shooter_lines(), [false], "close enough to arc over: open")
	# Braced, the far shooter sees you too.
	s.place_hunting(far, behind)
	scene._on_rifle_fired(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, null)
	scene._sync_target()
	check_eq(scene.pack.shooter_lines(), [false], "firing from the crouch exposes you")


func test_the_burst_fires_once_behind_the_player_and_lets_it_out() -> void:
	var scene: Node = await _scene()
	var waiting: Node = scene.pack.stalkers[1]
	var c: Vector2 = scene.bulkhead.panel_center()
	var past := c + Vector2(2.0, -float(scene._ambush_cfg.past_m) - 0.5)
	_at(scene, past, past + Vector2(0, 5))  # looking back at it
	await _run(scene, 0.2)
	check(scene.bulkhead.sealed, "not while they look at it")
	var bursts := [0]
	scene.bulkhead.burst.connect(func() -> void: bursts[0] += 1)
	_at(scene, past, past + Vector2(0, -5))
	await _run(scene, DT)
	check(not scene.bulkhead.sealed, "it bursts behind them")
	check_eq(bursts[0], 1, "one burst")
	check(scene.bulkhead.debris_count() > 0, "debris")
	check(scene._kick > 0.0, "the camera kicks")
	check(not scene.bulkhead.blocks_sight(), "the hole doesn't block sight")
	check_eq(waiting.brain.state, StalkerBrain.State.DORMANT, "the bang comes first")
	await _run(scene, float(scene._ambush_cfg.emerge_delay_s) + 0.05)
	check_eq(waiting.brain.state, StalkerBrain.State.STALK, "then it comes out knowing")
	var inside: Vector2 = waiting.floor_position()
	await _run(scene, 2.0)
	check(waiting.floor_position().distance_to(inside) > 1.0, "and it really leaves the closet")
	check_eq(bursts[0], 1, "still one burst")


func test_death_writes_the_log_and_a_respawn_resets_everything() -> void:
	var scene: Node = await _scene()
	scene.run_log.enabled = true
	var s: Node = scene.pack.stalkers[0]
	scene.pack.spits.add_puddle(scene._eye() + Vector2(9, 9), s.label)
	scene.fire_ambush()
	scene.ambush.fired = true
	await _run(scene, 0.1)
	scene._hurt("lunge", float(scene._health_cfg.suit.max), s.label, false)
	check(scene.suit.dead, "dead")
	check(scene.operator.control_held(), "no control")
	var path: String = scene.run_log.last_path
	check(path.begins_with(TEST_DIR), "a life's file: %s" % path)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(d.killed_by.stalker, s.label, "says which stalker")
	check_eq(d.killed_by.how, "lunge", "and how")
	check(float(d.time_alive_s) > 0.0, "and how long")
	s.brain.force_hunt(s.floor_position(), scene._eye())
	await _run(scene, DT)
	check_eq(s.brain.state, StalkerBrain.State.PROWL, "they go back to prowling once you're dead")
	scene.respawn()
	check(not scene.suit.dead and scene.suit.fraction() == 1.0, "the suit's whole")
	check(not scene.operator.control_held(), "control's back")
	check(scene.bulkhead.sealed, "the panel's sealed")
	check(scene.bulkhead.debris_count() == 0, "the debris is gone")
	check(not scene.ambush.fired, "the ambush is armed")
	check_eq(scene.pack.stalkers[1].brain.state, StalkerBrain.State.DORMANT, "it's waiting again")
	check(scene.pack.spits.puddles.puddles.is_empty(), "no puddles")
	check_eq(scene.run_log.time_alive_s, 0.0, "a new life")


func test_shooting_a_stalker_in_the_scene_logs_and_kills_it() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var p: Vector2 = scene._eye()
	var at := p + Vector2(0, -5)
	_at(scene, p, at)
	s.place_hunting(at, p)
	scene.simulate_world(DT)
	var rifle: Node = scene.operator.rifle
	rifle.cone.spread_deg = 0.0
	var hits := 0
	for i in 20:
		rifle.cone.spread_deg = 0.0
		rifle.state.recoil_deg = 0.0
		rifle._shoot(Vector3(p.x, 1.2, p.y), s.brain.yaw_to(p, s.floor_position()), Vector3(p.x, 1.2, p.y))
		hits += 1
		if not s.brain.alive():
			break
	check(not s.brain.alive(), "enough rounds kill it")
	check(hits >= 6 and hits <= 8, "in 6 to 8 hits (%d)" % hits)
	check_eq(scene.run_log.shots_fired, hits, "shots logged")
	check_eq(scene.run_log.shots_hit, hits, "hits logged")
	check(s.shot_disc().is_empty(), "the dead aren't a target")


func test_the_rifle_and_sprinting_make_noise_in_the_scene() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var p: Vector2 = scene._eye()
	s.global_position = Vector3(p.x + float(s.cfg.senses.sprint_m) * 0.5, 0.0, p.y)
	var aim := Vector3(p.x, 1.2, p.y - 5.0)
	scene.operator.face_now(aim)
	scene.operator.scripted = {"fire": true}
	await _run(scene, DT * 2.0)
	check_eq(s.brain.state, StalkerBrain.State.INVESTIGATE, "a shot brings it")
	check(s.brain.goal.distance_to(p) < 1.5, "to where the shot was (the muzzle): %s" % str(s.brain.goal))
	scene.respawn()
	check_eq(s.brain.state, StalkerBrain.State.PROWL, "reset")
	p = scene._eye()
	s.global_position = Vector3(p.x + float(s.cfg.senses.sprint_m) * 0.5, 0.0, p.y)
	scene.operator.scripted = {"keys": Vector2(0, -1), "sprint": true}
	await _run(scene, 0.5)
	check_eq(s.brain.state, StalkerBrain.State.INVESTIGATE, "sprinting brings it too")
	scene.respawn()
	p = scene._eye()
	s.global_position = Vector3(p.x + float(s.cfg.senses.sprint_m) * 0.5, 0.0, p.y)
	scene.operator.scripted = {"keys": Vector2(0, -1)}
	await _run(scene, 0.5)
	check_eq(s.brain.state, StalkerBrain.State.PROWL, "walking doesn't")


func test_a_glob_stopped_by_cover_counts_as_protected_and_splashes_on_the_far_side() -> void:
	var scene: Node = await _scene()
	scene._open_medbay_door()
	var bed: Node = scene.beds[2]
	var r: Rect2 = bed.footprint()
	var behind := Vector2(r.position.x - 0.6, r.get_center().y)
	var far := Vector2(r.end.x + float(scene.pack.cfg.spit.long_range_m) + 1.0, r.get_center().y)
	_at(scene, behind, far)
	scene.operator.scripted = {"crouch": true}
	await _run(scene, 0.4)
	var s: Node = scene.pack.stalkers[0]
	s.place_hunting(far, behind)
	s.brain._spit_cd = INF  # only the glob this test throws
	var before: float = scene.suit.integrity
	scene.pack.spits.spit(s, Vector3(behind.x, scene.body_height(), behind.y))
	await _run(scene, float(scene.pack.cfg.spit.long_range_m) / float(scene.pack.cfg.spit.speed_m_s) + 0.5)
	check_eq(scene.run_log.times_protected, 1, "logged as protected")
	check_eq(scene.suit.integrity, before, "no damage")
	var puddles: Array = scene.pack.spits.puddles.puddles
	check_eq(puddles.size(), 1, "a puddle")
	check((puddles[0].at as Vector2).x > r.end.x, "on the thrower's side of the bed")
	check_eq(scene.pack.spits.puddles.damage_at(behind, 1.0), 0.0, "and none reaches behind it")


func test_the_e_and_backspace_keys_reach_the_scene() -> void:
	var scene: Node = await _scene()
	var bed: Node = scene.beds[0]
	var c: Vector2 = bed.upright_rect.get_center()
	var p: Vector2 = c + Vector2(bed.upright_rect.size.x, 0)
	_at(scene, p, p + Vector2(0, -3))
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	scene._unhandled_input(e)
	check(not bed.can_tip(), "E tips the bed in reach")
	check(scene.operator.control_held(), "and commits you")
	var door: Node = scene._door("medbay", 0.7)
	var at: Vector2 = door.opening.get_center() + Vector2(1.5, 0)
	scene.operator.release_control()
	_at(scene, at, at + Vector2(-3, 0))
	var was_blocking: bool = door.door_state.blocks()
	scene._unhandled_input(e)
	await _run(scene, float(scene.doors.cfg.open_s) + 0.1)
	check(door.door_state.blocks() != was_blocking, "with no bed in reach E still works the door")
	var back := InputEventKey.new()
	back.physical_keycode = KEY_BACKSPACE
	back.pressed = true
	scene._unhandled_input(back)
	check(bed.can_tip(), "Backspace resets everything: the bed stands again")
	check(door.door_state.blocks(), "and the door's shut")


func test_closing_the_window_writes_the_life_so_far() -> void:
	var scene: Node = await _scene()
	await _run(scene, 0.1)
	scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var path: String = scene.run_log.last_path
	check(path.begins_with(TEST_DIR), "a file: %s" % path)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(d.ended, "quit", "marked as a quit")
	check_eq(d.killed_by, null, "nobody killed you")


# --- T006: a dangerous stalker ---

const WALK_S := 0.45  # a person's delay acting on a bang behind them (the ambush bots)


func _hunting_brain(pos: Vector2, player: Vector2) -> StalkerBrain:
	var b := _brain()
	b.force_hunt(pos, player)
	b.rng.seed = 5
	return b


func test_a_dash_is_faster_than_the_players_walk_and_comes_in_bursts() -> void:
	var player := Vector2(0, -30)
	var b := _hunting_brain(Vector2.ZERO, player)
	var cfg := b.cfg
	var walk := float(Data.value("player", "move").walk_speed_m_s)
	check(float(cfg.dash.speed_m_s) > walk, "a dash outruns a walk in the numbers")
	var s := _senses(Vector2.ZERO, {"player": player, "stalk_point": player, "next_point": player, "sees": true, "clear": false})
	var fast := 0.0
	var moving := 0
	var still := 0
	var runs := 0
	var last_moving := false
	for i in 600:
		b.step(DT, s)
		var v := b.velocity.length()
		fast = maxf(fast, v)
		if v > 0.0:
			moving += 1
		else:
			still += 1
		if v > 0.0 and not last_moving:
			runs += 1
		last_moving = v > 0.0
	check(absf(fast - float(cfg.dash.speed_m_s)) < 0.01, "it reaches dash speed (%.2f m/s)" % fast)
	check(fast > walk, "faster than the walk")
	check(still > 0 and moving > 0, "dashes and pauses (%d steps moving, %d still)" % [moving, still])
	check(runs >= 5, "several separate dashes in 10 s (%d)" % runs)
	var mean_dash := float(moving) * DT / runs
	check(mean_dash >= float(cfg.dash.min_s) * 0.8 and mean_dash <= float(cfg.dash.max_s) * 1.2, "a dash lasts what the data says (%.2f s)" % mean_dash)


func test_a_shot_triggers_a_dodge_and_the_cooldown_holds() -> void:
	var player := Vector2(0, -8)
	var b := _hunting_brain(Vector2.ZERO, player)
	var cfg := b.cfg
	var to_side := Vector2(float(cfg.dodge.reach_m), 0)
	var s := _senses(Vector2.ZERO, {"player": player, "dodge_point": to_side, "sees": false, "clear": false})
	b.take_hit(1.0, player)
	check(b.wants_dodge(), "a hit makes it want to dodge")
	b.step(DT, s)
	check_eq(b.state, StalkerBrain.State.DODGE, "and it does, the same step")
	check_eq(b.velocity, Vector2(float(cfg.dodge.speed_m_s), 0), "sideways, at dodge speed")
	_steps(b, float(cfg.dodge.max_s), s)
	check(b.state != StalkerBrain.State.DODGE, "the dodge ends")
	b.take_hit(1.0, player)
	check(not b.wants_dodge(), "a second hit during the cooldown doesn't dodge")
	_steps(b, float(cfg.dodge.cooldown_s) * 0.5, s)
	check(b.state != StalkerBrain.State.DODGE, "still on cooldown")
	_steps(b, float(cfg.dodge.cooldown_s), s)
	b.take_hit(1.0, player)
	check(b.wants_dodge(), "after the cooldown it can dodge again")
	var before := b.health
	check(b.take_hit(1.0, player) > 0.0 and b.health < before, "hits still land while it's dodging or about to")


func test_a_near_miss_and_a_light_landing_on_it_also_dodge() -> void:
	var player := Vector2(0, -8)
	var b := _hunting_brain(Vector2.ZERO, player)
	var s := _senses(Vector2.ZERO, {"player": player, "dodge_point": Vector2(2, 0), "sees": false, "clear": false})
	b.notice_shot(player)
	check(b.wants_dodge(), "a round going past is enough")
	var c := _hunting_brain(Vector2.ZERO, player)
	c.step(DT, s)
	check(not c.wants_dodge() and c.state != StalkerBrain.State.DODGE, "in the dark it just carries on")
	var lit := s.duplicate()
	lit.lit = true
	c.step(DT, lit)
	check_eq(c.state, StalkerBrain.State.DODGE, "the light landing on it makes it dodge")
	_steps(c, float(c.cfg.dodge.cooldown_s) + float(c.cfg.dodge.max_s), lit)
	check(c.state != StalkerBrain.State.DODGE, "only when the light first lands, not all the while it's on it")


func test_a_prowling_stalker_caught_in_the_light_knows_someone_is_there() -> void:
	var b := _brain()
	b.step(DT, _senses(Vector2.ZERO, {"lit": true, "player": Vector2(0, -12), "dodge_point": Vector2(2, 0)}))
	check(b.hunting(), "it's hunting now")
	check_eq(b.last_known, Vector2(0, -12), "toward the light")


func test_it_does_not_dodge_out_of_a_windup_and_a_recovery_keeps_its_reward() -> void:
	var player := Vector2(0, -6)
	var b := _hunting_brain(Vector2.ZERO, player)
	b.force_spit()
	b.take_hit(1.0, player)
	check(not b.wants_dodge(), "a hit doesn't get it out of a wind-up")
	var s := _senses(Vector2.ZERO, {"player": player, "dodge_point": Vector2(2, 0), "sees": false, "clear": false})
	var c := _hunting_brain(Vector2.ZERO, player)
	c.force_lunge()
	var near := s.duplicate()
	near.sees = true
	while c.state == StalkerBrain.State.LUNGE:
		c.step(DT, near)
	check(c.vulnerable(), "recovering")
	c.take_hit(1.0, player)
	c.step(DT, s)
	check_eq(c.state, StalkerBrain.State.RECOVER, "it stays open through its recovery")
	_steps(c, float(c.cfg.lunge.recover_s), s)
	c.step(DT, s)
	check_eq(c.state, StalkerBrain.State.DODGE, "and dodges as soon as it's over")


func test_the_faster_spit_comes_from_data() -> void:
	var cfg := _cfg()
	check(absf(float(cfg.spit.windup_s) - 0.4) < 0.11, "wind-up about 0.4 s (%.2f)" % float(cfg.spit.windup_s))
	check(absf(float(cfg.spit.speed_m_s) - 16.0) < 3.0, "glob about 16 m/s (%.1f)" % float(cfg.spit.speed_m_s))
	check(float(cfg.spit.damage) >= 22.0, "damage up from 16 (%.0f)" % float(cfg.spit.damage))
	cfg.spit.windup_s = 1.3
	cfg.spit.first_delay_s = 0.0
	var b := StalkerBrain.new(cfg, [Vector2.ZERO])
	var s := _senses(Vector2.ZERO, {"sees": true, "player": Vector2(0, -6), "ground_clear": false})
	b.step(DT, s)
	check(not _steps(b, 1.2, s).has(StalkerBrain.EV_SPIT), "an edited wind-up is what it waits")
	check(_steps(b, 0.2, s).has(StalkerBrain.EV_SPIT), "and then it goes")
	cfg.spit.speed_m_s = 4.0
	var slow := SpitArc.new(cfg.spit, Vector3(8, 1, 0), Vector3.ZERO)
	check_eq(slow.flight_s, 2.0, "an edited glob speed sets the flight")


func test_the_lunge_reaches_further_and_staggers() -> void:
	var cfg := _cfg()
	check(float(cfg.lunge.range_m) >= 4.5, "reach about 5 m (%.1f)" % float(cfg.lunge.range_m))
	check(float(cfg.lunge.charge_m) > float(cfg.lunge.range_m), "the charge can cover the reach")
	var h: Dictionary = Data.load_data("health")
	check(float(cfg.lunge.damage) >= float(h.suit.max) * float(h.stagger.threshold_fraction), "a lunge staggers")


## From the real spawn north past the panel. On the bang it keeps walking for `react_s`, then turns
## to the stalker and fires once the gun is within 15 degrees. {shot, hit}: seconds after the bang.
func _ambush_bot(scene: Node, react_s: float) -> Dictionary:
	var op: Node3D = scene.operator
	op.scripted = {"keys": Vector2(0, -1)}
	var guard := 0
	while not scene.ambush.fired and guard < 1200:
		op.aim_point = op.global_position + Vector3(0, 1.2, -5)
		await _run(scene, DT)
		guard += 1
	check(scene.ambush.fired, "the walk north sets it off")
	var mag: int = op.rifle.state.mag
	var full: float = scene.suit.integrity
	var out := {"shot": -1.0, "hit": -1.0}
	var t := 0.0
	var s: Node = scene.pack.stalkers[1]
	while t < 4.0 and out.hit < 0.0:
		if t >= react_s:
			var at: Vector2 = s.floor_position()
			op.aim_point = Vector3(at.x, 1.2, at.y)
			var off := absf(angle_difference(op.model.torso_yaw, op.model.yaw_to(op.global_position, op.aim_point)))
			op.scripted = {"fire": rad_to_deg(off) <= 15.0}
		else:
			op.aim_point = op.global_position + Vector3(0, 1.2, -5)
		await _run(scene, DT)
		t += DT
		if out.shot < 0.0 and int(op.rifle.state.mag) < mag:
			out.shot = t
		if float(scene.suit.integrity) < full:
			out.hit = t
	return out


func test_the_ambush_bites_a_player_who_only_reacts_to_the_sound() -> void:
	var scene: Node = await _scene()
	var r: Dictionary = await _ambush_bot(scene, WALK_S)
	check(float(r.hit) >= 0.0, "they take damage (at %.2f s)" % float(r.hit))


func test_a_player_who_turns_at_once_fires_before_being_hit() -> void:
	var scene: Node = await _scene()
	var r: Dictionary = await _ambush_bot(scene, 0.0)
	check(float(r.shot) >= 0.0, "they get a shot off (at %.2f s)" % float(r.shot))
	check(float(r.hit) < 0.0 or float(r.shot) < float(r.hit), "before being hit (shot %.2f s, hit %.2f s)" % [float(r.shot), float(r.hit)])


func test_the_burst_stalker_comes_out_fast_and_goes_straight_at_you() -> void:
	var scene: Node = await _scene()
	check(float(scene._ambush_cfg.emerge_delay_s) <= 0.3, "out within about 0.25 s")
	var s: Node = scene.pack.stalkers[1]
	var c: Vector2 = scene.bulkhead.panel_center()
	var p := c + Vector2(3.0, -float(s.cfg.lunge.range_m) - 2.0)
	_at(scene, p, p + Vector2(0, -5))
	scene.fire_ambush()
	scene.ambush.fired = true
	await _run(scene, float(scene._ambush_cfg.emerge_delay_s) + 2.0 * DT)
	check(s.brain.rushing, "it's rushing")
	await _run(scene, 0.2)
	check(absf(s.brain.velocity.length() - float(s.cfg.dash.speed_m_s)) < 0.01, "at a dash, with no pause first (%.2f m/s)" % s.brain.velocity.length())
	await _run(scene, 1.0)
	check(s.brain.state == StalkerBrain.State.LUNGE or s.brain.state == StalkerBrain.State.RECOVER, "and into a lunge: %s" % s.brain.state_name())


func test_in_stalk_it_keeps_moving_and_backs_off_after_attacking() -> void:
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var p: Vector2 = scene.layout.point_in("cargo", [0.15, 0.85])
	_at(scene, p, p + Vector2(0, -5))
	s.place_hunting(scene.layout.point_in("cargo", [0.75, 0.8]), p)
	s.brain.rng.seed = 3
	var still_longest := 0.0
	var still := 0.0
	var travelled := 0.0
	var last: Vector2 = s.floor_position()
	var backed := false
	for i in 480:
		await _run(scene, DT)
		var at: Vector2 = s.floor_position()
		travelled += at.distance_to(last)
		last = at
		backed = backed or s.brain.backing_off()
		var busy: bool = s.brain.state == StalkerBrain.State.STALK or s.brain.state == StalkerBrain.State.DODGE
		still = still + DT if busy and s.brain.velocity == Vector2.ZERO else 0.0
		still_longest = maxf(still_longest, still)
		scene.suit.reset()
	check(travelled > 12.0, "it covered ground in 8 s (%.1f m)" % travelled)
	check(still_longest < float(s.cfg.dash.pause_max_s) + float(s.cfg.stalk.replan_s), "never stands around in stalk (longest %.2f s)" % still_longest)
	check(backed, "it backs off after an attack")


func test_backing_off_prefers_further_away() -> void:
	var lay := _layout()
	var nav := StalkerNav.new(_cfg(), lay)
	var player := lay.point_in("cargo", [0.3, 0.5])
	var from := player + Vector2(4.5, 0)
	var none := func(_p: Vector2) -> bool: return false
	var coming: Vector2 = nav.stalk_point(from, player, 1.0, none, false)
	var going: Vector2 = nav.stalk_point(from, player, 1.0, none, true)
	check(going.distance_to(player) > coming.distance_to(player), "%.1f m backing off, %.1f m coming in" % [going.distance_to(player), coming.distance_to(player)])


func test_a_dodge_stays_out_of_walls() -> void:
	var lay := _layout()
	var nav := StalkerNav.new(_cfg(), lay)
	var player := lay.point_in("cargo", [0.5, 0.95])
	var from := lay.point_in("cargo", [0.97, 0.95])  # in a corner
	var none := func(_p: Vector2) -> bool: return false
	var to: Vector2 = nav.dodge_point(from, player, 1.0, none)
	check(nav.is_free(to), "somewhere it can stand")
	check(nav.line_free(from, to), "with a clear run to it")


# --- T006: doors get broken, slowly ---

func _shut_door_behind_player(scene: Node) -> Dictionary:
	var door: Node = scene._door("medbay", 0.7)
	var s: Node = scene.pack.stalkers[0]
	var inside: Vector2 = scene._door_side(door, -1.0, 3.0)
	var outside: Vector2 = scene._door_side(door, 1.0, 3.0)
	_at(scene, inside, inside + Vector2(-5, 0))
	s.place_hunting(outside, inside)
	return {"door": door, "stalker": s, "inside": inside, "outside": outside}


func test_a_stalker_breaks_a_shut_door_after_the_bang_time_and_never_opens_it() -> void:
	var scene: Node = await _scene()
	var w: Dictionary = _shut_door_behind_player(scene)
	var door: Node = w.door
	var s: Node = w.stalker
	var break_s := float(door.cfg.bash.break_s)
	check(break_s >= 6.0 and break_s <= 10.0, "about 6 to 10 s (%.1f)" % break_s)
	var bashing_s := 0.0
	var ever_opened := false
	var bangs := [0]
	var shakes := 0
	var broke_after := -1.0
	var t := 0.0
	var was_dented: float = door.door_state.bash_progress
	while t < break_s + 6.0 and broke_after < 0.0:
		await _run(scene, DT)
		t += DT
		if s.brain.bashing:
			bashing_s += DT
		var st: int = door.door_state.state
		ever_opened = ever_opened or st == door.door_state.State.OPENING or st == door.door_state.State.OPEN
		if door.door_state.is_broken():
			broke_after = bashing_s
		elif door.door_state.bash_progress > was_dented and door._shake_left > 0.0:
			shakes += 1
	check(not ever_opened, "it never opens it")
	check(broke_after >= 0.0, "it breaks it")
	check(broke_after >= break_s - 2.0 * DT, "not before the bang time (%.2f s of %.2f s)" % [broke_after, break_s])
	check(broke_after <= break_s + 2.0 * DT, "and right then")
	check(shakes > 0, "the panel shakes under the blows")
	check(not door.door_state.blocks(), "a broken door stops nothing")
	check(not door.blocks_sight(), "and hides nothing")
	await _run(scene, 1.0)
	check(s.brain.hunting(), "it comes on")
	check(door.door_state.is_broken(), "and the door stays broken")
	check(scene.doors.door_in_reach(door.opening.get_center()) == door, "fixture: in reach")
	check_eq(door.interact([]), "broken", "E doesn't work on it")
	check(not door.door_state.blocks(), "it can't be shut")
	scene.respawn()
	check(door.door_state.blocks(), "a new life has a whole door")
	check_eq(door.door_state.bash_progress, 0.0, "with no dents")


func test_it_goes_through_once_the_door_is_broken() -> void:
	var scene: Node = await _scene()
	var w: Dictionary = _shut_door_behind_player(scene)
	var door: Node = w.door
	door.door_state.bash_progress = 1.0 - 1.0 / (float(door.cfg.bash.break_s) * 60.0)
	var s: Node = w.stalker
	var t := 0.0
	while t < 6.0 and not door.door_state.is_broken():
		await _run(scene, DT)
		t += DT
	check(door.door_state.is_broken(), "fixture: broken")
	var hurt := false
	t = 0.0
	while t < 6.0 and not hurt:
		await _run(scene, DT)
		t += DT
		hurt = float(scene.suit.integrity) < float(scene._health_cfg.suit.max)
	check(hurt, "it reached the player past the broken door")
	check(s.brain.alive(), "fixture: still alive")


func test_two_stalkers_do_not_break_a_door_any_sooner() -> void:
	var scene: Node = await _scene()
	var w: Dictionary = _shut_door_behind_player(scene)
	var door: Node = w.door
	var other: Node = scene.pack.stalkers[1]
	other.brain.state = StalkerBrain.State.STALK
	other.place_hunting(w.outside + Vector2(0, 1.5), w.inside)
	var t := 0.0
	var first_bash := -1.0
	while t < float(door.cfg.bash.break_s) + 6.0 and not door.door_state.is_broken():
		await _run(scene, DT)
		t += DT
		if first_bash < 0.0 and door.door_state.bash_progress > 0.0:
			first_bash = t
	check(door.door_state.is_broken(), "fixture: it broke")
	check(t - first_bash >= float(door.cfg.bash.break_s) - 3.0 * DT, "the same bang time with two (%.2f s)" % (t - first_bash))


func test_opening_the_door_ends_the_bashing_and_the_damage_stays() -> void:
	var scene: Node = await _scene()
	var w: Dictionary = _shut_door_behind_player(scene)
	var door: Node = w.door
	var s: Node = w.stalker
	var t := 0.0
	while t < 4.0 and not s.brain.bashing:
		await _run(scene, DT)
		t += DT
	check(s.brain.bashing, "fixture: it's at the door")
	await _run(scene, 1.0)
	var dented: float = door.door_state.bash_progress
	check(dented > 0.0, "the door has taken some")
	door.door_state.state = door.door_state.State.OPEN
	door.door_state.progress = 1.0
	door._apply()
	await _run(scene, 0.6)
	check(s.brain.state != StalkerBrain.State.BASH, "with the door open it stops banging: %s" % s.brain.state_name())
	check_eq(door.door_state.bash_progress, dented, "the dents stay")


func test_a_locked_door_holds_and_a_door_with_a_way_around_is_not_bashed() -> void:
	var state: RefCounted = (load("res://src/doors/door_state.gd") as GDScript).new(Data.load_data("doors"), "locked")
	check(not state.bash(100.0), "a locked door doesn't break")
	check(state.blocks(), "and still blocks")
	var scene: Node = await _scene()
	var s: Node = scene.pack.stalkers[0]
	var p: Vector2 = scene.layout.point_in("cargo", [0.2, 0.8])
	var from: Vector2 = scene.layout.point_in("cargo", [0.8, 0.8])
	_at(scene, p, p + Vector2(0, -5))
	s.place_hunting(from, p)
	await _run(scene, 1.0)
	check(s.brain.state != StalkerBrain.State.BASH, "same room: no door to break")
	check(s.door == null, "and none in mind")


func test_a_noise_behind_a_shut_door_brings_it_to_bash() -> void:
	var scene: Node = await _scene()
	var door: Node = scene._door("cargo", 0.6)
	var s: Node = scene.pack.stalkers[0]
	var outside: Vector2 = scene._door_side(door, -1.0, 2.0)
	var noise_at: Vector2 = scene._door_side(door, -1.0, 4.0)
	s.global_position = Vector3(scene._door_side(door, 1.0, 2.5).x, 0, scene._door_side(door, 1.0, 2.5).y)
	_at(scene, noise_at, noise_at + Vector2(-5, 0))
	check(outside != noise_at, "fixture")
	scene.pack.noise("gunfire", noise_at)
	await _run(scene, 2.0)
	check_eq(s.brain.state, StalkerBrain.State.BASH, "a shot behind the door: it comes to break it")


# --- T006: small changes from John's play ---

func _crouch_in_place(scene: Node, p: Vector2) -> void:
	_at(scene, p, p + Vector2(0, -5))
	scene.operator.scripted = {"crouch": true}
	await _run(scene, float(scene.operator.model.cfg.crouch.down_s) + 0.1)


func test_in_cover_shows_behind_low_cover_with_nobody_hunting() -> void:
	var scene: Node = await _scene()
	var r: Rect2 = scene.beds[2].footprint()
	check_eq(scene.cover.kind_of(scene.beds[2]), "low", "fixture: low cover")
	var behind := Vector2(r.position.x - 0.6, r.get_center().y)
	check(scene.pack.shooter_lines().is_empty(), "fixture: nobody is hunting")
	_at(scene, behind, behind + Vector2(0, -5))
	await _run(scene, DT * 2.0)
	check(not scene.mark.in_cover, "standing: no")
	await _crouch_in_place(scene, behind)
	check(scene.mark.in_cover, "crouched behind it: IN COVER")
	check(scene.pack.shooter_lines().is_empty(), "still nobody hunting")
	scene._on_rifle_fired(Vector3.ZERO, Vector3(0, 0, 1), Vector3.ZERO, null)
	scene.simulate_world(DT)
	check(not scene.mark.in_cover, "rising to fire over it: no")


func test_in_cover_does_not_show_crouched_in_the_open() -> void:
	var scene: Node = await _scene()
	await _crouch_in_place(scene, scene.layout.point_in("junction", [0.5, 0.5]))
	check(scene.operator.model.crouch_amount > 0.9, "crouched")
	check(not scene.mark.in_cover, "with nothing near: no")


func test_the_new_camera_is_the_default_in_every_deck_and_old_presets_keep_their_keys() -> void:
	var cam: Dictionary = Data.load_data("camera")
	var d: Dictionary = cam.presets[int(cam.default_preset)]
	check_eq(float(d.pitch_deg), 60.0, "pitch")
	check_eq(float(d.distance_m), 20.5, "distance")
	check_eq(float(d.fov_deg), 35.0, "fov")
	check(int(cam.default_preset) >= 5, "past the five old keys")
	check_eq(float(cam.presets[0].pitch_deg), 56.0, "key 1 is still the old preset 1")
	check_eq(float(cam.presets[1].pitch_deg), 68.0, "key 2 is still the old preset 2")
	var scene: Node = await _scene()
	check_eq(scene.rig.preset_index, int(cam.default_preset), "this deck starts on it")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_1
	scene._unhandled_input(key)
	check_eq(scene.rig.preset_index, 0, "key 1 goes to the old preset")
	key.physical_keycode = KEY_6
	scene._unhandled_input(key)
	check_eq(scene.rig.preset_index, int(cam.default_preset), "key 6 comes back")


func test_light_off_shows_on_the_hud() -> void:
	var scene: Node = await _scene()
	var tree := Engine.get_main_loop() as SceneTree
	scene.flashlight.set_on(true)
	await tree.process_frame
	check(not scene._light_off_label.visible, "light on: nothing")
	scene.flashlight.set_on(false)
	await tree.process_frame
	check(scene._light_off_label.visible, "light off: says so")
	check_eq(scene._light_off_label.text, "LIGHT OFF", "in those words")


func test_tall_crates_block_sight_and_stop_being_low_cover() -> void:
	var scene: Node = await _scene()
	var crate: Dictionary = {}
	var index := -1
	for i in scene.layout.props.size():
		if scene.layout.props[i].type == "crate_high":
			crate = scene.layout.props[i]
			index = i
			break
	var c: Vector2 = crate.center
	var half: float = (crate.rect as Rect2).size.x * 0.5 + 0.5
	check(scene.sight.visibility.blocked(c + Vector2(half, 0), c - Vector2(half, 0)), "a 1.2 m crate blocks sight")
	check_eq(scene.cover.kind_of(index), "tall", "and counts as tall cover")


func test_awareness_circle_and_main_scene() -> void:
	check_eq(float(Data.value("sight", "awareness_radius_m")), 2.2, "the circle is John's 2.2 m")
	check_eq(String(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/enemies/stalker_deck.tscn", "F5 runs the latest build")


func test_an_open_door_hides_its_panel_and_a_shut_one_shows_it() -> void:
	var scene: Node = await _scene()
	var door: Node = scene._door("medbay", 0.7)
	check(door._panel.visible, "shut: panel")
	scene._open_medbay_door()
	check(not door._panel.visible, "fully open it lies in the wall, hidden, so it can't fight the post")
