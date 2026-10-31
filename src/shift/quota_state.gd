extends RefCounted
## Scene-free: the session around the shifts. A quota due at the end of a cycle of shifts, banked so
## far, surplus carried over, the firing. data/shift.json "quota". Solo now; the crew shares one quota.

const RUNNING := ""
const MET := "met"
const MISSED := "missed"
## How a shift closed, as `close_shift` is told.
const LEFT := "left"
const DIED := "died"
const DECLINED := "declined"
const ABANDONED := "abandoned"

var cfg: Dictionary
var cycle := 1
var quota := 0
var banked := 0
var shifts_left := 0
var shifts_billed := 0
var deaths := 0
var declined := 0
var cycles_met := 0
## What the last shift's close decided, and its numbers.
var verdict := RUNNING
var surplus := 0
var shortfall := 0
var quota_due := 0


func _init(config: Dictionary) -> void:
	cfg = config
	begin()


## A full reset: back to the first quota, nothing banked.
func begin() -> void:
	cycle = 1
	quota = int(cfg.start_cr)
	banked = 0
	shifts_left = int(cfg.shifts_per_cycle)
	shifts_billed = 0
	deaths = 0
	declined = 0
	cycles_met = 0
	verdict = RUNNING
	surplus = 0
	shortfall = 0
	quota_due = quota


## One shift off the clock, whatever became of it. `net_cr` goes on the quota, and can take it down.
## Returns RUNNING, MET or MISSED; a miss holds the numbers for the notice until `begin`.
func close_shift(net_cr: int, how: String) -> String:
	banked += net_cr
	shifts_left -= 1
	shifts_billed += 1
	match how:
		DIED:
			deaths += 1
		DECLINED:
			declined += 1
	verdict = RUNNING
	if shifts_left > 0:
		return verdict
	quota_due = quota
	if banked >= quota:
		verdict = MET
		surplus = banked - quota
		shortfall = 0
		cycles_met += 1
		cycle += 1
		quota = snappedi(float(quota) * float(cfg.growth), int(cfg.round_to))
		banked = surplus
		shifts_left = int(cfg.shifts_per_cycle)
	else:
		verdict = MISSED
		surplus = 0
		shortfall = quota - banked
	return verdict


## How much of the quota is banked, for a bar.
func share() -> float:
	return clampf(float(banked) / float(quota), 0.0, 1.0)


## The numbers the paperwork and the HUD read.
func facts() -> Dictionary:
	return {
		"cycle": cycle, "quota": quota, "banked": banked, "shifts_left": shifts_left,
		"shifts_per_cycle": int(cfg.shifts_per_cycle), "shifts_billed": shifts_billed, "deaths": deaths,
		"declined": declined, "cycles_met": cycles_met, "verdict": verdict, "surplus": surplus,
		"shortfall": shortfall, "quota_due": quota_due, "share": share(),
	}
