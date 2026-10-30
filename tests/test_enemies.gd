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
		"ground_clear": true, "next_point": pos + Vector2(1, 0), "stalk_point": pos}
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
	check(b.velocity.length() > float(cfg.speed.stalk_m_s), "fast")
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
	var s := _senses(Vector2.ZERO, {"next_point": Vector2(5, 5)})
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


func test_gameplay_scene_is_in_the_deck_layout_contract_and_the_breach_is_cut() -> void:
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


## World and operator together, as the tree would.
func _run(scene: Node, seconds: float) -> void:
	for i in roundi(seconds / DT):
		scene.simulate_world(DT)
		scene.operator.simulate(DT)
		scene.doors.tick(DT)


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
	_run(scene, 4.0)
	check(s.floor_position().distance_to(start) > 0.5, "it moved along its patrol")
	check(s.floor_position().distance_to(start) < float(s.cfg.speed.prowl_m_s) * 4.0 + 0.1, "slowly")
	# All doors shut: a shot next to it brings it to the door, no further.
	scene.pack.noise("gunfire", scene.layout.point_in("cargo", [0.05, 0.6]))
	check_eq(s.brain.state, StalkerBrain.State.INVESTIGATE, "it heard")
	_run(scene, 8.0)
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
	_run(scene, 0.4)
	check(scene.operator.global_position.distance_to(Vector3(p.x, 0, p.y)) < 0.01, "can't walk off while tipping")
	check_eq(scene.cover.kind_of(bed), "none", "no cover yet")
	_run(scene, 0.45)
	check(not scene.operator.control_held(), "free after the tip")
	check_eq(scene.cover.kind_of(bed), "low", "low cover now")
	check(bed.footprint().end.x <= bed.upright_rect.position.x + 0.001, "fell away from the player")
	var low_from_west := scene.cover.line_blocked(Vector3(bed.footprint().position.x - 6.0, 1.0, c.y), Vector3(p.x - 0.8, 0.8, c.y))
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
	_run(scene, float(scene._health_cfg.stagger.control_loss_s) * 0.8)
	check_eq(scene.operator.model.torso_yaw, yaw_before, "the body doesn't turn")
	check_eq(int(scene.operator.rifle.state.mag), mag, "the gun doesn't fire")
	_run(scene, float(scene._health_cfg.stagger.control_loss_s) * 0.4)
	check(not scene.operator.control_held(), "and control comes back")
	check_eq(scene.run_log.damage_by_source.lunge, float(s.cfg.lunge.damage), "the log has the damage")


func test_standing_in_a_puddle_costs_suit_in_the_scene() -> void:
	var scene: Node = await _scene()
	var p: Vector2 = scene._eye()
	scene.pack.spits.add_puddle(p, "cargo stalker")
	_run(scene, 1.0)
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
	_run(scene, 0.5)
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
	_run(scene, 0.2)
	check(scene.bulkhead.sealed, "not while they look at it")
	var bursts := [0]
	scene.bulkhead.burst.connect(func() -> void: bursts[0] += 1)
	_at(scene, past, past + Vector2(0, -5))
	_run(scene, DT)
	check(not scene.bulkhead.sealed, "it bursts behind them")
	check_eq(bursts[0], 1, "one burst")
	check(scene.bulkhead.debris_count() > 0, "debris")
	check(scene._kick > 0.0, "the camera kicks")
	check(not scene.bulkhead.blocks_sight(), "the hole doesn't block sight")
	check_eq(waiting.brain.state, StalkerBrain.State.DORMANT, "the bang comes first")
	_run(scene, float(scene._ambush_cfg.emerge_delay_s) + 0.05)
	check_eq(waiting.brain.state, StalkerBrain.State.STALK, "then it comes out knowing")
	var inside: Vector2 = waiting.floor_position()
	_run(scene, 2.0)
	check(waiting.floor_position().distance_to(inside) > 1.0, "and it really leaves the closet")
	check_eq(bursts[0], 1, "still one burst")


func test_death_writes_the_log_and_a_respawn_resets_everything() -> void:
	var scene: Node = await _scene()
	scene.run_log.enabled = true
	var s: Node = scene.pack.stalkers[0]
	scene.pack.spits.add_puddle(scene._eye() + Vector2(9, 9), s.label)
	scene.fire_ambush()
	scene.ambush.fired = true
	_run(scene, 0.1)
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
	_run(scene, DT)
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
