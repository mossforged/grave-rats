extends "res://tests/test_case.gd"
## T004 doors: states, timing, locked, sight and movement blocked when shut, data placement.

const DoorState := preload("res://src/doors/door_state.gd")
const DoorSystem := preload("res://src/doors/door_system.gd")
const Door := preload("res://src/doors/door.gd")
const Visibility := preload("res://src/sight/visibility.gd")
const DeckLayout := preload("res://src/study/deck_layout.gd")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _cfg() -> Dictionary:
	return (Data.load_data("doors") as Dictionary).duplicate(true)


func _layout() -> DeckLayout:
	var deck: Dictionary = Data.load_data("deck")
	return DeckLayout.new(deck, float(deck.room_scale))


func _system() -> DoorSystem:
	var s := DoorSystem.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	_nodes.append(s)
	s.setup(_layout())
	return s


func _space_of(layout: DeckLayout, p: Vector2) -> String:
	return layout.space_at(p)


func test_a_door_takes_its_time_to_open_and_close() -> void:
	var cfg := _cfg()
	var s := DoorState.new(cfg)
	check_eq(s.state, DoorState.State.CLOSED, "starts closed")
	check_eq(s.interact(), "opening", "E opens")
	var frames := roundi(float(cfg.open_s) / DT)
	for i in frames - 2:
		s.step(DT)
	check(s.blocks(), "not open before its time")
	for i in 3:
		s.step(DT)
	check_eq(s.state, DoorState.State.OPEN, "open after open_s")
	check(not s.blocks(), "and no longer blocks")
	check_eq(s.interact(), "closing", "E closes")
	s.step(DT)
	check(s.blocks(), "blocks from the panel's first step back")
	for i in roundi(float(cfg.close_s) / DT) + 1:
		s.step(DT)
	check_eq(s.state, DoorState.State.CLOSED, "closed after close_s")


func test_numbers_come_from_data() -> void:
	var cfg := _cfg()
	cfg.open_s = 10.0
	var s := DoorState.new(cfg)
	s.interact()
	for i in 60:
		s.step(DT)
	check(absf(s.progress - 0.1) < 0.001, "edited open_s is used (%.3f)" % s.progress)


func test_a_locked_door_refuses() -> void:
	var s := DoorState.new(_cfg(), "locked")
	check_eq(s.interact(), "locked", "says locked")
	s.step(1.0)
	check_eq(s.progress, 0.0, "doesn't move")
	check(s.blocks(), "blocks")
	check_eq(s.prompt_key(), "locked", "prompt says locked")
	s.unlock()
	check_eq(s.interact(), "opening", "unlocked, it opens")


func test_a_door_never_shuts_on_someone() -> void:
	var s := DoorState.new(_cfg(), "open")
	check_eq(s.interact(false), "blocked", "won't start closing on someone in the way")
	check_eq(s.state, DoorState.State.OPEN, "stays open")
	s.interact(true)
	for i in 5:
		s.step(DT, true)
	check_eq(s.state, DoorState.State.CLOSING, "closing")
	s.step(DT, false)
	check_eq(s.state, DoorState.State.OPENING, "someone steps in: it backs off")


func test_doors_are_placed_from_data() -> void:
	var sys := _system()
	var layout := _layout()
	check(sys.doors.size() >= 4, "at least four (%d)" % sys.doors.size())
	var locked := 0
	var medbay_junction := false
	for d: Door in sys.doors:
		if d.door_state.is_locked():
			locked += 1
		# Both ends of the opening must be real spaces: a door leads somewhere.
		var c := d.opening.get_center()
		var n := Vector2(0, 1) if d.along_x else Vector2(1, 0)
		var reach := float(layout.data.wall_thickness_m)
		var a := layout.space_at(c + n * reach)
		var b := layout.space_at(c - n * reach)
		check(a != "" and b != "" and a != b, "%s %s joins two spaces (%s, %s)" % [d.space, d.side, a, b])
		if ["medbay", "junction"].has(a) and ["medbay", "junction"].has(b):
			medbay_junction = true
	check(locked >= 1, "one is locked")
	check(medbay_junction, "one between medbay and junction")


func test_a_closed_door_blocks_sight_and_an_open_one_does_not() -> void:
	var sys := _system()
	var d: Door = sys.doors[0]
	var cfg: Dictionary = Data.load_data("sight")
	var v := Visibility.new(cfg)
	v.set_static([])
	var c := d.opening.get_center()
	var a := c + Vector2(1.0, 0)
	var b := c - Vector2(1.0, 0)
	check(d.blocks_sight(), "starts blocking")
	v.set_dynamic([d.sight_rect()])
	check(v.blocked(a, b), "closed: the line across is blocked")
	d.interact([])
	for i in 10:
		d.tick(DT, [])
	check(d.blocks_sight(), "half open still has a panel")
	# Door 0 slides north: the gap opens at its south end, the panel still covers the north.
	v.set_dynamic([d.sight_rect()])
	var gap := c + Vector2(0, 0.9)
	var covered := c + Vector2(0, -0.5)
	check(not v.blocked(gap + Vector2(1, 0), gap - Vector2(1, 0)), "half open: sight passes the gap")
	check(v.blocked(covered + Vector2(1, 0), covered - Vector2(1, 0)), "and not the panel")
	for i in roundi(float(d.cfg.open_s) / DT):
		d.tick(DT, [])
	check(not d.blocks_sight(), "open: no longer blocks")


func test_closed_door_blocks_movement_and_open_one_does_not() -> void:
	var sys := _system()
	var d: Door = sys.doors[0]
	var tree := Engine.get_main_loop() as SceneTree
	var c := d.opening.get_center()
	var body := CharacterBody3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = float(Data.value("player", "radius_m"))
	shape.height = float(Data.value("player", "height_m"))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	body.add_child(cs)
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	tree.root.add_child(body)
	_nodes.append(body)
	body.global_position = Vector3(c.x + 1.5, 0, c.y)
	await tree.physics_frame
	await tree.physics_frame
	for i in 60:
		body.velocity = Vector3(-3, 0, 0)
		body.move_and_slide()
		await tree.physics_frame
	var edge := c.x + float(d.cfg.panel_thickness_m) * 0.5 + shape.radius
	check(body.global_position.x >= edge - 0.05, "stopped at the closed panel (x %.2f, panel side %.2f)" % [body.global_position.x, edge])
	d.interact([])
	for i in 60:
		d.tick(DT, [])
	await tree.physics_frame
	await tree.physics_frame
	for i in 60:
		body.velocity = Vector3(-3, 0, 0)
		body.move_and_slide()
		await tree.physics_frame
	check(body.global_position.x < c.x - 1.0, "walks through the open door (x %.2f)" % body.global_position.x)


func test_reach_and_the_prompt() -> void:
	var sys := _system()
	var d: Door = sys.doors[0]
	var c := d.opening.get_center()
	check(sys.door_in_reach(c + Vector2(float(sys.cfg.reach_m) - 0.1, 0)) == d, "in reach")
	check(sys.door_in_reach(c + Vector2(float(sys.cfg.reach_m) + 0.1, 0)) == null, "out of reach")
	check_eq(sys.interact(c + Vector2(1000, 0)), "", "E with nothing near does nothing")
	check_eq(sys.interact(c), "opening", "E near a door opens it")
	sys.show_prompt(c)
	check(sys._label.visible, "prompt shows in reach")
	sys.show_prompt(c + Vector2(1000, 0))
	check(not sys._label.visible, "and hides out of reach")


func test_a_closing_door_backs_off_for_an_actor_in_the_doorway() -> void:
	var sys := _system()
	var d: Door = sys.doors[0]
	d.door_state.state = DoorState.State.OPEN
	d.door_state.progress = 1.0
	var c := d.opening.get_center()
	sys.actors = [{"position": c, "radius": 0.4}]
	check_eq(sys.interact(c), "blocked", "refuses to close on the actor")
	sys.actors = []
	check_eq(sys.interact(c), "closing", "closes when clear")
	for i in 5:
		sys.tick(DT)
	sys.actors = [{"position": c, "radius": 0.4}]
	sys.tick(DT)
	check_eq(d.door_state.state, DoorState.State.OPENING, "backs off")
