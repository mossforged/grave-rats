extends "res://src/enemies/stalker_deck.gd"
## Root of scenes/shift/shift_deck.tscn: one shift, solo, end to end. The stalker deck plus salvage on
## the floor, the airlock as the hold, the oxygen clock, the tiers and the big prize's alarm.
## E takes, G drops, walking into the airlock deposits, holding E there leaves, Backspace starts a new
## shift. Rules are scene-free (shift_state.gd, src/salvage); this wires them to the world.

const ShiftState := preload("res://src/shift/shift_state.gd")
const SectionLights := preload("res://src/shift/section_lights.gd")
const AlarmMarker := preload("res://src/shift/alarm_marker.gd")
const Airlock := preload("res://src/shift/airlock.gd")
const PlaceholderSiren := preload("res://src/shift/placeholder_siren.gd")
const SalvageField := preload("res://src/salvage/salvage_field.gd")
const CarryState := preload("res://src/salvage/carry_state.gd")

## Fired as each tier lands: (index from 1, its data). The ship's next threat hangs off this.
signal tier_fired(index: int, spec: Dictionary)

var shift: ShiftState
var field: SalvageField
var section: SectionLights
var marker: AlarmMarker
var airlock: Airlock
var player_id := 1
var rng := RandomNumberGenerator.new()
## Names in a tier's "wake" list -> (tier index) -> void. CUSTODIAN registers here (T014).
var wake_hooks := {}
## The seed the next shift starts from; 0 rolls a new one. Bots and tests set it.
var next_seed := 0

var _cfg: Dictionary
var _salvage_cfg: Dictionary
var _prompt: Label3D
var _siren: AudioStreamPlayer
var _chirp: AudioStreamPlayer
var _spawns_owed := 0
var _spawn_wait := 0.0
var _alarm_refresh := 0.0
var _shift_ready := false


func _ready() -> void:
	_cfg = Data.load_data("shift")
	_salvage_cfg = Data.load_data("salvage")
	super()
	player_id = int(_cfg.player_id)
	field = SalvageField.new()
	field.name = "Salvage"
	add_child(field)
	field.setup(_salvage_cfg, layout, mask.bind)
	shift = ShiftState.new(_cfg, field.rules)
	shift.add_player(player_id)
	airlock = Airlock.new()
	airlock.name = "Airlock"
	add_child(airlock)
	airlock.setup(_cfg.airlock, layout, mask.bind)
	section = SectionLights.new()
	section.name = "SectionLights"
	add_child(section)
	section.setup(_cfg.lights, layout, deck_lighting.lights, get_node("Deck").get_node("Walls"))
	marker = AlarmMarker.new()
	marker.name = "AlarmMarker"
	add_child(marker)
	marker.setup(_cfg.alarm.marker)
	_siren = _sound_player("Siren", _cfg.alarm.siren, true)
	_chirp = _sound_player("TierChirp", _cfg.tier_chirp, false)
	_make_prompt()
	run_log.shift_report = func() -> Dictionary: return shift.report()
	hud.hold_estimate = 0
	_shift_ready = true
	_start_shift()


func _sound_player(node_name: String, spec: Dictionary, looped: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = PlaceholderSiren.make(spec, int(_cfg.mix_rate), looped)
	p.volume_db = float(spec.volume_db)
	add_child(p)
	return p


func _make_prompt() -> void:
	var c: Dictionary = _cfg.prompt
	_prompt = Label3D.new()
	_prompt.name = "TakePrompt"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.pixel_size = float(c.pixel_size)
	_prompt.font_size = int(c.font_size)
	_prompt.visible = false
	add_child(_prompt)


func _help_text() -> String:
	return String(Data.value("shift", "help", {}).text)


## A new shift. The one under way, if any, goes to the log as abandoned.
func respawn() -> void:
	if _shift_ready:
		shift.abandon()
	super()
	if _shift_ready:
		_start_shift()


func _start_shift() -> void:
	if next_seed != 0:
		rng.seed = next_seed
		next_seed = 0
	else:
		rng.randomize()
	section.rng.seed = rng.randi()
	section.reset()
	shift.begin()
	field.reset(rng)
	marker.hide_now()
	_siren.stop()
	_spawns_owed = 0
	_spawn_wait = 0.0
	_alarm_refresh = 0.0
	operator.set_carry(shift.carry(player_id).penalties())
	_sync_hud()


## The shift first, then the deck under it. After LEAVE the deck stops: nobody's left on it.
func simulate_world(delta: float) -> void:
	if not _shift_ready:
		return
	_step_shift(delta)
	if shift.outcome != ShiftState.EXTRACTED:
		super(delta)
	_show_carried()
	_sync_hud()


func _step_shift(delta: float) -> void:
	section.tick(delta)
	marker.tick(delta, _eye())
	for ev: Dictionary in shift.step(delta):
		match String(ev.type):
			ShiftState.EV_TIER:
				_on_tier(int(ev.index), ev.spec)
			ShiftState.EV_OXYGEN_OUT:
				hud.os_state.announce(String(_cfg.words.oxygen_out))
			ShiftState.EV_ALARM_OVER:
				_siren.stop()
	if shift.ended():
		return
	_step_spawns(delta)
	if shift.alarm_left > 0.0:
		_alarm_refresh -= delta
		if _alarm_refresh <= 0.0:
			_alarm_refresh = float(_cfg.alarm.refresh_s)
			pack.alert(_eye())
	for ev: Dictionary in shift.carry(player_id).step(delta):
		_on_carry_event(ev)
	var inside := airlock.has_point(_eye())
	if inside and shift.alive(player_id):
		_deposit()
	if shift.step_leave(player_id, delta, inside, _leave_held()):
		_leave()
		return
	var loss := shift.suit_loss(delta)
	if loss > 0.0:
		_hurt("oxygen", loss * float(_health_cfg.suit.max), String(_cfg.out_of_air.who), false)


func _leave_held() -> bool:
	if operator.input_enabled:
		return Input.is_physical_key_pressed(KEY_E)
	return bool(operator.scripted.get("leave", false))


func _deposit() -> void:
	var items := shift.deposit(player_id)
	if items.is_empty():
		return
	for item: RefCounted in items:
		field.put_away(item)
	operator.set_carry(shift.carry(player_id).penalties())
	hud.os_state.announce(String(_cfg.words.deposit) % items.size())


func _leave() -> void:
	operator.hold_control(float(_cfg.leave.hold_after_s))
	_siren.stop()
	marker.hide_now()
	var w: Dictionary = _cfg.words
	hud.banner = [String(w.closed), String(w.hold_line) % hud.os_state.hold_text(shift.hold.estimate()), String(w.next)]
	run_log.write("left")


func _on_tier(index: int, spec: Dictionary) -> void:
	_spawns_owed += int(spec.get("stalkers", 0))
	_spawn_wait = 0.0
	var line := String(spec.announce)
	if spec.has("lights"):
		var options: Array = spec.lights
		var space := String(options[rng.randi_range(0, options.size() - 1)])
		section.fail(space)
		line = line % String(_cfg.section_words[space])
	hud.os_state.announce(line)
	_chirp.play()
	for name_key: String in spec.get("wake", []):
		if wake_hooks.has(name_key):
			(wake_hooks[name_key] as Callable).call(index)
	tier_fired.emit(index, spec)


## New stalkers come in where nobody can see. If that's nowhere right now, it asks again shortly.
func _step_spawns(delta: float) -> void:
	if _spawns_owed <= 0:
		return
	_spawn_wait -= delta
	if _spawn_wait > 0.0:
		return
	if pack.spawn_out_of_view([_player_sees], [_eye()], rng) != null:
		_spawns_owed -= 1
	else:
		_spawn_wait = float(pack._spawn_cfg.retry_s)


## Could the player see something standing at `p`? The same five points a SightTarget is judged by.
func _player_sees(p: Vector2) -> bool:
	var r := float(sight.cfg.target_radius_m)
	var v: RefCounted = sight.visibility
	var yaw := operator.gun_yaw()
	var lit: bool = flashlight.on
	for at: Vector2 in [p, p + Vector2(r, 0), p + Vector2(-r, 0), p + Vector2(0, r), p + Vector2(0, -r)]:
		if v.can_see(_eye(), yaw, lit, at):
			return true
	return false


func _on_carry_event(ev: Dictionary) -> void:
	var item: RefCounted = ev.item
	if String(ev.type) == CarryState.EV_TAKEN:
		shift.note_taken(item)
		field.put_away(item)
		if item.prize:
			_trip_alarm()
	else:
		field.lay_down(item, _eye())
		var noise := String(ev.noise)
		if noise != "":
			pack.noise(noise, _eye())
			noise_ring.state.fire(noise)
			var sounds: Dictionary = _cfg.drop_sound
			if sounds.has(noise):
				pack.play_sound(String(sounds[noise]), operator.global_position)
	operator.set_carry(shift.carry(player_id).penalties())


## The big prize came off its mount: every stalker gets your position, and keeps getting it while you
## show. Anything still behind its panel comes out now.
func _trip_alarm() -> void:
	if not shift.trip_alarm(player_id):
		return
	var a: Dictionary = _cfg.alarm
	hud.os_state.announce(String(a.announce))
	marker.show_for(float(a.reveal_s))
	_siren.play()
	_alarm_refresh = float(a.refresh_s)
	pack.alert(_eye())
	if not ambush.fired:
		ambush.fired = true
		fire_ambush()


## E: salvage in reach comes before a bed or a door. A full pocket or full hands lets them through.
func interact() -> void:
	if shift.ended() or suit.dead or operator.control_held():
		return
	var c: CarryState = shift.carry(player_id)
	if c.busy():
		return
	var item: RefCounted = field.nearest(_eye())
	if item != null and c.begin_take(item) == CarryState.OK:
		operator.hold_control(c.busy_left())
		return
	super()


## G: lets go of what's in your hands, the heavy kind at once and loudly.
func drop_item() -> void:
	if shift.ended() or suit.dead or operator.control_held():
		return
	var c: CarryState = shift.carry(player_id)
	for ev: Dictionary in c.drop():
		_on_carry_event(ev)
	if c.busy():
		operator.hold_control(c.busy_left())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_G:
		drop_item()
		get_viewport().set_input_as_handled()
		return
	super(event)


## You're down: what you carried falls around you, and the shift's log gets written by the deck under this.
func _die(who: String, how: String) -> void:
	var items := shift.player_died(player_id)
	var spread := float(_salvage_cfg.drop_scatter_m)
	for i in items.size():
		var around := Vector2.from_angle(TAU * float(i) / float(items.size())) * spread
		field.lay_down(items[i], _eye() + around)
	_siren.stop()
	marker.hide_now()
	super(who, how)


func _killer_kind(how: String) -> String:
	return "suit" if how == "oxygen" else super(how)


## What's in your hands is shown in your hands.
func _show_carried() -> void:
	var item: RefCounted = shift.carry(player_id).in_hand
	if item != null:
		field.hold_up(item, Transform3D(Basis(Vector3.UP, operator.model.torso_yaw), operator.global_position))


func _sync_hud() -> void:
	var c: CarryState = shift.carry(player_id)
	hud.os_state.set_oxygen(shift.oxygen_left, float(_cfg.oxygen_s))
	hud.hold_estimate = shift.hold.estimate()
	var held: RefCounted = c.in_hand
	var key := ""
	if held != null:
		key = "prize" if held.prize else String(held.klass)
	hud.carry = {
		"slots_used": c.pockets.size(),
		"slots_max": int(_salvage_cfg.pocket_limit),
		"in_hand": String(held.word) if held != null else "",
		"class_word": String(field.rules.class_of(held).word) if held != null else "",
		"class_key": key,
	}
	hud.hands_full = not operator.can_fire()
	var urgent: Array = []
	if shift.alarm_left > 0.0:
		urgent.append("alarm")
	if shift.oxygen_out() and not shift.ended():
		urgent.append("o2_out")
	hud.urgent_alerts = urgent
	hud.action = _action_now(c)


func _action_now(c: CarryState) -> Dictionary:
	var w: Dictionary = _cfg.words
	if c.busy():
		var word: String = w.taking if c.busy_type() == CarryState.EV_TAKEN else w.dropping
		return {"word": word, "share": c.busy_share()}
	if not shift.ended() and shift.leave_share(player_id) > 0.0:
		return {"word": String(w.leaving), "share": shift.leave_share(player_id)}
	return {}


func _process(delta: float) -> void:
	super(delta)
	if not _shift_ready:
		return
	_update_prompt()


func _update_prompt() -> void:
	var c: Dictionary = _cfg.prompt
	_prompt.visible = false
	if shift.ended() or suit.dead:
		return
	var carry: CarryState = shift.carry(player_id)
	if airlock.has_point(_eye()):
		_show_prompt(String(c.leave), _eye(), c.color)
		return
	var item: RefCounted = field.nearest(_eye())
	if item == null or carry.busy():
		return
	_bed_prompt.visible = false
	var why := carry.can_take(item)
	if why == CarryState.POCKETS_FULL or why == CarryState.HANDS_FULL:
		_show_prompt(String(c[why]) % String(item.word), item.at, c.refused_color)
	else:
		var word := String(field.rules.class_of(item).word)
		_show_prompt(String(c.take) % [String(item.word), word], item.at, c.color)


func _show_prompt(text: String, at: Vector2, hex: Variant) -> void:
	_prompt.text = text
	_prompt.modulate = Color(String(hex))
	_prompt.global_position = Vector3(at.x, float(_cfg.prompt.height_m), at.y)
	_prompt.visible = true


# --- capture hooks (src/debug/capture.gd) ---

func capture_shots() -> Array[Dictionary]:
	return [
		{"name": "carry_small", "do": "carry", "class": "small"},
		{"name": "carry_medium", "do": "carry", "class": "medium"},
		{"name": "carry_heavy", "do": "carry", "class": "heavy"},
		{"name": "salvage_in_the_dark", "do": "dark"},
		{"name": "hold_deposit", "do": "deposit"},
		{"name": "tier1_announcement", "do": "tier", "index": 0},
		{"name": "tier2_lights_before", "do": "lights", "phase": "before"},
		{"name": "tier2_lights_flicker", "do": "lights", "phase": "flicker"},
		{"name": "tier2_lights_failed", "do": "lights", "phase": "failed"},
		{"name": "prize_alarm_1_grab", "do": "prize", "wait": 0.05},
		{"name": "prize_alarm_2_pulse", "do": "prize", "wait": 1.0},
		{"name": "prize_alarm_3_converge", "do": "prize", "wait": 6.0},
		{"name": "oxygen_zero", "do": "oxygen_zero"},
		{"name": "leaving", "do": "leaving"},
		{"name": "left", "do": "left"},
	]


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	ambush.fired = true
	match String(shot.do):
		"carry":
			await _carry_shot(String(shot["class"]))
		"dark":
			set_kit_view("known")
			var r: Rect2 = layout.space_rect("medbay")
			await _open_medbay_door()
			await _stand_at(r.get_center() + Vector2(r.size.x * 0.25, 0.0), r.get_center())
			flashlight.set_on(false)
			await _sim(0.2)
		"deposit":
			await _deposit_shot()
		"tier":
			await _stand_at(layout.point_in("junction", [0.5, 0.6]), layout.point_in("junction", [0.5, 0.1]))
			_step_clock_to(float(_cfg.tiers[int(shot.index)].at_oxygen))
			await _sim(0.5)
		"lights":
			await _lights_shot(String(shot.phase))
		"prize":
			await _prize_shot(float(shot.wait))
		"oxygen_zero":
			await _stand_at(layout.point_in("junction", [0.5, 0.5]), layout.point_in("junction", [0.5, 0.1]))
			shift.oxygen_left = float(_cfg.oxygen_s) * float(_cfg.tiers[-1].at_oxygen)
			_step_clock_to(0.0)
			await _sim(2.0)
		"leaving":
			await _stand_at(airlock.rect.get_center(), layout.point_in("junction", [0.5, 0.5]))
			operator.scripted = {"leave": true}
			await _sim(float(_cfg.leave.hold_s) * 0.6)
		"left":
			shift.hold.deposit(field.items[0])
			field.put_away(field.items[0])
			await _stand_at(airlock.rect.get_center(), layout.point_in("junction", [0.5, 0.5]))
			operator.scripted = {"leave": true}
			await _sim(float(_cfg.leave.hold_s) + 0.2)
	Engine.time_scale = 0.0


## Runs the clock to `fraction` of the oxygen left at once; the tiers land as they would.
func _step_clock_to(fraction: float) -> void:
	shift.oxygen_left = minf(shift.oxygen_left, float(_cfg.oxygen_s) * fraction)
	for ev: Dictionary in shift.step(0.0):
		match String(ev.type):
			ShiftState.EV_TIER:
				_on_tier(int(ev.index), ev.spec)
			ShiftState.EV_OXYGEN_OUT:
				hud.os_state.announce(String(_cfg.words.oxygen_out))


func _first_of(klass: String) -> RefCounted:
	for item: RefCounted in field.items:
		if String(item.klass) == klass and not item.prize:
			return item
	return null


## Standing beside one of a class in a lit room, then lifting it for real.
func _carry_shot(klass: String) -> void:
	var item := _first_of(klass)
	var mid: Vector2 = layout.point_in("junction", [0.5, 0.45])
	await _stand_at(mid, mid + Vector2(0, -4.0))
	item.at = _eye()
	field.lay_down(item, _eye())
	interact()
	if klass == "small":
		for other: RefCounted in field.items.slice(1, 3):
			shift.carry(player_id).pockets.append(other)
			field.put_away(other)
	await _sim(float(field.rules.class_of(item).pickup_s) + 0.3)
	operator.scripted = {"keys": Vector2(0, -1)}
	await _sim(0.5)


## Walks in with a full load: the moment it lands in the hold.
func _deposit_shot() -> void:
	var c: CarryState = shift.carry(player_id)
	var pocketed := 0
	for item: RefCounted in field.items:
		if String(item.klass) == "small" and pocketed < 3:
			c.pockets.append(item)
			shift.note_taken(item)
			field.put_away(item)
			pocketed += 1
	var medium := _first_of("medium")
	c.in_hand = medium
	medium.taken_by = player_id
	shift.note_taken(medium)
	operator.set_carry(c.penalties())
	var edge := airlock.rect.position.y - float(_salvage_cfg.reach_m)
	var mid := airlock.rect.get_center().x
	await _stand_at(Vector2(mid, edge), Vector2(mid, airlock.rect.end.y))
	operator.scripted = {"keys": Vector2(0, 1)}
	while not airlock.has_point(_eye()):
		await get_tree().process_frame
	operator.scripted = {}
	await _sim(0.4)


func _lights_shot(phase: String) -> void:
	var space := "cargo"
	var d := _door("cargo", 0.6)
	d.door_state.progress = 1.0
	d.door_state.state = d.door_state.State.OPEN
	d.tick(0.0, [])
	var r: Rect2 = layout.space_rect(space)
	await _stand_at(r.get_center() + Vector2(-r.size.x * 0.2, r.size.y * 0.3), r.get_center())
	set_kit_view("known")
	await _sim(0.2)
	if phase == "before":
		return
	shift.tier_reached = (_cfg.tiers as Array).size() - 1
	shift.oxygen_left = float(_cfg.oxygen_s) * float(_cfg.tiers[-1].at_oxygen)
	hud.os_state.announce(String(_cfg.tiers[-1].announce) % String(_cfg.section_words[space]))
	section.fail(space)
	await _sim(float(_cfg.lights.flicker_s) * 0.4 if phase == "flicker" else float(_cfg.lights.flicker_s) + 0.5)


func _prize_shot(wait: float) -> void:
	var prize: RefCounted = field.items.filter(func(i: RefCounted) -> bool: return i.prize)[0]
	var side := _door("side_corridor", 0.8)
	side.door_state.progress = 1.0
	side.door_state.state = side.door_state.State.OPEN
	side.tick(0.0, [])
	await _stand_at(prize.at + Vector2(float(_salvage_cfg.reach_m) * 0.7, 0.0), prize.at)
	interact()
	await _sim(float(field.rules.class_of(prize).pickup_s) + wait)
	suit.reset()


## Measuring window: tier 1 has landed, so three stalkers, all told where the player is, in the
## junction with the cargo door open. The suit refills, so the window stays a fight.
func _demo_step(delta: float) -> void:
	var dm: Dictionary = _cfg.demo
	if _demo_t == 0.0:
		ambush.fired = true
		fire_ambush()
		var d := _door("cargo", 0.6)
		d.door_state.progress = 1.0
		d.door_state.state = d.door_state.State.OPEN
		var p: Vector2 = layout.point_in("junction", [0.5, 0.5])
		operator.global_position = Vector3(p.x, 0, p.y)
		rig.snap()
		_step_clock_to(float(_cfg.tiers[0].at_oxygen))
		pack.spawn_out_of_view([_player_sees], [_eye()], rng)
		_spawns_owed = 0
		pack.stalkers[0].place_hunting(p + Vector2(float(dm.hunter_ahead_m), float(dm.hunter_side_m)), p)
	_demo_t += delta
	suit.reset()
	shift.oxygen_left = float(_cfg.oxygen_s) * float(_cfg.tiers[0].at_oxygen)
	pack.alert(_eye())
	var pace := float(dm.pace_s)
	var phase := fmod(_demo_t, pace) / pace
	var share := float(dm.pace_share)
	operator.scripted = {"keys": Vector2(-1, 0) if phase < share else (Vector2(1, 0) if phase < share * 2.0 else Vector2.ZERO)}
	operator.aim_point = _ahead(90.0 + sin(_demo_t) * 90.0)
