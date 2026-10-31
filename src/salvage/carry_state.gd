extends RefCounted
## Scene-free: what one player has on them, and the committed lifts and drops. Keyed by player ID.
## An item is reserved the moment the lift starts and arrives when it ends. A drop of no length is
## instant. Events: {type: EV_TAKEN or EV_DROPPED, item, noise}.

const SalvageRules := preload("res://src/salvage/salvage_rules.gd")
const SalvageItem := preload("res://src/salvage/salvage_item.gd")

const EV_TAKEN := "taken"
const EV_DROPPED := "dropped"
const OK := ""
const BUSY := "busy"
const POCKETS_FULL := "pockets_full"
const HANDS_FULL := "hands_full"
const NOTHING := "nothing"

var rules: SalvageRules
var player_id := 0
var pockets: Array = []
var in_hand: SalvageItem = null

var _busy_type := ""
var _busy_item: SalvageItem = null
var _busy_left := 0.0
var _busy_total := 0.0


func _init(salvage_rules: SalvageRules, id: int) -> void:
	rules = salvage_rules
	player_id = id


func busy() -> bool:
	return _busy_type != ""


## What's being done right now: EV_TAKEN, EV_DROPPED or "".
func busy_type() -> String:
	return _busy_type


func busy_share() -> float:
	return 1.0 - _busy_left / _busy_total if busy() and _busy_total > 0.0 else 0.0


## Why this item can't be taken right now, or OK.
func can_take(item: SalvageItem) -> String:
	if busy():
		return BUSY
	if bool(rules.class_of(item).pocketed):
		return POCKETS_FULL if pockets.size() >= int(rules.cfg.pocket_limit) else OK
	return HANDS_FULL if in_hand != null else OK


## Starts the lift. Returns OK or why not. The lift's length is `busy_left()`.
func begin_take(item: SalvageItem) -> String:
	var why := can_take(item)
	if why != OK:
		return why
	item.taken_by = player_id
	_busy_type = EV_TAKEN
	_busy_item = item
	_busy_total = float(rules.class_of(item).pickup_s)
	_busy_left = _busy_total
	return OK


func busy_left() -> float:
	return _busy_left


## Lets go of what's in hand. Returns the events of an instant drop, none for a committed one (it
## ends in `step`) or when there's nothing in hand.
func drop() -> Array:
	if busy() or in_hand == null:
		return []
	var s := float(rules.class_of(in_hand).drop_s)
	if s <= 0.0:
		return [_finish_drop(in_hand)]
	_busy_type = EV_DROPPED
	_busy_item = in_hand
	_busy_total = s
	_busy_left = s
	return []


func step(delta: float) -> Array:
	if not busy():
		return []
	_busy_left -= delta
	if _busy_left > 0.0:
		return []
	var item := _busy_item
	var type := _busy_type
	_busy_type = ""
	_busy_item = null
	_busy_left = 0.0
	if type == EV_DROPPED:
		return [_finish_drop(item)]
	if bool(rules.class_of(item).pocketed):
		pockets.append(item)
	else:
		in_hand = item
	return [{"type": EV_TAKEN, "item": item, "noise": ""}]


func _finish_drop(item: SalvageItem) -> Dictionary:
	in_hand = null
	item.taken_by = 0
	return {"type": EV_DROPPED, "item": item, "noise": String(rules.class_of(item).drop_noise)}


func carried() -> Array:
	var out := pockets.duplicate()
	if in_hand != null:
		out.append(in_hand)
	return out


## Everything leaves you at once: deposited, or you died. Any lift or drop in progress is off; an item
## being lifted stays where it is.
func empty_out() -> Array:
	var out := carried()
	if _busy_type == EV_TAKEN:
		_busy_item.taken_by = 0
	_busy_type = ""
	_busy_item = null
	_busy_left = 0.0
	pockets = []
	in_hand = null
	for item: SalvageItem in out:
		item.taken_by = 0
	return out


func penalties() -> Dictionary:
	return rules.penalties(in_hand)
