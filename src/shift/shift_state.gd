extends RefCounted
## Scene-free: one shift. The oxygen clock, the tiers, the alarm, who's aboard, the hold, LEAVE and
## what the run log gets. Every rule is keyed by player ID; solo is a crew of one. data/shift.json.
## `step` returns events, as StalkerBrain does: {type: EV_TIER, index, spec}, {type: EV_OXYGEN_OUT},
## {type: EV_ALARM_OVER}.

const Hold := preload("res://src/salvage/hold.gd")
const CarryState := preload("res://src/salvage/carry_state.gd")
const SalvageItem := preload("res://src/salvage/salvage_item.gd")

const EV_TIER := "tier"
const EV_OXYGEN_OUT := "oxygen_out"
const EV_ALARM_OVER := "alarm_over"
const RUNNING := ""
const EXTRACTED := "extracted"
const WIPED := "wiped"
const ABANDONED := "abandoned"

var cfg: Dictionary
var oxygen_left := 0.0
var hold := Hold.new()
var tier_reached := 0
var prize_taken := false
var alarm_left := 0.0
var outcome := RUNNING
var oxygen_at_exit := -1.0
var survivors: Array = []
## Deposits that put something in the hold: what the airlock bills.
var airlock_cycles := 0
## What was on whoever went down: {count, value}.
var carried_at_death := {"count": 0, "value": 0}

var _rules: RefCounted
var _players := {}        # player ID -> {carry, alive, leave_left}
var _touched := {}        # item id -> SalvageItem: everything anyone ever lifted
var _oxygen_out := false


func _init(config: Dictionary, salvage_rules: RefCounted) -> void:
	cfg = config
	_rules = salvage_rules
	begin()


## A new shift. The crew stays on the roster, empty-handed.
func begin() -> void:
	oxygen_left = float(cfg.oxygen_s)
	hold.clear()
	tier_reached = 0
	prize_taken = false
	alarm_left = 0.0
	outcome = RUNNING
	oxygen_at_exit = -1.0
	survivors = []
	airlock_cycles = 0
	carried_at_death = {"count": 0, "value": 0}
	_touched = {}
	_oxygen_out = false
	for id: int in _players.keys():
		add_player(id)


func add_player(id: int) -> void:
	_players[id] = {"carry": CarryState.new(_rules, id), "alive": true, "leave_left": float(cfg.leave.hold_s)}


func carry(id: int) -> CarryState:
	return _players[id].carry


func alive(id: int) -> bool:
	return bool(_players[id].alive)


func ended() -> bool:
	return outcome != RUNNING


func oxygen_fraction() -> float:
	return oxygen_left / float(cfg.oxygen_s)


func oxygen_out() -> bool:
	return oxygen_left <= 0.0


## One step of the clock.
func step(delta: float) -> Array:
	var events: Array = []
	if ended():
		return events
	oxygen_left = maxf(oxygen_left - delta, 0.0)
	var tiers: Array = cfg.tiers
	while tier_reached < tiers.size() and oxygen_fraction() <= float(tiers[tier_reached].at_oxygen):
		tier_reached += 1
		events.append({"type": EV_TIER, "index": tier_reached, "spec": tiers[tier_reached - 1]})
	if oxygen_out() and not _oxygen_out:
		_oxygen_out = true
		events.append({"type": EV_OXYGEN_OUT})
	if alarm_left > 0.0:
		alarm_left = maxf(alarm_left - delta, 0.0)
		if alarm_left == 0.0:
			events.append({"type": EV_ALARM_OVER})
	return events


## The share of a full suit lost this step for lack of air.
func suit_loss(delta: float) -> float:
	return float(cfg.out_of_air.suit_fraction_per_s) * delta if oxygen_out() and not ended() else 0.0


func note_taken(item: SalvageItem) -> void:
	_touched[item.id] = item


## The big prize came off its mount. True the first time: the alarm goes off once a shift.
func trip_alarm(_by_player: int) -> bool:
	if prize_taken:
		return false
	prize_taken = true
	alarm_left = float(cfg.alarm.reveal_s)
	return true


## Everything this player has goes in the hold. Returns what went in.
func deposit(id: int) -> Array:
	var c: CarryState = carry(id)
	# A lift in progress belongs to the deck until it ends.
	if c.busy():
		return []
	var items: Array = c.empty_out()
	for item: SalvageItem in items:
		hold.deposit(item)
	if not items.is_empty():
		airlock_cycles += 1
	return items


## One step of E in the airlock. True on the step LEAVE completes, which ends the shift for whoever's
## in the airlock. Letting go starts it over.
func step_leave(id: int, delta: float, in_airlock: bool, held: bool) -> bool:
	if ended() or not alive(id):
		return false
	var p: Dictionary = _players[id]
	if not (in_airlock and held):
		p.leave_left = float(cfg.leave.hold_s)
		return false
	p.leave_left = float(p.leave_left) - delta
	if float(p.leave_left) > 0.0:
		return false
	survivors = [id]
	_finish(EXTRACTED)
	return true


func leave_share(id: int) -> float:
	return 1.0 - float(_players[id].leave_left) / float(cfg.leave.hold_s)


## They're down: what they carried comes back for the deck to show. Whole crew down ends the shift.
func player_died(id: int) -> Array:
	_players[id].alive = false
	var items: Array = carry(id).empty_out()
	for item: SalvageItem in items:
		carried_at_death.count = int(carried_at_death.count) + 1
		carried_at_death.value = int(carried_at_death.value) + item.value
	for other: int in _players:
		if alive(other):
			return items
	_finish(WIPED)
	return items


## Walked away from: a respawn in mid-shift.
func abandon() -> void:
	if not ended():
		_finish(ABANDONED)


func _finish(how: String) -> void:
	outcome = how
	oxygen_at_exit = oxygen_left
	alarm_left = 0.0


## What counts for the crew: the hold, if anyone got out.
func banked() -> int:
	return hold.actual() if outcome == EXTRACTED else 0


## Lifted, and not in the hold: dropped on the deck, or on a body.
func lost_items() -> Array:
	var in_hold := {}
	for item: SalvageItem in hold.items:
		in_hold[item.id] = true
	return _touched.values().filter(func(item: SalvageItem) -> bool: return not in_hold.has(item.id))


## The run log's fields for this shift.
func report() -> Dictionary:
	var lost := lost_items()
	var lost_value := 0
	for item: SalvageItem in lost:
		lost_value += item.value
	var salvage: Array = []
	for item: SalvageItem in hold.items:
		salvage.append({"kind": item.kind, "word": item.word, "class": item.klass, "value": item.value, "prize": item.prize})
	return {
		"shift_outcome": outcome,
		"oxygen_at_exit_s": oxygen_at_exit if ended() else oxygen_left,
		"deposited_by_class": hold.by_class(),
		"deposited_items": hold.items.size(),
		"deposited_value": hold.actual(),
		"banked_value": banked(),
		"items_lost": lost.size(),
		"items_lost_value": lost_value,
		"prize_taken": prize_taken,
		"tier_reached": tier_reached,
		"survivors": survivors,
		"airlock_cycles": airlock_cycles,
		"salvage": salvage,
		"carried_at_death": int(carried_at_death.count),
		"carried_at_death_value": int(carried_at_death.value),
	}
