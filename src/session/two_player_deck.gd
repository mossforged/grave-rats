extends "res://src/shift/shift_deck.gd"
## Debug launch: godot --path . res://scenes/session/two_player_deck.tscn. You, plus a scripted second
## player on the same deck: two operators, two carries, two suits, two sights, one hold. Plain shifts,
## no forms. It proves the structure; it isn't co-op. No network.

const MateBot := preload("res://src/session/mate_bot.gd")
const CAPTURE_SEED_2P := 1800

var mate_id := 0
var bot: MateBot


func _ready() -> void:
	super()
	var c: Dictionary = Data.value("session", "two_player")
	mate_id = int(c.mate_id)
	join_player(mate_id, String(session.cfg.crew), Session.SOURCE_SCRIPTED)
	bot = MateBot.new(c.mate_bot, mate_id, self)


func _opens_on_session() -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	if bot and delta > 0.0 and not _capture:
		bot.step(delta)


func capture_shots() -> Array[Dictionary]:
	return [
		{"name": "two_operators_spawned", "do": "spawned"},
		{"name": "two_operators_carrying", "do": "carrying"},
		{"name": "two_players_mate_down_you_extract", "do": "extract"},
		{"name": "two_players_both_down", "do": "wiped"},
	]


## The shift deck's measuring window, with the mate working the same room. Nobody dies in it.
func _demo_step(delta: float) -> void:
	super(delta)
	session.player(mate_id).suit.reset()
	bot.step(delta)


func apply_shot(shot: Dictionary) -> void:
	_demo_t = -1.0
	Engine.time_scale = 1.0
	if panel:
		panel.visible = false
	sight_debug.visible = false
	next_seed = CAPTURE_SEED_2P
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	ambush.fired = true
	_quiet_stalkers()
	var mate: Session.SessionPlayer = session.player(mate_id)
	var mid: Vector2 = layout.point_in("junction", [0.45, 0.5])
	var ahead := mid + Vector2(0.0, -4.0)
	set_kit_view("known")
	await _stand_at(mid, ahead)
	_put(mate, mid + Vector2(float(session.cfg.spawn_spacing_m), 0.0), ahead)
	match String(shot.do):
		"carrying":
			_hand_over(session.local(), "heavy")
			_hand_over(mate, "medium")
		"extract":
			_hand_over(session.local(), "heavy")
			_hand_over(mate, "medium")
			shift.hold.deposit(field.items[0])
			field.put_away(field.items[0])
			hurt_player(mate_id, "lunge", float(_health_cfg.suit.max), "Stalker", false)
			await _stand_at(airlock.rect.get_center(), mid)
			operator.scripted = {"leave": true}
			await _sim(float(_cfg.leave.hold_s) + 0.2)
			print("two_player_deck: mate down, you extract: outcome %s, banked %d, survivors %s" % [shift.outcome, session.banked(), shift.survivors])
		"wiped":
			shift.hold.deposit(field.items[0])
			field.put_away(field.items[0])
			hurt_player(mate_id, "lunge", float(_health_cfg.suit.max), "Stalker", false)
			hurt_player(player_id, "lunge", float(_health_cfg.suit.max), "Stalker", false)
			print("two_player_deck: both down: outcome %s, banked %d, in the hold %d" % [shift.outcome, session.banked(), session.hold().actual()])
	await _sim(0.3)
	Engine.time_scale = 0.0


func _put(p: Session.SessionPlayer, at: Vector2, look: Vector2) -> void:
	p.operator.global_position = Vector3(at.x, 0.0, at.y)
	p.operator.face_now(Vector3(look.x, _aim_height, look.y))
	update_player_sight(p, 0.0, true)


## Put straight in their hands, without the lift, for the frame.
func _hand_over(p: Session.SessionPlayer, klass: String) -> void:
	for item: RefCounted in field.items:
		if String(item.klass) == klass and not item.prize and item.taken_by == 0:
			item.taken_by = p.id
			shift.carry(p.id).in_hand = item
			shift.note_taken(item)
			p.operator.set_carry(shift.carry(p.id).penalties())
			return
