extends RefCounted
## A scripted crewmate: lifts what's in its room, carries it to the airlock, then waits there. It plays
## through commands and nothing else, as a human or an AI crew would. data/session.json "mate_bot".

const Commands := preload("res://src/session/commands.gd")

var cfg: Dictionary
var id := 0
## Holding LEAVE once it has nothing left to fetch.
var leave_when_done := false

var _send: Callable
var _deck: Node
var _wait := 0.0


func _init(config: Dictionary, player_id: int, deck: Node) -> void:
	cfg = config
	id = player_id
	_deck = deck
	_send = deck.session.send


## One step: where to go next, and whether to reach for it.
func step(delta: float) -> void:
	var p: RefCounted = _deck.session.player(id)
	if p.suit.dead or _deck.shift.ended():
		_send.call(Commands.move(id, Vector2.ZERO, false, 0.0))
		return
	var me: Vector2 = _deck.player_pos(p)
	var carry: RefCounted = _deck.shift.carry(id)
	if carry.busy():
		return
	var home: Vector2 = _deck.airlock.rect.get_center()
	var goal: Variant = home if _has_load(carry) else _next_item(carry)
	if goal == null:
		_walk(me, home)
		_send.call(Commands.leave(id, leave_when_done and _deck.airlock.has_point(me)))
		return
	_walk(me, goal)
	_wait = maxf(_wait - delta, 0.0)
	var reach := float(_deck.field.rules.cfg.reach_m) * float(cfg.reach_share)
	if not _has_load(carry) and me.distance_to(goal) <= reach and _wait <= 0.0:
		_wait = float(cfg.wait_s)
		_send.call(Commands.take(id))


func _has_load(carry: RefCounted) -> bool:
	return carry.in_hand != null or carry.pockets.size() >= int(carry.rules.cfg.pocket_limit)


func _next_item(carry: RefCounted) -> Variant:
	var room: Rect2 = _deck.layout.space_rect(String(cfg.space))
	var best: Variant = null
	var me: Vector2 = _deck.player_pos(_deck.session.player(id))
	for item: RefCounted in _deck.field.on_floor():
		if room.has_point(item.at) and not item.prize and item.taken_by == 0 and carry.can_take(item) == carry.OK \
				and not _deck.airlock.has_point(item.at) and (best == null or me.distance_to(item.at) < me.distance_to(best)):
			best = item.at
	if best == null and not carry.pockets.is_empty():
		return _deck.airlock.rect.get_center()
	return best


func _walk(me: Vector2, to: Vector2) -> void:
	var there := me.distance_to(to) <= float(cfg.arrive_m)
	# Camera yaw 0: keys are the world's X and Z.
	_send.call(Commands.move(id, Vector2.ZERO if there else me.direction_to(to), false, 0.0))
	if not there:
		var y: float = _deck.session.player(id).operator.aim_point.y
		_send.call(Commands.aim(id, Vector3(to.x, y, to.y)))
