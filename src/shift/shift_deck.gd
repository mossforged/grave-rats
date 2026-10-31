extends "res://src/enemies/stalker_deck.gd"
## Root of scenes/shift/shift_deck.tscn: one shift, end to end, for a crew of one or more. The stalker
## deck plus salvage on the floor, the airlock as the hold, the oxygen clock, the tiers and the big
## prize's alarm. Whatever a player does arrives as a command with their ID (`_on_world_command`); what
## changes the shared world checks `session.is_authority()` first. Everything keyed "local" is what this
## machine's screen shows.
## E takes, G drops, walking into the airlock deposits, holding E there leaves, Backspace starts a new
## shift. Rules are scene-free (shift_state.gd, src/salvage); this wires them to the world.

const ShiftState := preload("res://src/shift/shift_state.gd")
const SectionLights := preload("res://src/shift/section_lights.gd")
const AlarmMarker := preload("res://src/shift/alarm_marker.gd")
const Airlock := preload("res://src/shift/airlock.gd")
const PlaceholderSiren := preload("res://src/shift/placeholder_siren.gd")
const SalvageField := preload("res://src/salvage/salvage_field.gd")
const CarryState := preload("res://src/salvage/carry_state.gd")
const QuotaState := preload("res://src/shift/quota_state.gd")
const Paperwork := preload("res://src/paperwork/paperwork.gd")
const PaperworkScreen := preload("res://src/paperwork/paperwork_screen.gd")
const Custodian := preload("res://src/custodian/custodian.gd")
const CustodianTrace := preload("res://src/custodian/custodian_trace.gd")
const PlayerSight := preload("res://src/session/player_sight.gd")

## Fired as each tier lands: (index from 1, its data). The ship's next threat hangs off this.
signal tier_fired(index: int, spec: Dictionary)

var shift: ShiftState
var field: SalvageField
var section: SectionLights
var marker: AlarmMarker
var airlock: Airlock
## The local player. Everyone else is in `session.players`.
var player_id := 1
## The session's RNG.
var rng: RandomNumberGenerator
## Names in a tier's "wake" list -> (tier index) -> void. CUSTODIAN registers here (T014).
var wake_hooks := {}
## The seed the next shift starts from; 0 rolls a new one. Bots and tests set it.
var next_seed := 0
## The session around the shifts. It runs when this is the game's main scene, or when something calls
## `start_session`; without one the deck plays single shifts as it did in T012.
var quota: QuotaState
var paperwork: Paperwork
var paper: PaperworkScreen
var session_live := false
## This session's run logs, oldest first: all the briefing may know.
var past_logs: Array = []
var contract: Dictionary = {}
var custodian: Custodian

var _bill_wait := -1.0
var _contracts := 0
var _threat_wait := 0.0
var _cfg: Dictionary
var _salvage_cfg: Dictionary
var _prompt: Label3D
var _siren: AudioStreamPlayer
var _chirp: AudioStreamPlayer
var _spawns_owed := 0
var _spawn_wait := 0.0
var _alarm_refresh := 0.0
var _shift_ready := false
var _custodian_cfg: Dictionary
var _custodian_trace: CustodianTrace
var _drone_tracer: ShotTracer
## Who the pack is hunting: it has one target at a time.
var _hunted_id := -1


func _ready() -> void:
	_cfg = Data.load_data("shift")
	_salvage_cfg = Data.load_data("salvage")
	super()
	player_id = session.local_id
	rng = session.rng
	field = SalvageField.new()
	field.name = "Salvage"
	add_child(field)
	field.setup(_salvage_cfg, layout, mask.bind)
	shift = ShiftState.new(_cfg, field.rules)
	shift.add_player(player_id)
	session.shift = shift
	session.world_commands = _on_world_command
	var me: Session.SessionPlayer = session.local()
	me.suit = suit
	me.run_log = run_log
	me.sight = sight
	me.flashlight = flashlight
	run_log.player_id = me.id
	run_log.crew = me.crew
	doors.set_authority(session.is_authority)
	pack.light_on = _anyone_lights
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
	quota = QuotaState.new(_cfg.quota)
	session.quota = quota
	paper = PaperworkScreen.new()
	paper.name = "Paperwork"
	add_child(paper)
	paper.pressed.connect(_on_paper_pressed)
	paperwork = Paperwork.new(paper.cfg)
	_make_custodian()
	_shift_ready = true
	_start_shift()
	if get_tree().current_scene == self and not _capture and _opens_on_session():
		start_session()


## The main scene runs the quota and the forms around its shifts.
func _opens_on_session() -> bool:
	return true


# --- the crew: everyone but the local player comes on through here ---

## Spawns another player and gives them what's theirs: suit, log, sight, light. Their carry is the
## shift's. Null if the session won't have them.
func join_player(id: int, crew: String, source: String) -> Operator:
	var op := spawn_player(id, crew, source)
	if op == null:
		return null
	var p: Session.SessionPlayer = session.player(id)
	p.suit = Suit.new(_health_cfg)
	p.run_log = RunLog.new(run_log.dir)
	p.run_log.enabled = run_log.enabled
	p.run_log.player_id = id
	p.run_log.crew = crew
	p.run_log.shift_report = run_log.shift_report
	p.sight = PlayerSight.new()
	p.sight.name = "Sight%d" % id
	add_child(p.sight)
	p.sight.setup(layout)
	p.sight.refresh_occluders()
	p.flashlight = Flashlight.new()
	p.flashlight.name = "Flashlight%d" % id
	add_child(p.flashlight)
	p.flashlight.setup(sight.cfg)
	p.flashlight.set_mask(mask.visible_texture(), sight.bounds)
	# This screen's sight decides whether they show. Rounds pass through the crew.
	var seen := SightTarget.new()
	seen.name = "SightTarget"
	op.add_child(seen)
	op.visuals.visible = false
	operator.rifle.exclude.append(op.get_rid())
	op.rifle.exclude = operator.rifle.exclude
	op.rifle.shot_tracer = operator.rifle.shot_tracer
	op.rifle.fired.connect(_on_mate_fired.bind(p))
	shift.add_player(id)
	op.set_carry(shift.carry(id).penalties())
	_seed_player(p)
	update_player_sight(p, 0.0, true)
	return op


func _is_local(p: Session.SessionPlayer) -> bool:
	return p.id == player_id


func player_pos(p: Session.SessionPlayer) -> Vector2:
	return Vector2(p.operator.global_position.x, p.operator.global_position.z)


func _height_of(p: Session.SessionPlayer) -> float:
	return body_height() if _is_local(p) else cover.torso_height(p.operator.model.crouch_amount, p.brace_left > 0.0)


func _lit(p: Session.SessionPlayer) -> bool:
	return flashlight.on if _is_local(p) else p.light_on


## Anyone's light on `at`: a stalker notices whichever beam finds it.
func _anyone_lights(at: Vector2) -> bool:
	for p: Session.SessionPlayer in session.players:
		if _lit(p) and p.sight.visibility.in_light(player_pos(p), p.operator.gun_yaw(), at):
			return true
	return false


## The local sight runs in `sight_deck`; this keeps another player's up to date.
func update_player_sight(p: Session.SessionPlayer, delta: float, force_memory: bool) -> void:
	var yaw: float = p.operator.gun_yaw()
	p.sight.update_sight(player_pos(p), yaw, p.light_on, delta, force_memory)
	var muzzle: Vector3 = p.operator.muzzle_position()
	p.flashlight.set_on(p.light_on)
	p.flashlight.follow(muzzle, yaw)
	p.flashlight.draw_beam(p.sight.visibility, player_pos(p), yaw, muzzle, delta)


## The world end of the command layer. The operator takes the rest (src/session/commands.gd).
func _on_world_command(cmd: Dictionary) -> void:
	var p: Session.SessionPlayer = session.player(int(cmd.player_id))
	match String(cmd.type):
		Commands.INTERACT:
			_act_interact(p)
		Commands.TAKE:
			_act_take(p)
		Commands.TIP:
			_act_tip(p)
		Commands.DOOR:
			_act_door(p)
		Commands.DROP:
			_act_drop(p)
		Commands.LEAVE:
			p.leave_held = bool(cmd.held)


func _can_act(p: Session.SessionPlayer) -> bool:
	return session.is_authority() and not shift.ended() and not p.suit.dead and not p.operator.control_held()


## E: salvage in reach comes before a bed or a door. A full pocket or full hands lets them through.
func _act_interact(p: Session.SessionPlayer) -> void:
	if not _can_act(p) or shift.carry(p.id).busy():
		return
	if not _act_take(p) and not _act_tip(p):
		_act_door(p)


func _act_take(p: Session.SessionPlayer) -> bool:
	if not _can_act(p):
		return false
	var c: CarryState = shift.carry(p.id)
	var item: RefCounted = field.nearest(player_pos(p))
	if item == null or c.begin_take(item) != CarryState.OK:
		return false
	p.operator.hold_control(c.busy_left())
	return true


func _act_tip(p: Session.SessionPlayer) -> bool:
	if not _can_act(p):
		return false
	var bed := bed_in_reach(player_pos(p))
	if bed == null or not bed.try_tip(player_pos(p)):
		return false
	p.operator.hold_control(float(_cover_cfg.bed.tip_s))
	return true


func _act_door(p: Session.SessionPlayer) -> void:
	if _can_act(p):
		doors.interact(player_pos(p))


## G: lets go of what's in your hands, the heavy kind at once and loudly.
func _act_drop(p: Session.SessionPlayer) -> void:
	if not _can_act(p):
		return
	var c: CarryState = shift.carry(p.id)
	for ev: Dictionary in c.drop():
		_on_carry_event(ev, p)
	if c.busy():
		p.operator.hold_control(c.busy_left())


## What a body does for the world that isn't the local player's (theirs is in `stalker_deck`).
func _step_crew(delta: float) -> void:
	for p: Session.SessionPlayer in session.players:
		if _is_local(p):
			continue
		p.brace_left = maxf(p.brace_left - delta, 0.0)
		p.operator.crouch_shown = move_toward(p.operator.crouch_shown,
				float(_cover_cfg.brace_crouch_shown) if p.brace_left > 0.0 else 1.0, float(_cover_cfg.brace_rate_per_s) * delta)
		p.suit.step(delta)
		if p.suit.dead:
			continue
		p.run_log.note_time(delta)
		var at := player_pos(p)
		p.noise_left -= delta
		var kind: String = p.operator.model.noise_kind()
		if kind != "" and p.noise_left <= 0.0:
			p.noise_left = float(pack.cfg.senses.sprint_emit_s)
			pack.noise(kind, at)
		var acid: float = pack.spits.puddles.damage_at(at, delta)
		if acid > 0.0:
			hurt_player(p.id, "puddle", acid, String(pack.spits.puddles.puddle_at(at).owner), false)
		if not p.suit.dead and ambush.check(at, Vector2(p.operator.aim_dir().x, p.operator.aim_dir().z)):
			fire_ambush()


func _on_mate_fired(from: Vector3, to: Vector3, _direction: Vector3, hit: Object, p: Session.SessionPlayer) -> void:
	if p.operator.model.crouch_amount > 0.0:
		p.brace_left = float(_cover_cfg.brace_hold_s)
	p.run_log.note_shot(hit != null and hit.has_method("shot_disc"))
	pack.noise("gunfire", Vector2(from.x, from.z))
	pack.shot_at(Vector2(from.x, from.z), Vector2(to.x, to.z))


## The pack hunts one player at a time: the living one nearest a stalker that's up.
func _hunted() -> Session.SessionPlayer:
	var best: Session.SessionPlayer = session.local()
	var best_d := INF
	for p: Session.SessionPlayer in session.players:
		if p.suit.dead:
			continue
		for s: Node in pack.stalkers:
			var d: float = s.floor_position().distance_to(player_pos(p))
			if s.brain.alive() and s.brain.state != s.brain.State.DORMANT and d < best_d:
				best = p
				best_d = d
	if best.suit.dead or best_d == INF:
		for p: Session.SessionPlayer in session.players:
			if not p.suit.dead:
				return p
	return best


func _sync_target() -> void:
	if not _shift_ready or session.players.size() == 1:
		_hunted_id = session.local_id
		super()
		return
	var p := _hunted()
	_hunted_id = p.id
	pack.target = {"pos": player_pos(p), "height": _height_of(p), "alive": not p.suit.dead}


func _on_player_hit(source: String, amount: float, stalker: Node3D, in_cover: bool) -> void:
	if _hunted_id == player_id:
		super(source, amount, stalker, in_cover)
	else:
		hurt_player(_hunted_id, source, amount, stalker.label, in_cover)


func _on_player_protected(_stalker: Node3D) -> void:
	session.player(_hunted_id).run_log.note_protected()


## Everything that hurts anyone comes through here.
func hurt_player(id: int, source: String, amount: float, who: String, in_cover: bool) -> void:
	if id == player_id:
		_hurt(source, amount, who, in_cover)
		return
	if not session.is_authority():
		return
	var p: Session.SessionPlayer = session.player(id)
	var result: Dictionary = p.suit.take(amount, source)
	if float(result.amount) <= 0.0:
		return
	p.run_log.note_damage(source, float(result.amount), in_cover)
	if bool(result.staggered):
		var st: Dictionary = _health_cfg.stagger
		p.operator.hold_control(float(st.control_loss_s))
		p.operator.rifle.cone.spread_deg = maxf(p.operator.rifle.cone.spread_deg, float(st.cone_deg))
	if bool(result.died):
		_mate_down(p, who, source)


func _mate_down(p: Session.SessionPlayer, who: String, how: String) -> void:
	p.run_log.note_death_location(layout.space_at(player_pos(p)))
	_drop_body(p)
	p.operator.hold_control(INF)
	p.run_log.note_death(who, how, _killer_kind(how))
	p.run_log.hold_back = not shift.ended()
	p.run_log.write("death")
	_after_death(p)


## What they carried lands around them. Whole crew down ends the shift, in ShiftState.
func _drop_body(p: Session.SessionPlayer) -> void:
	var at := player_pos(p)
	var items := shift.player_died(p.id)
	var spread := float(_salvage_cfg.drop_scatter_m)
	for i in items.size():
		var around := Vector2.from_angle(TAU * float(i) / float(items.size())) * spread
		field.lay_down(items[i], at + around)


## The alarm goes quiet with whoever set it off. The crew's last death ends the shift.
func _after_death(p: Session.SessionPlayer) -> void:
	if shift.ended() or shift.alarm_by == p.id:
		_siren.stop()
		marker.hide_now()
	if not shift.ended():
		return
	_flush_logs()
	if session_live:
		_bill_wait = float(_cfg.session.death_hold_s)


## How the shift ended is known now, so the lives that were waiting on it can go on file.
func _flush_logs() -> void:
	for p: Session.SessionPlayer in session.players:
		p.run_log.flush_held()


## The ship's AI on the deck: registers on the tier hook, gets the guns' trace, and adds its drones to
## what a round can hit. It hears nothing of the suit or the stalkers but through these signals.
func _make_custodian() -> void:
	_custodian_cfg = Data.load_data("custodian")
	_custodian_trace = CustodianTrace.new(cover, get_world_3d(), operator.rifle.exclude)
	custodian = Custodian.new()
	custodian.name = "Custodian"
	add_child(custodian)
	custodian.setup(_custodian_cfg, layout, _custodian_trace.line, sight.visibility, mask.bind, _player_knows,
			mask.visible_texture(), sight.bounds, int(_cfg.mix_rate))
	custodian.player_hit.connect(_on_custodian_hit)
	custodian.spoke.connect(func(line: String) -> void: hud.os_state.custodian_say(line))
	custodian.woke.connect(func(_reason: String) -> void: run_log.note_threat("custodian", "ship"))
	custodian.revealed.connect(func(unit: Node3D, at: Vector2) -> void: sight.flash(unit, at, _custodian_cfg.cutter.reveal))
	custodian.stalker_wanted.connect(_on_stalker_wanted)
	custodian.called.connect(_on_custodian_called)
	wake_hooks["custodian"] = func(_tier: int) -> void: custodian.wake("tier")
	_drone_tracer = ShotTracer.new(cover, get_world_3d())
	_drone_tracer.exclude = operator.rifle.exclude
	_drone_tracer.bodies = custodian.drones
	operator.rifle.shot_tracer = _trace_shot


## A round: stalkers first, as ever, then any drone that's nearer on the same line.
func _trace_shot(origin: Vector3, dir: Vector3, length: float) -> Dictionary:
	var shot: Dictionary = tracer.trace(origin, dir, length)
	var at_drone: Dictionary = _drone_tracer.trace(origin, dir, length)
	if at_drone.get("collider") == null or not (at_drone.collider as Object).has_method("shot_disc"):
		return shot
	if shot.is_empty() or origin.distance_to(at_drone.position) < origin.distance_to(shot.position):
		return at_drone
	return shot


## This screen's fog: has the local player seen this spot?
func _player_knows(p: Vector2) -> bool:
	return sight.grid.state_at(p) != sight.grid.UNKNOWN


func _on_custodian_hit(id: int, source: String, amount: float, from: Vector2, who: String) -> void:
	if id != player_id:
		hurt_player(id, source, amount, who, false)
		return
	note_hit_from(from, source)
	run_log.note_threat("custodian", layout.space_at(_eye()))
	_hurt(source, amount, who, in_cover_now())


## The nearest stalker that can come gets your position. All of them is what the alarm's for.
func _on_stalker_wanted(_id: int, at: Vector2, from: Vector2) -> void:
	var best: Node = null
	var best_d := INF
	for s: Node in pack.stalkers:
		var d: float = s.floor_position().distance_to(from)
		if s.brain.alive() and s.brain.state != s.brain.State.DORMANT and d < best_d:
			best = s
			best_d = d
	if best != null:
		best.brain.alert(at)


func _on_custodian_called(_id: int, how: String) -> void:
	run_log.note_custodian_call()
	var w: Dictionary = _custodian_cfg.words
	hud.os_state.announce(String(w.called_cutter if how == Custodian.CALLED_CUTTER else w.called_stalker))


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
		if not session.is_authority():
			return
		shift.abandon()
		_flush_logs()
	super()
	if _shift_ready:
		_reset_crew()
		_start_shift()


## Everybody but the local player, back to a new life. `stalker_deck` did the local one.
func _reset_crew() -> void:
	for p: Session.SessionPlayer in session.players:
		if _is_local(p):
			continue
		if p.run_log.time_alive_s > 0.0:
			p.run_log.write("respawn")
		p.run_log.begin()
		p.suit.reset()
		p.operator.release_control()
		p.operator.crouch_shown = 1.0
		p.brace_left = 0.0
		p.noise_left = 0.0
		p.leave_held = false
		p.sight.refresh_occluders()
		p.sight.forget()
		update_player_sight(p, 0.0, true)
	session.local().leave_held = false


func _start_shift() -> void:
	session.reseed(next_seed)
	next_seed = 0
	section.rng.seed = rng.randi()
	section.reset()
	shift.begin()
	field.reset(rng)
	marker.hide_now()
	_siren.stop()
	_spawns_owed = 0
	_spawn_wait = 0.0
	_alarm_refresh = 0.0
	_bill_wait = -1.0
	_threat_wait = 0.0
	custodian.reset()
	for p: Session.SessionPlayer in session.players:
		p.operator.set_carry(shift.carry(p.id).penalties())
		_seed_player(p)
	for i in pack.stalkers.size():
		pack.stalkers[i].brain.rng.seed = session.seed_for("stalker:%d" % i)
	_sync_hud()


## This shift's rounds, from the session's seed.
func _seed_player(p: Session.SessionPlayer) -> void:
	p.operator.rifle.state.rng.seed = session.seed_for("rifle:%d" % p.id)


## The shift first, then the deck under it. After LEAVE the deck stops: nobody's left on it.
func simulate_world(delta: float) -> void:
	if not _shift_ready:
		return
	if not session.is_authority():
		_show_carried()
		_sync_hud()
		return
	_step_shift(delta)
	if shift.outcome != ShiftState.EXTRACTED:
		_step_crew(delta)
		super(delta)
	_show_carried()
	_sync_hud()
	if _bill_wait >= 0.0:
		_bill_wait -= delta
		if _bill_wait < 0.0:
			file_death_bill()


## The forms stop the ship: nothing runs behind one.
func _physics_process(delta: float) -> void:
	if _shift_ready and paper.is_open():
		return
	super(delta)


func _step_shift(delta: float) -> void:
	if not session.is_authority():
		return
	section.tick(delta)
	marker.tick(delta, _alarm_at())
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
	_note_threats(delta)
	_step_spawns(delta)
	custodian.tick(delta, _custodian_players())
	if shift.alarm_left > 0.0:
		_alarm_refresh -= delta
		if _alarm_refresh <= 0.0:
			_alarm_refresh = float(_cfg.alarm.refresh_s)
			if shift.alive(_alarm_holder().id):
				pack.alert(_alarm_at())
	for p: Session.SessionPlayer in session.players:
		for ev: Dictionary in shift.carry(p.id).step(delta):
			_on_carry_event(ev, p)
		var inside := airlock.has_point(player_pos(p))
		shift.set_aboard(p.id, inside)
		if inside and shift.alive(p.id):
			_deposit(p)
	for p: Session.SessionPlayer in session.players:
		_send_leave_input(p)
		if shift.step_leave(p.id, delta, airlock.has_point(player_pos(p)), p.leave_held):
			_leave()
			return
	for p: Session.SessionPlayer in session.players:
		var loss := shift.suit_loss(delta, p.id)
		if loss > 0.0 and shift.alive(p.id):
			hurt_player(p.id, "oxygen", loss * float(_health_cfg.suit.max), String(_cfg.out_of_air.who), false)


## Who the ship can see, by player ID.
func _custodian_players() -> Array:
	var out: Array = []
	for p: Session.SessionPlayer in session.players:
		var at := player_pos(p)
		out.append({"id": p.id, "pos": at, "body": Vector3(at.x, _height_of(p), at.y), "alive": not p.suit.dead})
	return out


## Holding E is read fresh each step, so it stays in step with the airlock.
func _send_leave_input(p: Session.SessionPlayer) -> void:
	if p.operator.remote:
		return
	var held: bool = p.operator.scripted.get("leave", false)
	if p.operator.input_enabled:
		held = Input.is_physical_key_pressed(KEY_E)
	session.send(Commands.leave(p.id, held))


func _deposit(p: Session.SessionPlayer) -> void:
	var items := shift.deposit(p.id)
	if items.is_empty():
		return
	for item: RefCounted in items:
		field.put_away(item)
	p.operator.set_carry(shift.carry(p.id).penalties())
	hud.os_state.announce(String(_cfg.words.deposit) % items.size())


## LEAVE: over for everyone. The crew in the airlock go home; the rest are left behind.
func _leave() -> void:
	for id: int in shift.survivors:
		session.player(id).operator.hold_control(float(_cfg.leave.hold_after_s))
	_siren.stop()
	marker.hide_now()
	var w: Dictionary = _cfg.words
	_flush_logs()
	for p: Session.SessionPlayer in session.players:
		if not p.suit.dead:
			p.run_log.write("left" if shift.survivors.has(p.id) else "left_behind")
	if session_live:
		_file_payslip(run_log.to_dict("death" if suit.dead else "left"), QuotaState.LEFT)
		return
	hud.banner = [String(w.closed), String(w.hold_line) % hud.os_state.hold_text(session.hold().estimate()), String(w.next)]


func _on_tier(index: int, spec: Dictionary) -> void:
	_spawns_owed += int(spec.get("stalkers", 0))
	_spawn_wait = 0.0
	if int(spec.get("stalkers", 0)) > 0:
		run_log.note_threat("vents", "ship")
	var line := String(spec.announce)
	if spec.has("lights"):
		var options: Array = spec.lights
		var space := String(options[rng.randi_range(0, options.size() - 1)])
		section.fail(space)
		run_log.note_threat("power_loss", space)
		line = line.replace("%s", String(_cfg.section_words[space]))
	hud.os_state.announce(line)
	_chirp.play()
	for name_key: String in spec.get("wake", []):
		if wake_hooks.has(name_key):
			(wake_hooks[name_key] as Callable).call(index)
	tier_fired.emit(index, spec)


## New stalkers come in where nobody can see. If that's nowhere right now, it asks again shortly.
func _step_spawns(delta: float) -> void:
	if _spawns_owed <= 0 or not session.is_authority():
		return
	_spawn_wait -= delta
	if _spawn_wait > 0.0:
		return
	if pack.spawn_out_of_view(_viewers(), _player_points(), rng) != null:
		_spawns_owed -= 1
	else:
		_spawn_wait = float(pack._spawn_cfg.retry_s)


## One sight check per living player, and where they stand: nothing spawns where anyone can see it.
func _viewers() -> Array:
	var out: Array = []
	for p: Session.SessionPlayer in session.players:
		if not p.suit.dead:
			out.append(_sees_from.bind(p))
	return out


func _player_points() -> Array:
	var out: Array = []
	for p: Session.SessionPlayer in session.players:
		if not p.suit.dead:
			out.append(player_pos(p))
	return out


## Could the local player see something standing at `p`?
func _player_sees(p: Vector2) -> bool:
	return _sees_from(p, session.local())


## Could this player? The same five points a SightTarget is judged by.
func _sees_from(p: Vector2, who: Session.SessionPlayer) -> bool:
	var r := float(sight.cfg.target_radius_m)
	var v: RefCounted = who.sight.visibility
	var yaw: float = who.operator.gun_yaw()
	var lit := _lit(who)
	var eye := player_pos(who)
	for at: Vector2 in [p, p + Vector2(r, 0), p + Vector2(-r, 0), p + Vector2(0, r), p + Vector2(0, -r)]:
		if v.can_see(eye, yaw, lit, at):
			return true
	return false


## Whose lift or drop this was; no one named is the local player.
func _on_carry_event(ev: Dictionary, who: Session.SessionPlayer = null) -> void:
	var p: Session.SessionPlayer = who if who != null else session.local()
	var item: RefCounted = ev.item
	var at := player_pos(p)
	if String(ev.type) == CarryState.EV_TAKEN:
		shift.note_taken(item)
		field.put_away(item)
		if item.prize:
			_trip_alarm(p.id)
	else:
		field.lay_down(item, at)
		var noise := String(ev.noise)
		if noise != "":
			pack.noise(noise, at)
			if _is_local(p):
				noise_ring.state.fire(noise)
			var sounds: Dictionary = _cfg.drop_sound
			if sounds.has(noise):
				pack.play_sound(String(sounds[noise]), p.operator.global_position)
	p.operator.set_carry(shift.carry(p.id).penalties())


## Who set the alarm off, while they're on the roster.
func _alarm_holder() -> Session.SessionPlayer:
	return session.player(shift.alarm_by) if session.has_player(shift.alarm_by) else session.local()


func _alarm_at() -> Vector2:
	return player_pos(_alarm_holder())


## The big prize came off its mount: every stalker gets the carrier's position, and keeps getting it
## while they show. Anything still behind its panel comes out now.
func _trip_alarm(id := -1) -> void:
	if not session.is_authority() or not shift.trip_alarm(player_id if id < 0 else id):
		return
	var a: Dictionary = _cfg.alarm
	run_log.note_threat("alarm", layout.space_at(_alarm_at()))
	hud.os_state.announce(String(a.announce))
	marker.show_for(float(a.reveal_s))
	_siren.play()
	_alarm_refresh = float(a.refresh_s)
	pack.alert(_alarm_at())
	custodian.wake("prize")
	if not ambush.fired:
		ambush.fired = true
		fire_ambush()


## E, for this machine's player. See `_act_interact`.
func interact() -> void:
	session.send(Commands.interact(player_id))


## G, for this machine's player. See `_act_drop`.
func drop_item() -> void:
	session.send(Commands.drop(player_id))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_G:
		drop_item()
		get_viewport().set_input_as_handled()
		return
	if session_live and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		if _bill_wait >= 0.0:
			file_death_bill()
		else:
			abandon_shift()
		get_viewport().set_input_as_handled()
		return
	super(event)


## Every hit goes on file under where it found you, for later briefings.
func _hurt(source: String, amount: float, who: String, in_cover: bool) -> void:
	if not session.is_authority():
		return
	run_log.note_threat(source, layout.space_at(_eye()))
	super(source, amount, who, in_cover)


## You're down: what you carried falls around you, and the shift's log gets written by the deck under
## this, or waits for how the shift ends if the crew's still going.
func _die(who: String, how: String) -> void:
	run_log.note_death_location(layout.space_at(_eye()))
	_drop_body(session.local())
	run_log.hold_back = not shift.ended()
	super(who, how)
	_after_death(session.local())


func _killer_kind(how: String) -> String:
	if how == String(_custodian_cfg.cutter.source):
		return String(_custodian_cfg.cutter.killer_key)
	return "suit" if how == "oxygen" else super(how)


## What's in anyone's hands is shown in their hands.
func _show_carried() -> void:
	for p: Session.SessionPlayer in session.players:
		var item: RefCounted = shift.carry(p.id).in_hand
		if item != null:
			field.hold_up(item, Transform3D(Basis(Vector3.UP, p.operator.model.torso_yaw), p.operator.global_position))


func _sync_hud() -> void:
	var c: CarryState = shift.carry(player_id)
	hud.os_state.set_oxygen(shift.oxygen_of(player_id), float(_cfg.oxygen_s))
	hud.hold_estimate = session.hold().estimate()
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
	if shift.oxygen_of(player_id) <= 0.0 and not shift.ended():
		urgent.append("o2_out")
	if not shift.ended() and custodian.cutter_on(player_id):
		urgent.append("cutter")
	if not shift.ended() and custodian.drone_on(player_id):
		urgent.append("drone_call")
	hud.urgent_alerts = urgent
	hud.action = _action_now(c)
	hud.quota = quota.facts() if session_live or (_capture and _demo_t >= 0.0) else {}


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
	for p: Session.SessionPlayer in session.players:
		if not _is_local(p):
			if not p.suit.dead:
				doors.actors.append({"position": player_pos(p), "radius": p.operator.body_radius()})
			update_player_sight(p, delta, false)


func _update_prompt() -> void:
	var c: Dictionary = _cfg.prompt
	_prompt.visible = false
	if shift.ended() or suit.dead:
		return
	var carry: CarryState = shift.carry(player_id)
	if airlock.has_point(_eye()):
		if shift.leave_share(player_id) <= 0.0:
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


# --- the session: quota, briefing, payslip, death bill, notice ---

## A full reset, then the first briefing.
func start_session() -> void:
	session_live = true
	quota.begin()
	past_logs = []
	_contracts = 0
	paperwork.book.forget()
	paperwork.reseed(rng.randi() if next_seed == 0 else next_seed)
	_brief()


## A fresh ship, rolled now so the estimate is about this ship, frozen behind the form until it's signed.
func _brief() -> void:
	respawn()
	_contracts += 1
	var total := 0
	for item: RefCounted in field.items:
		total += int(item.value)
	contract = paperwork.contract(_contracts, total, past_logs, quota.facts())
	_open_form("briefing", contract)


func _open_form(screen: String, doc: Dictionary) -> void:
	for p: Session.SessionPlayer in session.players:
		p.operator.process_mode = Node.PROCESS_MODE_DISABLED
	paper.open(screen, doc)


func _close_form() -> void:
	paper.close()
	for p: Session.SessionPlayer in session.players:
		p.operator.process_mode = Node.PROCESS_MODE_INHERIT


func _on_paper_pressed(button: String) -> void:
	match button:
		"accept":
			_close_form()
		"decline":
			contract["confirming"] = true
			contract["decline_line"] = paperwork.decline_line()
			paper.update(contract)
		"confirm_decline":
			session.close_quota(0, QuotaState.DECLINED)
			_after_form()
		"acknowledge":
			if paper.screen_name == "termination":
				start_session()
			else:
				_after_form()


## What the last close decided: the notice on a miss, else the next briefing.
func _after_form() -> void:
	if quota.verdict == QuotaState.MISSED:
		_open_form("termination", paperwork.termination(contract, quota.facts()))
	else:
		_brief()


func _file_payslip(log: Dictionary, how: String) -> void:
	past_logs.append(log)
	var doc := paperwork.payslip(log, contract)
	session.close_quota(int(doc.net_cr), how)
	doc.merge(paperwork.quota_fields(quota.facts()), true)
	_open_form("payslip", doc)


## The death screen has had its moment; the bill comes after, as the release.
func file_death_bill() -> void:
	_bill_wait = -1.0
	var log := run_log.to_dict("death")
	past_logs.append(log)
	session.close_quota(0, QuotaState.DIED)
	_open_form("death_bill", paperwork.death_bill(log, contract, quota.facts()))


## Backspace in a session: the shift's written off and billed, nothing banked, and it counts.
func abandon_shift() -> void:
	if not session_live or paper.is_open() or shift.ended() or not session.is_authority():
		return
	shift.abandon()
	_flush_logs()
	var log := run_log.to_dict("respawn")
	run_log.write("respawn")
	_file_payslip(log, QuotaState.ABANDONED)


## Which threats this life has really met, for later briefings. Sight is checked now and then, and only
## until one's been seen.
func _note_threats(delta: float) -> void:
	if run_log.threats_seen.has("stalker"):
		return
	_threat_wait -= delta
	if _threat_wait > 0.0:
		return
	_threat_wait = float(_cfg.session.threat_check_s)
	for s: Node in pack.stalkers:
		if s.brain.alive() and s.brain.state != s.brain.State.DORMANT and _player_sees(s.floor_position()):
			run_log.note_threat("stalker", layout.space_at(s.floor_position()))
			return


# --- capture hooks (src/debug/capture.gd) ---

const CAPTURE_SEED := 4100


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
		{"name": "t014_quota_hud", "do": "quota_hud"},
		{"name": "t014_briefing", "do": "form", "form": "briefing"},
		{"name": "t014_decline_confirm", "do": "form", "form": "decline"},
		{"name": "t014_payslip_good", "do": "form", "form": "good"},
		{"name": "t014_payslip_bad", "do": "form", "form": "bad"},
		{"name": "t014_payslip_long", "do": "form", "form": "long"},
		{"name": "t014_death_bill", "do": "form", "form": "death"},
		{"name": "t014_termination", "do": "form", "form": "termination"},
		{"name": "t015_lens_dormant", "do": "t015", "shot": "dormant"},
		{"name": "t015_lens_awake", "do": "t015", "shot": "awake"},
		{"name": "t015_cutter_sweep", "do": "t015", "shot": "sweep"},
		{"name": "t015_cutter_warmup", "do": "t015", "shot": "warmup"},
		{"name": "t015_cutter_beam", "do": "t015", "shot": "beam"},
		{"name": "t015_cutter_stopped_by_tall", "do": "t015", "shot": "tall"},
		{"name": "t015_cutter_over_low", "do": "t015", "shot": "low"},
		{"name": "t015_drone_patrol", "do": "t015", "shot": "patrol"},
		{"name": "t015_drone_bars_1", "do": "t015", "shot": "bars", "share": 0.2},
		{"name": "t015_drone_bars_2", "do": "t015", "shot": "bars", "share": 0.5},
		{"name": "t015_drone_bars_3", "do": "t015", "shot": "bars", "share": 0.85},
		{"name": "t015_drone_call_complete", "do": "t015", "shot": "called"},
		{"name": "t015_death_bill", "do": "t015", "shot": "bill"},
		{"name": "t015_payslip", "do": "t015", "shot": "payslip"},
	]


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	_close_form()
	session_live = false
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	ambush.fired = true
	match String(shot.do):
		"quota_hud":
			await _quota_hud_shot()
		"form":
			await _form_shot(String(shot.form))
		"t015":
			await _t015_shot(shot)
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


func _quota_hud_shot() -> void:
	next_seed = CAPTURE_SEED
	start_session()
	paper.press("accept")
	quota.banked = 1840
	quota.shifts_left = 2
	shift.hold.deposit(field.items[0])
	await _stand_at(layout.point_in("junction", [0.5, 0.6]), layout.point_in("junction", [0.5, 0.1]))
	await _sim(0.3)


## The forms, reached through the real flow with the run's numbers set by hand.
func _form_shot(form: String) -> void:
	next_seed = CAPTURE_SEED
	start_session()
	match form:
		"briefing", "decline":
			paper.press("accept")
			run_log.note_threat("stalker", "medbay")
			run_log.note_threat("power_loss", "cargo")
			_shot_home(17, 12, 4, 262.0)
			next_seed = CAPTURE_SEED + 1
			paper.press("acknowledge")
			if form == "decline":
				paper.press("decline")
		"good":
			paper.press("accept")
			_shot_home(19, 14, 5, 312.0)
		"bad":
			paper.press("accept")
			run_log.note_damage("spit", 31.0, false)
			run_log.note_damage("puddle", 12.0, false)
			run_log.note_damage("lunge", 22.0, true)
			_shot_home(2, 61, 2, 455.0)
		"long":
			paper.press("accept")
			run_log.note_damage("spit", 31.0, false)
			run_log.note_damage("puddle", 12.0, false)
			run_log.note_damage("lunge", 22.0, true)
			run_log.note_protected()
			_shot_home(field.items.size(), 44, 9, 455.0)
		"death":
			paper.press("accept")
			var at: Vector2 = layout.space_rect("medbay").get_center()
			operator.global_position = Vector3(at.x, 0, at.y)
			shift.carry(player_id).pockets.append(field.items[0])
			shift.carry(player_id).pockets.append(field.items[1])
			run_log.note_time(263.0)
			run_log.note_damage("puddle", 12.0, false)
			_hurt("spit", 1000.0, String(pack.stalkers[0].label), false)
			file_death_bill()
		"termination":
			quota.shifts_left = 1
			quota.deaths = 1
			quota.declined = 1
			quota.cycle = 2
			quota.cycles_met = 1
			quota.shifts_billed = 5
			quota.quota = 4125
			quota.banked = 1960
			paper.press("accept")
			_shot_home(6, 22, 3, 240.0)
			paper.press("acknowledge")
	await get_tree().process_frame
	await get_tree().process_frame


## A shift brought home with these numbers.
func _shot_home(items: int, shots: int, cycles: int, alive_s: float) -> void:
	for item: RefCounted in field.items.slice(0, items):
		shift.hold.deposit(item)
		field.put_away(item)
	shift.airlock_cycles = cycles
	for i in shots:
		run_log.note_shot(i % 2 == 0)
	run_log.note_time(alive_s)
	shift.step_leave(player_id, float(_cfg.leave.hold_s) + 1.0, true, true)
	_leave()


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
	# Nothing else going on: a hit flash would hide the lights.
	for s: Node in pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(layout.bounds.end.x + 50.0, 0.0, layout.bounds.end.y + 50.0)
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
	# Both tiers count as landed, so the real one doesn't fire on top of this and pick its own section.
	shift.tier_reached = (_cfg.tiers as Array).size()
	shift.oxygen_left = float(_cfg.oxygen_s) * float(_cfg.tiers[-1].at_oxygen)
	hud.os_state.announce(String(_cfg.tiers[-1].announce).replace("%s", String(_cfg.section_words[space])))
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


# --- T015: CUSTODIAN's frames. Nothing else going on, so the tell is what's in shot. ---

func _quiet_stalkers() -> void:
	for s: Node in pack.stalkers:
		s.brain.state = s.brain.State.DORMANT
		s.global_position = Vector3(layout.bounds.end.x + 50.0, 0.0, layout.bounds.end.y + 50.0)
	shift.tier_reached = (_cfg.tiers as Array).size()


func _t015_shot(shot: Dictionary) -> void:
	_quiet_stalkers()
	set_kit_view("known")
	var cutter: Node3D = custodian.cutters[0]
	var drone: Node3D = custodian.drones[1]
	var cargo: Rect2 = layout.space_rect("cargo")
	var mid: Vector2 = cargo.get_center() + Vector2(cargo.size.x * 0.12, 0.0)
	match String(shot.shot):
		"dormant":
			await _stand_at(cutter.floor_position() + Vector2(-1.0, 4.0), cutter.floor_position())
			await _sim(0.2)
		"awake":
			await _stand_at(cutter.floor_position() + Vector2(-1.0, 4.0), cutter.floor_position())
			custodian.wake("tier")
			cutter.brain.state = cutter.brain.State.COOL
			cutter.brain._cool = INF
			await _sim(0.3)
		"sweep":
			await _stand_at(mid, cutter.floor_position())
			custodian.wake("tier")
			cutter.brain._hold = INF
			await _sim(1.2)
		"warmup":
			await _stand_at(mid, cutter.floor_position())
			custodian.wake("tier")
			await _until_warm(cutter, 0.65)
		"beam":
			await _stand_at(mid, cutter.floor_position())
			custodian.wake("tier")
			await _until_burn(cutter)
		"tall", "low":
			await _behind_cover(cutter, String(shot.shot))
			custodian.wake("tier")
			await _sim(0.15)
			var aim: Vector2 = cutter.floor_position().direction_to(_eye())
			cutter.brain.yaw = atan2(-aim.x, -aim.y)
			cutter.brain._offset = angle_difference(cutter.brain.home_yaw, cutter.brain.yaw)
			cutter.brain._sweep_dir = 0.0
			await _sim(0.1 if shot.shot == "tall" else float(cutter.cfg.warmup_s) * 0.6)
		"patrol":
			custodian.wake("tier")
			for c: Node3D in custodian.cutters:
				c.brain.state = c.brain.State.COOL
				c.brain._cool = INF
			drone.brain._reacquire = INF
			await _stand_at(drone.floor_position() + Vector2(0.0, -5.0), drone.floor_position())
			await _sim(0.5)
		"bars", "called":
			custodian.wake("tier")
			for c: Node3D in custodian.cutters:
				if c.brain.awake():
					c.brain.state = c.brain.State.COOL
					c.brain._cool = INF
			var to: Vector2 = Vector2(0.0, -5.0)
			drone.brain.yaw = atan2(-to.x, -to.y)
			await _stand_at(drone.floor_position() + to, drone.floor_position())
			await _sim(0.1)
			var call_s := float(drone.cfg.call_s)
			if shot.shot == "bars":
				await _sim(call_s * float(shot.share) - 0.1)
			else:
				await _sim(call_s + 0.3)
		"bill":
			next_seed = CAPTURE_SEED
			start_session()
			paper.press("accept")
			_stand_quick(mid)
			run_log.note_time(301.0)
			_on_custodian_hit(player_id, String(cutter.cfg.source), float(cutter.cfg.damage), cutter.floor_position(), cutter.label)
			_on_custodian_hit(player_id, String(cutter.cfg.source), 1000.0, cutter.floor_position(), cutter.label)
			file_death_bill()
			await get_tree().process_frame
			await get_tree().process_frame
		"payslip":
			next_seed = CAPTURE_SEED
			start_session()
			paper.press("accept")
			_on_custodian_hit(player_id, String(cutter.cfg.source), float(cutter.cfg.damage), cutter.floor_position(), cutter.label)
			_shot_home(8, 22, 4, 330.0)
			await get_tree().process_frame
			await get_tree().process_frame


func _stand_quick(p: Vector2) -> void:
	operator.global_position = Vector3(p.x, 0.0, p.y)


## Right behind a tall or low piece of cargo cover, as the cutter sees it, crouched.
func _behind_cover(cutter: Node3D, kind: String) -> void:
	var mount: Vector2 = cutter.floor_position()
	for p: Dictionary in layout.props:
		if String(p.space) == "cargo" and String(p.cover) == kind:
			var r: Rect2 = p.rect
			var c := r.get_center()
			if c.distance_to(mount) > float(cutter.cfg.range_m) * 0.75:
				continue
			var spot := c + mount.direction_to(c) * (r.size.length() * 0.5 + operator.body_radius())
			await _crouch_at(spot, mount)
			return


func _until_warm(cutter: Node3D, share: float) -> void:
	while cutter.brain.warm_share() < share:
		await get_tree().process_frame


func _until_burn(cutter: Node3D) -> void:
	while not cutter.brain.burning():
		await get_tree().process_frame
	await _sim(float(cutter.cfg.burn_s) * 0.4)
	suit.reset()
	suit_hud.show_death("")


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
		custodian.wake("tier")
		pack.spawn_out_of_view([_player_sees], [_eye()], rng)
		_spawns_owed = 0
		print("shift_deck: frame-time window with %d stalkers and CUSTODIAN awake" % pack.stalkers.size())
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
