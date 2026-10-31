extends "res://tools/t012_bots.gd"
## T014: T012's greedy and cautious bots through whole sessions on the real deck: briefing, shift, payslip
## or death bill, next, until the quota fires them or they've met `MAX_CYCLES` quotas. Not a test: numbers
## for the handoff.
## Slow, so it splits: run several at once with different [first] seeds, then tools/t014_report.py reads
## their files together.
## usage: godot --headless --path . --fixed-fps 60 -s tools/t014_bots.gd -- [seeds] [out.json] [first] [greedy,cautious]

const MAX_CYCLES := 4
const SEED_BASE := 2000
const SEED_STEP := 100


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 12
	var first := int(args[2]) if args.size() > 2 else 0
	var bots: PackedStringArray = args[3].split(",") if args.size() > 3 else PackedStringArray([GREEDY, CAUTIOUS])
	scene = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.aim_from_mouse = false
	op = scene.operator
	op.input_enabled = false
	scene.set_physics_process(false)
	op.set_physics_process(false)
	scene.run_log.enabled = false
	var all := {}
	for bot: String in bots:
		var rows: Array = []
		for i in range(first, first + seeds):
			rows.append(await _session(bot, SEED_BASE + i * SEED_STEP))
			print("OUT %s seed %d: cycles met %d, fired %s, deaths %d, shifts %d" % [bot, SEED_BASE + i * SEED_STEP, rows[-1].cycles_met, str(rows[-1].fired), rows[-1].deaths, (rows[-1].shifts as Array).size()])
		all[bot] = rows
	if args.size() > 1 and args[1].ends_with(".json"):
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		f.store_string(JSON.stringify(all, "  ") + "\n")
		f.close()
	quit()


func _session(bot: String, seed_value: int) -> Dictionary:
	var shifts: Array = []
	var cycles: Array = []
	var n := 0
	scene.next_seed = seed_value
	scene.start_session()
	while true:
		n += 1
		var quota_was: int = scene.quota.quota
		var row: Dictionary = await _one_shift(bot, seed_value + n)
		shifts.append(row)
		var q: Dictionary = scene.quota.facts()
		if String(q.verdict) != "":
			cycles.append({"quota": int(q.quota_due), "met": String(q.verdict) == "met", "surplus": int(q.surplus), "shortfall": int(q.shortfall), "was": quota_was})
		if String(q.verdict) == "missed":
			scene.paper.press("acknowledge")
			check_notice()
			scene.paper.press("acknowledge")
			return {"seed": seed_value, "cycles_met": q.cycles_met, "fired": true, "deaths": q.deaths, "shifts": shifts, "cycles": cycles}
		if int(q.cycles_met) >= MAX_CYCLES:
			return {"seed": seed_value, "cycles_met": q.cycles_met, "fired": false, "deaths": q.deaths, "shifts": shifts, "cycles": cycles}
		scene.next_seed = seed_value + n + 1
		scene.paper.press("acknowledge")
	return {}


func check_notice() -> void:
	if scene.paper.screen_name != "termination":
		push_error("t014_bots: a miss didn't reach the notice")


func _one_shift(bot: String, seed_value: int) -> Dictionary:
	seed(seed_value)
	var k := 0
	for s: Node in scene.pack.stalkers:
		k += 1
		s.brain.rng.seed = seed_value * 31 + k
	op.rifle.state.rng.seed = seed_value * 7
	_seen = {}
	_skipped = {}
	_stuck_left = STUCK_S
	_last_goal = Vector2.INF
	_nudge_left = 0.0
	_check_at = Vector2.INF
	scene.paper.press("accept")
	var t := 0.0
	var cap := float(scene.shift.cfg.oxygen_s) + 60.0
	while not scene.shift.ended() and t < cap:
		_decide(bot)
		await physics_frame
		scene.simulate_world(DT)
		op.simulate(DT)
		t += DT
	if scene.shift.outcome == "wiped":
		scene.file_death_bill()
	var doc: Dictionary = scene.paper.doc
	var rep: Dictionary = scene.run_log.to_dict("x")
	return {"outcome": rep.shift_outcome, "gross": doc.get("gross_cr", 0), "deductions": doc.get("deductions_total_cr", 0),
		"net": doc.get("net_cr", 0), "death_bill": doc.get("outstanding_cr", 0), "rounds": rep.shots_fired, "cycles": rep.airlock_cycles,
		"time_s": t, "prize": rep.prize_taken, "cause": rep.cause_of_death, "items": rep.deposited_items, "lost": rep.items_lost,
		"lines": (doc.get("deductions", []) as Array).map(func(d: Dictionary) -> Dictionary: return {"id": d.id, "quantity": d.quantity, "amount_cr": d.amount_cr})}
