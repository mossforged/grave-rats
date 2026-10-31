extends "res://tests/test_case.gd"
## T014: the quota over three shifts, and the company paperwork filled from the run log. Scene-free
## first, then the session on the real deck. All numbers come from data, as the tests read them.

const QuotaState := preload("res://src/shift/quota_state.gd")
const Paperwork := preload("res://src/paperwork/paperwork.gd")
const LineBook := preload("res://src/paperwork/line_book.gd")
const RunLog := preload("res://src/run_log/run_log.gd")
const SCRIPTS := ["res://src/paperwork/paperwork.gd", "res://src/paperwork/line_book.gd", "res://src/paperwork/paperwork_screen.gd", "res://src/shift/quota_state.gd"]
const DT := 1.0 / 60.0
const TEST_DIR := "user://test_runs_paperwork"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Data.clear_cache()
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _cfg() -> Dictionary:
	return (Data.load_data("paperwork") as Dictionary).duplicate(true)


func _quota_cfg() -> Dictionary:
	return (Data.value("shift", "quota") as Dictionary).duplicate(true)


func _paper(cfg := {}) -> Paperwork:
	var p := Paperwork.new(_cfg() if cfg.is_empty() else cfg)
	p.reseed(11)
	return p


func _contract(p: Paperwork, logs := []) -> Dictionary:
	return p.contract(1, 5000, logs, QuotaState.new(_quota_cfg()).facts())


## A log as a shift that went home writes it: nothing happened but the time.
func _log(fields := {}) -> Dictionary:
	var rl := RunLog.new(TEST_DIR)
	var out := rl.to_dict("left")
	out.merge({"time_alive_s": 61.0, "shift_outcome": "extracted", "airlock_cycles": 0, "salvage": [], "carried_at_death_value": 0}, true)
	out.merge(fields, true)
	return out


func _ids(doc: Dictionary) -> Array:
	return doc.deductions.map(func(d: Dictionary) -> String: return d.id)


func _tariff(cfg: Dictionary, id: String) -> Dictionary:
	for line: Dictionary in cfg.tariff:
		if line.id == id:
			return line
	return {}


# --- quota ---

func test_meeting_the_quota_carries_the_surplus_and_raises_it() -> void:
	var c := _quota_cfg()
	var q := QuotaState.new(c)
	var start := int(c.start_cr)
	var over := int(c.round_to) * 7
	check_eq(q.shifts_left, int(c.shifts_per_cycle), "a cycle's shifts")
	check_eq(q.close_shift(start, QuotaState.LEFT), QuotaState.RUNNING, "not due after one")
	check_eq(q.close_shift(0, QuotaState.DIED), QuotaState.RUNNING, "not due after two")
	check_eq(q.banked, start, "banked so far")
	check_eq(q.close_shift(over, QuotaState.LEFT), QuotaState.MET, "due and met")
	check_eq(q.surplus, over, "surplus")
	check_eq(q.banked, over, "the surplus carries over")
	check_eq(q.quota, snappedi(float(start) * float(c.growth), int(c.round_to)), "next quota from data's growth")
	check_eq(q.shifts_left, int(c.shifts_per_cycle), "a new cycle")
	check_eq(q.cycle, 2, "cycle two")
	check_eq(q.cycles_met, 1, "one met")


func test_exactly_the_quota_is_met() -> void:
	var c := _quota_cfg()
	c.shifts_per_cycle = 1
	var q := QuotaState.new(c)
	check_eq(q.close_shift(int(c.start_cr), QuotaState.LEFT), QuotaState.MET, "exact")
	check_eq(q.surplus, 0, "nothing over")


func test_growth_and_length_come_from_data() -> void:
	var c := _quota_cfg()
	c.shifts_per_cycle = 2
	c.growth = 2.0
	c.start_cr = 1000
	c.round_to = 1
	var q := QuotaState.new(c)
	q.close_shift(600, QuotaState.LEFT)
	check_eq(q.close_shift(600, QuotaState.LEFT), QuotaState.MET, "two shifts")
	check_eq(q.quota, 2000, "doubled")
	check_eq(q.banked, 200, "over")


func test_a_miss_says_by_how_much_and_begin_is_a_full_reset() -> void:
	var c := _quota_cfg()
	var q := QuotaState.new(c)
	q.close_shift(100, QuotaState.LEFT)
	q.close_shift(0, QuotaState.DECLINED)
	check_eq(q.close_shift(-40, QuotaState.ABANDONED), QuotaState.MISSED, "missed")
	check_eq(q.shortfall, int(c.start_cr) - 60, "shortfall, the balance due taken off")
	check_eq(q.quota_due, int(c.start_cr), "what was due")
	check_eq(q.declined, 1, "declined counted")
	q.begin()
	check_eq(q.quota, int(c.start_cr), "first quota again")
	check_eq(q.banked, 0, "nothing banked")
	check_eq(q.cycle, 1, "first cycle")
	check_eq(q.verdict, QuotaState.RUNNING, "verdict cleared")
	check_eq(q.shifts_billed, 0, "record cleared")


# --- the briefing ---

func test_estimate_stays_within_the_spread_of_the_truth() -> void:
	var cfg := _cfg()
	var spread := float(cfg.contract.estimate_spread)
	var p := _paper(cfg)
	for total: int in [123, 1000, 5317, 7450, 9999]:
		for i in 200:
			var e := p.estimate(total)
			check(float(e) >= float(total) * (1.0 - spread) and float(e) <= float(total) * (1.0 + spread), "%d within the spread of %d" % [e, total])
	var doc := _contract(p)
	check_eq(doc.true_value_cr, 5000, "truth kept beside it")
	check_eq(doc.estimate, p.cr(int(doc.estimated_value_cr)), "printed as computed")


func test_hazards_come_only_from_past_logs() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var empty := _contract(p)
	check((empty.known_hazards as Array).is_empty(), "first shift knows nothing")
	check_eq(empty.hazards[0].text, String(cfg.words.no_hazards), "and says so")
	check_eq((empty.hazards as Array).size(), 1, "one row")
	var doc := _contract(p, [_log({"threats_seen": {"stalker": "medbay", "power_loss": "cargo"}}), _log({"threats_seen": {"stalker": "cargo"}})])
	var kinds: Array = doc.known_hazards.map(func(h: Dictionary) -> String: return h.kind)
	kinds.sort()
	check_eq(kinds, ["power_loss", "stalker"], "exactly what the logs met")
	for h: Dictionary in doc.known_hazards:
		if h.kind == "stalker":
			check_eq(h.location, String(cfg.space_words.cargo), "the newest place")
	check_eq(doc.hazards[-1].text, String(cfg.words.hazard_rest), "the rest stays unverified")
	# A threat nobody met can't print, whatever data knows about it.
	var rival: Dictionary = cfg.hazards.filter(func(h: Dictionary) -> bool: return h.kind == "rifle")[0]
	for row: Dictionary in doc.hazards:
		check(not String(row.text).contains(String(rival.text)), "no rival crew on a log with none")


func test_too_many_hazards_keep_to_the_rows_on_the_form() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var threats := {}
	for h: Dictionary in cfg.hazards:
		threats[h.kind] = "cargo"
	var doc := _contract(p, [_log({"threats_seen": threats})])
	check_eq((doc.known_hazards as Array).size(), (cfg.hazards as Array).size(), "all on file")
	check_eq((doc.hazards as Array).size(), int(cfg.contract.hazard_rows) + 1, "the rows, and the rest unverified")


func test_vessel_names_and_decline_lines_dont_repeat_back_to_back() -> void:
	var p := _paper()
	var last := ""
	var last_line := ""
	for i in 40:
		var doc := _contract(p)
		check(doc.vessel != last, "vessel repeats: %s" % doc.vessel)
		last = doc.vessel
		var line := p.decline_line()
		check(line != last_line, "decline line repeats: %s" % line)
		last_line = line


# --- the payslip ---

func test_a_clean_shift_pays_only_for_what_it_did() -> void:
	var p := _paper()
	var doc := p.payslip(_log(), _contract(p))
	check_eq(_ids(doc), ["suit_rental", "oxygen", "morale"], "time aboard's charges only")


## Each line of the tariff, with its cause in the log and without.
func test_each_deduction_appears_only_with_its_cause() -> void:
	var cases := {
		"ammunition": {"shots_fired": 9},
		"airlock_cycling": {"airlock_cycles": 2},
		"ballistic_shelter": {"shots_blocked_for_you": 3},
		"corrosive_interception": {"times_protected": 1},
		"cover_occupancy": {"time_locked_s": 30.0},
		"covered_review": {"hits_in_cover": 2},
		"corrosive_contact": {"damage_by_source": {"spit": 12.5}},
		"floor_residue": {"damage_by_source": {"puddle": 3.0}},
		"impact_seal": {"damage_by_source": {"lunge": 20.0}},
		"ballistic_seal": {"damage_by_source": {"rifle": 8.0}},
		"custodian_charge": {"custodian_hits": 1},
		"replacement_shift": {"ended": "respawn"},
	}
	var cfg := _cfg()
	var p := _paper(cfg)
	var c := _contract(p)
	var plain := _ids(p.payslip(_log(), c))
	var always := ["suit_rental", "oxygen", "morale"]
	for line: Dictionary in cfg.tariff:
		if bool(line.enabled) and not always.has(line.id):
			check(cases.has(line.id), "a case covers %s" % line.id)
	for id: String in cases:
		check(not plain.has(id), "%s not on a clean shift" % id)
		var with_cause := _ids(p.payslip(_log(cases[id]), c))
		check(with_cause.has(id), "%s appears with its cause" % id)
		check_eq(with_cause.size(), plain.size() + 1, "%s adds only itself" % id)
	var none := _ids(p.payslip(_log({"time_alive_s": 0.0}), c))
	check(none.is_empty(), "no time aboard, nothing charged: %s" % str(none))


func test_lines_left_out_of_the_tariff_never_print() -> void:
	var p := _paper()
	var ids := _ids(p.payslip(_log({"shots_fired": 9, "shots_hit": 3, "hits_in_open": 2, "your_shots_blocked": 1, "ended": "quit", "salvage": [{"kind": "fuse", "word": "FUSE", "value": 40}]}), _contract(p)))
	for off: String in ["missed_rounds", "impact_reconciliation", "obstruction", "open_review", "early_closure", "salvage_handling"]:
		check(not ids.has(off), "%s stays off" % off)


func test_the_arithmetic_adds_up() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var log := _log({"time_alive_s": 301.0, "shots_fired": 14, "airlock_cycles": 5, "damage_by_source": {"spit": 12.2, "puddle": 0.0, "lunge": 0.0, "rifle": 0.0},
		"salvage": [{"kind": "relay", "word": "RELAY ASSEMBLY", "value": 201}, {"kind": "fuse", "word": "FUSE", "value": 41}, {"kind": "fuse", "word": "FUSE", "value": 77}]})
	var doc := p.payslip(log, _contract(p))
	check_eq(doc.gross_cr, 319, "gross")
	var fuse: Dictionary = doc.credits.filter(func(r: Dictionary) -> bool: return r.kind == "fuse")[0]
	check_eq(fuse.quantity, 2, "grouped")
	check_eq(fuse.amount_cr, 118, "each at its own value")
	var total := 0
	for d: Dictionary in doc.deductions:
		check_eq(d.amount_cr, int(d.quantity) * int(d.rate_cr), "%s is quantity times rate" % d.id)
		total += int(d.amount_cr)
	check_eq(doc.deductions_total_cr, total, "total deductions")
	check_eq(doc.net_cr, 319 - total, "net")
	var by_id := {}
	for d: Dictionary in doc.deductions:
		by_id[d.id] = d
	check_eq(by_id.oxygen.quantity, 6, "oxygen billed per started minute")
	check_eq(by_id.ammunition.quantity, 14, "every round")
	check_eq(by_id.airlock_cycling.quantity, 5, "every deposit")
	check_eq(by_id.corrosive_contact.quantity, 13, "damage rounded up")


func test_rates_come_from_data() -> void:
	var cfg := _cfg()
	_tariff(cfg, "ammunition").rate = 7
	var p := _paper(cfg)
	var doc := p.payslip(_log({"shots_fired": 3}), _contract(p))
	var ammo: Dictionary = doc.deductions.filter(func(d: Dictionary) -> bool: return d.id == "ammunition")[0]
	check_eq(ammo.amount_cr, 21, "the rate followed")


func test_negative_net_shows_as_a_balance_due() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var doc := p.payslip(_log({"shift_outcome": "extracted"}), _contract(p))
	check(int(doc.net_cr) < 0, "nothing recovered, charges anyway: %d" % int(doc.net_cr))
	check(bool(doc.balance_due), "flagged")
	check_eq(doc.net_label, String(cfg.words.net_negative), "NET PAY / BALANCE DUE")
	check(String(doc.net).begins_with(String(cfg.format.minus)), "a plain minus, no clamp")
	var rich := p.payslip(_log({"salvage": [{"kind": "black_box", "word": "BLACK BOX", "value": 1600}]}), _contract(p))
	check(int(rich.net_cr) > 0, "and in profit")
	check(not bool(rich.balance_due), "no balance due")
	check_eq(rich.net_label, String(cfg.words.net_positive), "NET PAY")


func test_nothing_credited_unless_the_shift_came_home() -> void:
	var p := _paper()
	var doc := p.payslip(_log({"shift_outcome": "abandoned", "ended": "respawn", "salvage": [{"kind": "fuse", "word": "FUSE", "value": 60}]}), _contract(p))
	check_eq(doc.gross_cr, 0, "the hold's forfeit")
	check(_ids(doc).has("replacement_shift"), "and billed")


func test_payslip_notes_only_quote_charged_lines_and_dont_repeat() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var c := _contract(p)
	var last := ""
	for i in 30:
		var doc := p.payslip(_log({"shots_fired": 5}), c)
		var notes: Array = doc.deductions.map(func(d: Dictionary) -> String: return d.note)
		check(notes.has(doc.note), "%s is a charged line's" % doc.note)
		check(doc.note != last, "note repeats: %s" % doc.note)
		last = doc.note


# --- the death bill ---

func test_the_cause_matches_the_log() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var c := _contract(p)
	for how: String in ["spit", "puddle", "lunge", "rifle", "oxygen"]:
		var kind := "pirate" if how == "rifle" else ("suit" if how == "oxygen" else "stalker")
		var doc := p.death_bill(_log({"ended": "death", "killed_by": {kind: "the one", "how": how}, "death_location": "cargo"}), c, QuotaState.new(_quota_cfg()).facts())
		check_eq(doc.method, how, "method verbatim")
		check_eq(doc.cause_id, how, "cause by method")
		check_eq(doc.killer, "the one", "killer as recorded")
		check_eq(doc.location, String(cfg.space_words.cargo), "where")
		check(bool(doc.location_recorded), "recorded")


func test_no_cause_is_invented() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var c := _contract(p)
	var facts := QuotaState.new(_quota_cfg()).facts()
	var none := p.death_bill(_log({"ended": "death", "killed_by": null}), c, facts)
	check_eq(none.cause_id, "cause_unavailable", "no killer on file")
	check_eq(none.killer, String(cfg.words.not_recorded), "not recorded")
	check_eq(none.location, String(cfg.words.not_recorded), "no location on file")
	check(not bool(none.location_recorded), "and flagged")
	check_eq(none.party_line, "", "nobody named")
	check_eq(none.context_line, "", "nothing on file")
	var odd := p.death_bill(_log({"ended": "death", "killed_by": {"stalker": "x", "how": "falling piano"}}), c, facts)
	check_eq(odd.cause_id, "unclassified", "an unknown method isn't guessed at")
	check_eq(odd.method, "falling piano", "shown as recorded")


func test_context_lines_need_their_facts_and_rest() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var c := _contract(p)
	var facts := QuotaState.new(_quota_cfg()).facts()
	var log := _log({"ended": "death", "killed_by": {"stalker": "x", "how": "spit"}, "hits_in_cover": 1, "hits_in_open": 1})
	var first := p.death_bill(log, c, facts)
	var second := p.death_bill(log, c, facts)
	var lines: Array = cfg.causes.context.map(func(l: Dictionary) -> String: return l.line)
	check(lines.has(first.context_line), "from the library")
	check(first.context_line != second.context_line, "doesn't repeat back to back")
	var party := p.death_bill(log, c, facts)
	check_eq(party.party_line, String(cfg.causes.party[0].line), "a stalker, so the stalker line")


func test_the_bill_adds_up_and_bills_what_you_carried() -> void:
	var cfg := _cfg()
	var d: Dictionary = cfg.death
	var p := _paper(cfg)
	var facts := QuotaState.new(_quota_cfg()).facts()
	var c := _contract(p)
	var empty := p.death_bill(_log({"ended": "death"}), c, facts)
	check_eq(empty.outstanding_cr, int(d.processing_cr) + int(d.suit_cr) + int(d.cleanup_cr), "processing, the suit, cleanup")
	check_eq((empty.lines as Array).size(), 3, "three rows with empty pockets")
	var full := p.death_bill(_log({"ended": "death", "carried_at_death_value": 333}), c, facts)
	check_eq(full.outstanding_cr, int(empty.outstanding_cr) + 333, "plus what you carried")
	check_eq((full.lines as Array).size(), 4, "on its own row")
	check_eq(full.next_of_kin, String(cfg.contract.next_of_kin), "to next of kin")


# --- the notice ---

func test_the_notice_shows_the_shortfall_and_final_deductions() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var q := QuotaState.new(_quota_cfg())
	q.close_shift(100, QuotaState.LEFT)
	q.close_shift(0, QuotaState.DIED)
	q.close_shift(0, QuotaState.DECLINED)
	var doc := p.termination(_contract(p), q.facts())
	check_eq(doc.shortfall_cr, int(_quota_cfg().start_cr) - 100, "shortfall")
	var total := 0
	for line: Dictionary in cfg.termination.deductions:
		total += int(line.rate)
	check_eq(doc.deductions_total_cr, total, "final deductions from data")
	check_eq(doc.final_balance_cr, 100 - total, "final balance")
	check(doc.line_one != doc.line_two, "two different lines")
	var kin := ""
	for line: Dictionary in cfg.termination.lines:
		if line.id == "debt":
			kin = line.text
	check(doc.line_one != kin and doc.line_two != kin, "no debt line with money banked")


func test_every_screen_has_the_approved_lines_in_data() -> void:
	var text := FileAccess.get_file_as_string("res://data/paperwork.json")
	for line: String in ["Recovery does not include rescue.", "Thank you for choosing independent recovery.", "probably abandoned", "Liability survives the contractor.", "Cover was present. Coverage was not.", "Evidence unavailable. Balance available."]:
		check(text.contains(line), "data has: %s" % line)


## Copy lives in data: the scripts have no sentences, and every printed field a form names exists.
func test_no_copy_in_the_scripts() -> void:
	var rx := RegEx.create_from_string("\"([^\"]*)\"")
	var has_copy := RegEx.create_from_string("[A-Z ]")
	for path: String in SCRIPTS:
		var n := 0
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var line: String = raw.get_slice("##", 0)
			if line.strip_edges().begins_with("#") or line.strip_edges().begins_with("const") or line.contains("%d:%02d") or line.contains(".name ="):
				continue
			for m: RegExMatch in rx.search_all(line):
				if has_copy.search(m.get_string(1)) != null:
					check(false, "%s:%d has copy: %s" % [path, n, m.get_string(1)])


func test_forms_only_name_fields_their_documents_have() -> void:
	var cfg := _cfg()
	var p := _paper(cfg)
	var q := QuotaState.new(_quota_cfg())
	var c := _contract(p, [_log({"threats_seen": {"stalker": "cargo"}})])
	var slip := p.payslip(_log(), c)
	slip.merge(p.quota_fields(q.facts()))
	var docs := {
		"briefing": c, "payslip": slip,
		"death_bill": p.death_bill(_log({"ended": "death"}), c, q.facts()),
		"termination": p.termination(c, q.facts()),
	}
	var rx := RegEx.create_from_string("\\{(\\w+)\\}")
	var extra := {"briefing": ["decline_line"]}
	for screen: String in docs:
		var doc: Dictionary = docs[screen]
		for op: Dictionary in cfg.base + (cfg.screens[screen] as Array):
			if op.has("list"):
				check(doc.get(op.list) is Array, "%s lists %s" % [screen, op.list])
			elif op.has("text"):
				for m: RegExMatch in rx.search_all(String(op.text)):
					var key := m.get_string(1)
					check(doc.has(key) or (extra.get(screen, []) as Array).has(key), "%s prints {%s}" % [screen, key])


# --- the run log ---

func test_the_log_records_where_and_what_was_met() -> void:
	var rl := RunLog.new(TEST_DIR)
	check_eq(rl.to_dict("x").death_location, null, "nowhere yet")
	check((rl.to_dict("x").threats_seen as Dictionary).is_empty(), "nothing met")
	rl.note_threat("spit", "medbay")
	rl.note_threat("spit", "cargo")
	rl.note_death_location("cargo")
	var d := rl.to_dict("death")
	check_eq(d.threats_seen.spit, "medbay", "the first place stands")
	check_eq(d.death_location, "cargo", "location")
	rl.begin()
	check_eq(rl.to_dict("x").death_location, null, "a new life forgets")
	check((rl.to_dict("x").threats_seen as Dictionary).is_empty(), "both")


# --- the session on the real deck ---

func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://scenes/shift/shift_deck.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	scene.operator.input_enabled = false
	scene.aim_from_mouse = false
	scene.set_physics_process(false)
	scene.operator.set_physics_process(false)
	scene.run_log.dir = TEST_DIR
	await tree.process_frame
	return scene


func _at_airlock(scene: Node) -> void:
	var c: Vector2 = scene.airlock.rect.get_center()
	scene.operator.global_position = Vector3(c.x, 0, c.y)


## Walks a shift home with `n` items in the hold, through the real LEAVE.
func _go_home(scene: Node, n: int) -> void:
	scene.paper.press("accept")
	for item: RefCounted in scene.field.items.slice(0, n):
		scene.shift.hold.deposit(item)
		scene.field.put_away(item)
	_at_airlock(scene)
	scene.operator.scripted = {"leave": true}
	var left := float(scene.shift.cfg.leave.hold_s) + DT * 2.0
	while left > 0.0 and not scene.shift.ended():
		scene.simulate_world(DT)
		left -= DT
	scene.operator.scripted = {}


func test_without_a_session_the_deck_plays_plain_shifts() -> void:
	var scene: Node = await _scene()
	check(not scene.session_live, "no session in a test or a capture")
	check(not scene.paper.is_open(), "no form")
	check(scene.hud.quota.is_empty(), "no quota on the HUD")


func test_the_briefing_freezes_the_ship_and_describes_this_one() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	check_eq(scene.paper.screen_name, "briefing", "first thing: the contract")
	check_eq(scene.operator.process_mode, Node.PROCESS_MODE_DISABLED, "nobody moves behind it")
	var total := 0
	for item: RefCounted in scene.field.items:
		total += int(item.value)
	check_eq(scene.contract.true_value_cr, total, "this ship's real total")
	var spread := float(scene.paperwork.cfg.contract.estimate_spread)
	check(absf(float(scene.contract.estimated_value_cr) - total) <= total * spread, "estimated within the spread")
	var oxygen: float = scene.shift.oxygen_left
	scene._physics_process(DT)
	check_eq(scene.shift.oxygen_left, oxygen, "the clock waits for a signature")
	scene.paper.press("accept")
	check(not scene.paper.is_open(), "signed")
	check_eq(scene.operator.process_mode, Node.PROCESS_MODE_INHERIT, "moving again")
	check_eq(scene.contract.true_value_cr, total, "the same ship")
	var rolled: Array = scene.field.items.map(func(i: RefCounted) -> int: return i.value)
	scene.simulate_world(DT)
	check_eq(scene.field.items.map(func(i: RefCounted) -> int: return i.value), rolled, "not re-rolled")
	check(scene.shift.oxygen_left < oxygen, "the clock runs")
	check_eq(int(scene.hud.quota.quota), int(scene.quota.quota), "HUD: the quota")
	check_eq(int(scene.hud.quota.shifts_left), int(scene.quota.shifts_left), "HUD: shifts left")


func test_leave_files_a_payslip_that_goes_on_the_quota() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	_go_home(scene, 4)
	check_eq(scene.paper.screen_name, "payslip", "after LEAVE")
	var doc: Dictionary = scene.paper.doc
	var hold: int = scene.shift.hold.actual()
	check_eq(doc.gross_cr, hold, "the hold's true value")
	check_eq(scene.quota.banked, int(doc.net_cr), "net goes on the quota")
	check_eq(doc.banked, scene.paperwork.cr(int(doc.net_cr)), "and the slip says so")
	check_eq(scene.quota.shifts_left, int(_quota_cfg().shifts_per_cycle) - 1, "one gone")
	check(scene.paper.press("acknowledge"), "acknowledged")
	check_eq(scene.paper.screen_name, "briefing", "next contract")
	check_eq((scene.past_logs as Array).size(), 1, "one log on file")
	check(not scene.shift.ended(), "a new ship")


func test_decline_needs_a_confirm_and_still_counts() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	check(not scene.paper.press("confirm_decline"), "no confirm before you've declined")
	check(scene.paper.press("decline"), "declined")
	check_eq(scene.paper.screen_name, "briefing", "still on the form")
	var lines: Array = scene.paperwork.cfg.decline_lines.map(func(l: Dictionary) -> String: return l.text)
	check(lines.has(scene.paper.doc.decline_line), "the deadpan line")
	check_eq(scene.quota.shifts_left, int(_quota_cfg().shifts_per_cycle), "nothing's counted until confirmed")
	check(scene.paper.press("accept"), "can still sign")
	check(not scene.paper.is_open(), "signed")
	scene.start_session()
	var id: String = scene.contract.id
	scene.paper.press("decline")
	check(scene.paper.press("confirm_decline"), "confirmed")
	check_eq(scene.quota.shifts_left, int(_quota_cfg().shifts_per_cycle) - 1, "it counts against the quota")
	check_eq(scene.quota.banked, 0, "and pays nothing")
	check_eq(scene.paper.screen_name, "briefing", "next contract")
	check(scene.contract.id != id, "a new one")


func test_a_miss_fires_the_crew_then_a_full_reset() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	for i in int(_quota_cfg().shifts_per_cycle):
		check_eq(scene.paper.screen_name, "briefing", "briefed")
		scene.paper.press("decline")
		scene.paper.press("confirm_decline")
	check_eq(scene.paper.screen_name, "termination", "the notice fires on a miss")
	check_eq(scene.paper.doc.shortfall_cr, int(_quota_cfg().start_cr), "the whole quota short")
	check(scene.paper.press("acknowledge"), "acknowledged")
	check_eq(scene.paper.screen_name, "briefing", "a new contractor")
	check_eq(scene.quota.quota, int(_quota_cfg().start_cr), "first quota")
	check_eq(scene.quota.cycle, 1, "first cycle")
	check((scene.past_logs as Array).is_empty(), "no logs carried")


func test_a_miss_after_a_payslip_reaches_the_notice() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	scene.quota.shifts_left = 1
	_go_home(scene, 0)
	check_eq(scene.paper.screen_name, "payslip", "the payslip first")
	check(int(scene.paper.doc.net_cr) < 0, "empty-handed: balance due")
	check_eq(scene.quota.verdict, "missed", "missed")
	check(String(scene.paper.doc.quota_note) != "", "the slip says so")
	scene.paper.press("acknowledge")
	check_eq(scene.paper.screen_name, "termination", "then the notice")


func test_meeting_it_on_the_deck_raises_the_next_briefing() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	scene.quota.shifts_left = 1
	scene.quota.banked = int(scene.quota.quota) + 2000
	_go_home(scene, 0)
	check_eq(scene.quota.verdict, "met", "met")
	check(String(scene.paper.doc.quota_note) != "", "the slip says so")
	scene.paper.press("acknowledge")
	check_eq(scene.paper.screen_name, "briefing", "next")
	check_eq(scene.quota.cycle, 2, "cycle two")
	check(String(scene.contract.quota_note) != "", "the briefing says so")


func test_death_gets_a_bill_after_the_death_screen_and_its_cause_is_the_logs() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	scene.paper.press("accept")
	var space := "medbay"
	var at: Vector2 = scene.layout.space_rect(space).get_center()
	scene.operator.global_position = Vector3(at.x, 0, at.y)
	scene.shift.carry(scene.player_id).pockets.append(scene.field.items[0])
	var carried: int = scene.field.items[0].value
	scene._hurt("spit", 1000.0, "the stalker", false)
	check(not scene.paper.is_open(), "the death screen has its moment")
	var hold := float(scene._cfg.session.death_hold_s)
	var left := hold + DT * 2.0
	while left > 0.0 and not scene.paper.is_open():
		scene.simulate_world(DT)
		left -= DT
	check_eq(scene.paper.screen_name, "death_bill", "then the bill")
	var doc: Dictionary = scene.paper.doc
	check_eq(doc.method, "spit", "as logged")
	check_eq(doc.cause_id, "spit", "cause")
	check_eq(doc.killer, "the stalker", "who")
	check_eq(doc.location, String(scene.paperwork.cfg.space_words[space]), "where")
	check_eq(scene.past_logs[-1].death_location, space, "the location's in the log")
	check_eq(scene.past_logs[-1].carried_at_death_value, carried, "and what you carried")
	check_eq(scene.quota.banked, 0, "the balance goes to next of kin, not the quota")
	check_eq(scene.quota.deaths, 1, "a death on file")
	check_eq(scene.quota.shifts_left, int(_quota_cfg().shifts_per_cycle) - 1, "the quota clock still ticks")
	scene.paper.press("acknowledge")
	check_eq(scene.paper.screen_name, "briefing", "next contract")
	check(not scene.suit.dead, "someone new in the suit")


func test_oxygen_death_is_billed_as_oxygen() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	scene.paper.press("accept")
	scene.shift.oxygen_left = 0.0
	var left := 80.0
	while left > 0.0 and not scene.suit.dead:
		scene.simulate_world(1.0 / 20.0)
		left -= 1.0 / 20.0
	scene.file_death_bill()
	check_eq(scene.paper.doc.cause_id, "oxygen", "the log says oxygen")
	check_eq(scene.paper.doc.method, "oxygen", "printed")


func test_hazards_reach_the_next_briefing_only_once_met() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	check((scene.contract.known_hazards as Array).is_empty(), "first contract: nothing known")
	scene.paper.press("accept")
	scene._hurt("puddle", 1.0, "the floor", false)
	scene.abandon_shift()
	check_eq(scene.paper.screen_name, "payslip", "abandoned shifts are billed")
	check(scene.paper.doc.deductions.any(func(d: Dictionary) -> bool: return d.id == "replacement_shift"), "for the replacement")
	scene.paper.press("acknowledge")
	var kinds: Array = scene.contract.known_hazards.map(func(h: Dictionary) -> String: return h.kind)
	check_eq(kinds, ["puddle"], "exactly what happened")


func test_airlock_cycles_count_deposits_that_put_something_in() -> void:
	var scene: Node = await _scene()
	var s: RefCounted = scene.shift
	check_eq(s.report().airlock_cycles, 0, "none yet")
	s.deposit(scene.player_id)
	check_eq(s.report().airlock_cycles, 0, "empty hands don't cycle it")
	s.carry(scene.player_id).pockets.append(scene.field.items[0])
	s.deposit(scene.player_id)
	check_eq(s.report().airlock_cycles, 1, "one")
	check_eq((s.report().salvage as Array).size(), 1, "and the item's on file")
	s.begin()
	check_eq(s.report().airlock_cycles, 0, "a new shift")


func test_the_screen_draws_and_buttons_sit_where_data_says() -> void:
	var scene: Node = await _scene()
	scene.start_session()
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	var names: Array = scene.paper.buttons().map(func(b: Dictionary) -> String: return b.name)
	check_eq(names, ["accept", "decline"], "accept and decline")
	var a: Rect2 = scene.paper.buttons()[0].rect
	var d: Rect2 = scene.paper.buttons()[1].rect
	check(a.get_area() > d.get_area() * 2.0, "ACCEPT much larger than DECLINE")
	check(scene.paper.buttons()[0].primary, "accept is primary")
	scene.paper.press("decline")
	await tree.process_frame
	names = scene.paper.buttons().map(func(b: Dictionary) -> String: return b.name)
	check_eq(names, ["accept", "confirm_decline"], "confirm replaces decline")


func test_a_long_ledger_scrolls_and_the_total_stays_pinned() -> void:
	var scene: Node = await _scene()
	var tree := Engine.get_main_loop() as SceneTree
	scene.start_session()
	var ledger := []
	for i in 60:
		ledger.append({"style": "row", "label": "row %d" % i, "unit": "", "amount": ""})
	var op: Dictionary = (scene.paper.cfg.screens.payslip as Array).filter(func(o: Dictionary) -> bool: return o.has("list"))[0]
	var window := float(op.bottom) - float(op.top)
	var hide_some: int = scene.paper._rows_to_hide(ledger, op.styles, float(op.min_fit), window)
	check(hide_some > 0, "sixty rows don't fit")
	check(hide_some < ledger.size(), "some still do")
	check_eq(scene.paper._rows_to_hide(ledger.slice(0, 2), op.styles, 1.0, window), 0, "two do")
	var slip: Dictionary = scene.paperwork.payslip(_log(), scene.contract)
	slip.merge(scene.paperwork.quota_fields(scene.quota.facts()))
	slip.ledger = ledger
	scene.paper.open("payslip", slip)
	await tree.process_frame
	await tree.process_frame
	scene.paper._scroll_by(1000)
	await tree.process_frame
	check(scene.paper.is_open(), "drew")


# --- real input: what a player's keys and clicks reach ---

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	(Engine.get_main_loop() as SceneTree).root.push_input(e)


func _click(scene: Node, button: String) -> void:
	for b: Dictionary in scene.paper.buttons():
		if b.name == button:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			e.position = scene.paper._origin + (b.rect as Rect2).get_center() * scene.paper._scale
			(Engine.get_main_loop() as SceneTree).root.push_input(e)


func test_keys_and_clicks_work_the_forms_and_stop_at_them() -> void:
	var scene: Node = await _scene()
	var tree := Engine.get_main_loop() as SceneTree
	scene.start_session()
	await tree.process_frame
	await tree.process_frame
	_key(KEY_ENTER)
	check(scene.paper.is_open(), "a key held over from the shift can't sign: the lock")
	scene.paper._lock_left = 0.0
	var left: int = scene.quota.shifts_left
	_key(KEY_BACKSPACE)
	check_eq(scene.quota.shifts_left, left, "the deck's keys stop at the form")
	check(scene.paper.is_open(), "still up")
	_click(scene, "decline")
	check(scene.paper.doc.get("confirming", false), "the click declined")
	_key(KEY_ENTER)
	check(not scene.paper.is_open(), "Enter signs")
	_key(KEY_BACKSPACE)
	check_eq(scene.paper.screen_name, "payslip", "Backspace in a shift abandons it, billed")
	check_eq(scene.quota.shifts_left, left - 1, "and it counts")
	scene.paper._lock_left = 0.0
	_key(KEY_ENTER)
	check_eq(scene.paper.screen_name, "briefing", "Enter acknowledges")
