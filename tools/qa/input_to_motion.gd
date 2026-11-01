extends SceneTree
## Q003: how many physics steps from a real input event to the body, gun or door answering, on the real shift deck.
## Events go through Godot's Input (parse + flush), the same path keys take, not `scripted`, so it covers T018's
## command layer. It also runs on commits before T018, so the numbers compare across it.
## Step 0 means the step the event arrived in. Each case keeps its trace, so two commits compare exactly.
## usage: godot --headless --path . --fixed-fps 60 -s tools/qa/input_to_motion.gd -- <out.json>
## Not covered: a physical keyboard, the OS and display delay, the mouse-to-aim-point line (headless has no mouse;
## this sets the aim point the way the deck's _process does, then measures the body turning).

const TRACE_STEPS := 40
var deck: Node
var op: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _mouse(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


## Back to a calm, standing start, away from anything that bites.
func _reset() -> void:
	deck.respawn()
	deck.aim_from_mouse = false
	deck.suit.reset()
	op.input_enabled = true
	op.scripted = {}
	var p: Vector2 = deck.layout.point_in("junction", [0.5, 0.5])
	op.global_position = Vector3(p.x, 0.0, p.y)
	op.aim_point = op.global_position + Vector3(0.0, 1.2, -50.0)
	op.face_now(op.aim_point)
	await _steps(30)


## Sends `press` at the top of a step; `read` is sampled at the end of that step and of the ones after it.
func _trace(press: Callable, read: Callable, steps := TRACE_STEPS) -> Array:
	await physics_frame
	press.call()
	var out: Array = []
	for i in steps:
		await process_frame_after_physics()
		out.append(snappedf(float(read.call()), 0.0001))
		await physics_frame
	return out


func process_frame_after_physics() -> void:
	# Node _physics_process has run once the next process_frame fires; with --fixed-fps there is one step per frame.
	await process_frame


func _first(trace: Array, from: float) -> int:
	for i in trace.size():
		if not is_equal_approx(float(trace[i]), from):
			return i
	return -1


func _first_at(trace: Array, level: float) -> int:
	for i in trace.size():
		if float(trace[i]) >= level:
			return i
	return -1


func _case_move(name: String, code: Key, extra := KEY_NONE) -> Dictionary:
	await _reset()
	var start: Vector3 = op.global_position
	var speed: Array = await _trace(func() -> void:
		if extra != KEY_NONE:
			_key(extra, true)
		_key(code, true), func() -> float: return op.model.speed)
	var moved := (op.global_position as Vector3).distance_to(start)
	var top: float = speed.back()
	var release: Array = await _trace(func() -> void:
		_key(code, false)
		if extra != KEY_NONE:
			_key(extra, false), func() -> float: return op.model.speed)
	var stop := -1
	for i in release.size():
		if float(release[i]) <= 0.001:
			stop = i
			break
	return {"case": name, "first_response_step": _first(speed, 0.0), "steps_to_90pct_of_final": _first_at(speed, top * 0.9),
			"final_speed": top, "moved_m": snappedf(moved, 0.001), "stop_steps": stop, "trace": speed}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "/tmp/input_to_motion.json"
	deck = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	root.add_child(deck)
	await _steps(5)
	if deck.has_method("_close_form"):
		deck._close_form()
	deck.session_live = false
	deck.ambush.fired = true
	op = deck.operator
	var out: Array = []
	out.append(await _case_move("W, walk forward", KEY_W))
	out.append(await _case_move("S, walk back", KEY_S))
	out.append(await _case_move("A, strafe left", KEY_A))
	out.append(await _case_move("D, strafe right", KEY_D))
	out.append(await _case_move("Shift+W, sprint", KEY_W, KEY_SHIFT))

	await _reset()
	var crouch: Array = await _trace(func() -> void: _key(KEY_C, true), func() -> float: return op.model.crouch_amount)
	_key(KEY_C, false)
	out.append({"case": "C, crouch", "first_response_step": _first(crouch, 0.0), "steps_to_90pct_of_final": _first_at(crouch, float(crouch.back()) * 0.9), "trace": crouch})

	await _reset()
	var before := float(op.model.aim_yaw)
	var yaw: Array = await _trace(func() -> void: op.aim_point = op.global_position + Vector3(50.0, 1.2, 0.0), func() -> float: return op.model.aim_yaw)
	out.append({"case": "aim point 90 degrees right, body turns", "first_response_step": _first(yaw, before), "trace": yaw})

	await _reset()
	var mag_start := int(op.rifle.state.mag)
	var held: Array = await _trace(func() -> void: _mouse(true), func() -> float: return mag_start - int(op.rifle.state.mag))
	_mouse(false)
	await _steps(2)
	out.append({"case": "LMB held, rounds fired", "first_response_step": _first(held, 0.0), "rounds_in_trace": held.back(), "trace": held})

	await _reset()
	mag_start = int(op.rifle.state.mag)
	var tap: Array = await _trace(func() -> void:
		_mouse(true)
		_mouse(false), func() -> float: return mag_start - int(op.rifle.state.mag))
	out.append({"case": "LMB tap inside one step, rounds fired", "first_response_step": _first(tap, 0.0), "rounds_in_trace": tap.back(), "trace": tap})

	await _reset()
	op.rifle.state.mag = int(op.rifle.state.mag) - 5
	var reload: Array = await _trace(func() -> void:
		_key(KEY_R, true)
		_key(KEY_R, false), func() -> float: return 1.0 if op.rifle.state.reloading() else 0.0)
	out.append({"case": "R, reload starts", "first_response_step": _first(reload, 0.0), "trace": reload})
	await _steps(240)

	await _reset()
	# A shut door nothing else claims: E takes salvage first, then tips a bed, then works a door.
	var door: Node = null
	for d: Node in deck.doors.doors:
		if int(d.door_state.state) != int(d.door_state.State.CLOSED):
			continue
		var c: Vector2 = d.opening.get_center()
		for off: Vector2 in [Vector2(0.0, 1.0), Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]:
			var at := c + off
			op.global_position = Vector3(at.x, 0.0, at.y)
			await _steps(2)
			if deck.doors.door_in_reach(at) == d and deck.field.nearest(at) == null and deck.bed_in_reach(at) == null:
				door = d
				break
		if door != null:
			break
	if door != null:
		var was := int(door.door_state.state)
		var d: Array = await _trace(func() -> void:
			_key(KEY_E, true)
			_key(KEY_E, false), func() -> float: return int(door.door_state.state))
		out.append({"case": "E at a door, door state changes", "first_response_step": _first(d, float(was)), "trace": d})
	else:
		out.append({"case": "E at a door, door state changes", "first_response_step": -2, "note": "no shut door free of salvage and beds"})

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ") + "\n")
	f.close()
	for c: Dictionary in out:
		print("%-44s first response at step %d" % [c.case, c.first_response_step])
	quit(0)
