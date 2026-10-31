extends RefCounted
## Scene-free: turns run logs and quota facts into documents, flat dictionaries the screen prints.
## Strings are formatted for `{field}`s in data/paperwork.json; the `_cr` numbers beside them are what
## the arithmetic really was. All copy and rates are in data. Nothing here says what happened: that's
## the log (src/run_log), and a line whose cause isn't in the log doesn't print.

const LineBook := preload("res://src/paperwork/line_book.gd")

var cfg: Dictionary
var book := LineBook.new()
var rng := RandomNumberGenerator.new()


func _init(config: Dictionary) -> void:
	cfg = config


func reseed(value: int) -> void:
	rng.seed = value
	book.rng.seed = rng.randi()


## 1,600. Negative numbers keep a plain minus: balances aren't clamped.
func cr(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	var group := int(cfg.format.group_digits)
	for i in digits.length():
		if i > 0 and (digits.length() - i) % group == 0:
			out += String(cfg.format.separator)
		out += digits[i]
	return String(cfg.format.minus) + out if amount < 0 else out


func clock(seconds: float) -> String:
	var whole := int(floorf(seconds))
	var minute := int(cfg.format.minute_s)
	return "%d:%02d" % [whole / minute, whole % minute]


func _words(key: String, fields := {}) -> String:
	return String(cfg.words[key]).format(fields)


func _space_word(space: Variant) -> String:
	if space == null:
		return _words("not_recorded")
	return String(cfg.space_words.get(String(space), space))


func _crew_name() -> String:
	return String(cfg.contract.crew[0].name)


# --- the briefing ---

## What the briefing knows from past logs: threats somebody really met, the latest place for each, in
## data order, which is also which ones make the form when there are too many.
func known_hazards(past_logs: Array) -> Array:
	var seen := {}
	for log: Dictionary in past_logs:
		var threats: Dictionary = log.get("threats_seen", {})
		for kind: String in threats:
			seen[kind] = threats[kind]
	var out: Array = []
	for entry: Dictionary in cfg.hazards:
		var kind := String(entry.kind)
		if seen.has(kind):
			out.append({"kind": kind, "description": String(entry.text), "location": _space_word(seen[kind])})
	return out


## Within the data's spread of the ship's real total, on a round number that stays within it.
func estimate(ship_total: int) -> int:
	var spread := float(cfg.contract.estimate_spread)
	var raw := float(ship_total) * (1.0 + rng.randf_range(-spread, spread))
	var snapped := snappedi(raw, int(cfg.contract.estimate_round_to))
	return clampi(snapped, ceili(float(ship_total) * (1.0 - spread)), floori(float(ship_total) * (1.0 + spread)))


func contract(number: int, ship_total: int, past_logs: Array, quota_facts: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.contract
	var vessel: Dictionary = book.pick("vessels", c.vessels)
	var id := String(c.id_format) % (int(c.id_base) + number)
	var estimate_cr := estimate(ship_total)
	var known := known_hazards(past_logs)
	var shown := known.slice(0, int(c.hazard_rows))
	var rows: Array = []
	for h: Dictionary in shown:
		rows.append({"n": str(rows.size() + 1).pad_zeros(2), "text": _words("hazard_row", h)})
	if known.is_empty():
		rows.append({"n": "", "text": _words("no_hazards")})
	else:
		rows.append({"n": str(rows.size() + 1).pad_zeros(2), "text": _words("hazard_rest")})
	var crew: Array = []
	for member: Dictionary in c.crew:
		crew.append({"n": str(crew.size() + 1).pad_zeros(2), "name": String(member.name), "role": String(member.role)})
	var doc := {
		"id": id, "ref": _words("ref_contract", {"id": id}), "vessel": String(vessel.text), "status": String(c.status),
		"estimated_value_cr": estimate_cr, "estimate": cr(estimate_cr), "true_value_cr": ship_total,
		"known_hazards": known, "hazards": rows, "crew": crew, "next_of_kin": String(c.next_of_kin), "contractor": _crew_name(),
	}
	doc.merge(quota_fields(quota_facts))
	return doc


func decline_line() -> String:
	return String(book.pick("decline", cfg.decline_lines).text)


# --- quota lines every document can carry ---

func quota_fields(q: Dictionary) -> Dictionary:
	var note := ""
	match String(q.verdict):
		"met":
			note = _words("quota_met", {"surplus": cr(int(q.surplus)), "next": cr(int(q.quota))})
		"missed":
			note = _words("quota_missed", {"shortfall": cr(int(q.shortfall))})
	return {
		"quota": cr(int(q.quota)), "banked": cr(int(q.banked)), "shifts_left": str(int(q.shifts_left)),
		"quota_share": float(q.share), "quota_note": note, "cycle": str(int(q.cycle)),
	}


# --- the payslip ---

## How many of each thing the log shows. Zero means the cause isn't in the log. The tariff in data names
## these keys, so a line can't print without one.
func quantities(log: Dictionary) -> Dictionary:
	var alive := float(log.get("time_alive_s", 0.0))
	var dmg: Dictionary = log.get("damage_by_source", {})
	var shots := int(log.get("shots_fired", 0))
	var hit := int(log.get("shots_hit", 0))
	var minute := float(cfg.format.minute_s)
	var ended := String(log.get("ended", ""))
	return {
		"shift": 1 if alive > 0.0 else 0,
		"rounds": shots,
		"oxygen_minutes": ceili(alive / minute),
		"cycles": int(log.get("airlock_cycles", 0)),
		"rounds_missed": maxi(shots - hit, 0),
		"rounds_hit": hit,
		"your_shots_blocked": int(log.get("your_shots_blocked", 0)),
		"shots_blocked_for_you": int(log.get("shots_blocked_for_you", 0)),
		"times_protected": int(log.get("times_protected", 0)),
		"locked_minutes": ceili(float(log.get("time_locked_s", 0.0)) / minute),
		"hits_in_open": int(log.get("hits_in_open", 0)),
		"hits_in_cover": int(log.get("hits_in_cover", 0)),
		"spit_damage": ceili(float(dmg.get("spit", 0.0))),
		"puddle_damage": ceili(float(dmg.get("puddle", 0.0))),
		"lunge_damage": ceili(float(dmg.get("lunge", 0.0))),
		"rifle_damage": ceili(float(dmg.get("rifle", 0.0))),
		"ended_quit": 1 if ended == "quit" else 0,
		"ended_respawn": 1 if ended == "respawn" else 0,
		"items": (log.get("salvage", []) as Array).size(),
	}


## What the tariff charges for this log, in tariff order: {id, label, note, quantity, unit, rate_cr, amount_cr}.
func deductions(log: Dictionary) -> Array:
	var counts := quantities(log)
	var out: Array = []
	for line: Dictionary in cfg.tariff:
		if not bool(line.get("enabled", true)):
			continue
		var qty := int(counts[String(line.qty)])
		if qty <= 0:
			continue
		var rate := int(line.rate)
		out.append({
			"id": String(line.id), "label": String(line.label), "note": String(line.note), "quantity": qty,
			"unit": String(line.unit) if qty == 1 else String(line.units), "rate_cr": rate, "amount_cr": qty * rate,
		})
	return out


## Credits by item, grouped by kind. Items of a kind are each worth their own, so several show as assessed.
func credits(log: Dictionary) -> Array:
	var rows := {}
	if String(log.get("shift_outcome", "")) != "extracted":
		return []
	for item: Dictionary in log.get("salvage", []):
		var kind := String(item.kind)
		var row: Dictionary = rows.get(kind, {"kind": kind, "label": String(cfg.salvage_labels.get(kind, item.word)), "quantity": 0, "amount_cr": 0})
		row.quantity = int(row.quantity) + 1
		row.amount_cr = int(row.amount_cr) + int(item.value)
		rows[kind] = row
	return rows.values()


## The quota line goes on after the net is known: `quota_fields`.
func payslip(log: Dictionary, contract_doc: Dictionary) -> Dictionary:
	var earned := credits(log)
	var charged := deductions(log)
	var gross := 0
	for row: Dictionary in earned:
		gross += int(row.amount_cr)
	var total := 0
	for row: Dictionary in charged:
		total += int(row.amount_cr)
	var net := gross - total
	var ledger: Array = [{"style": "head", "label": _words("credits_head"), "amount": _words("amount_head")}]
	for row: Dictionary in earned:
		var unit := _words("credit_one", {"value": cr(int(row.amount_cr))}) if int(row.quantity) == 1 else _words("credit_many", {"qty": row.quantity})
		ledger.append({"style": "row", "label": row.label, "unit": unit, "amount": String(cfg.format.plus) + cr(int(row.amount_cr))})
	if earned.is_empty():
		ledger.append({"style": "row", "label": _words("no_salvage"), "unit": "", "amount": ""})
	ledger.append({"style": "total", "label": _words("gross_head"), "amount": cr(gross)})
	ledger.append({"style": "head", "label": _words("deductions_head"), "amount": ""})
	for row: Dictionary in charged:
		ledger.append({"style": "row", "label": row.label, "unit": _words("charge_unit", {"qty": row.quantity, "unit": row.unit, "rate": cr(int(row.rate_cr))}), "amount": cr(-int(row.amount_cr))})
	var returned := String(log.get("shift_outcome", "")) == "extracted"
	return {
		"credits": earned, "deductions": charged, "ledger": ledger,
		"gross_cr": gross, "deductions_total_cr": total, "net_cr": net,
		"gross": cr(gross), "deductions_paid": cr(total), "deductions_total": cr(-total), "net": cr(net),
		"net_label": _words("net_negative") if net < 0 else _words("net_positive"), "balance_due": net < 0,
		"status": _words("status_returned") if returned else _words("status_abandoned"),
		"time_aboard": clock(float(log.get("time_alive_s", 0.0))), "note": _payslip_note(charged),
		"ref": _words("ref_shift", {"id": contract_doc.id, "name": contract_doc.contractor}), "contractor": contract_doc.contractor,
	}


## One charged line's small print. Rests a while, so the same line doesn't sign two payslips running.
func _payslip_note(charged: Array) -> String:
	var pool: Array = []
	var rest := int(cfg.note_cooldown)
	for row: Dictionary in charged:
		pool.append({"id": row.id, "text": row.note, "cooldown": rest})
	var line := book.pick("notes", pool)
	return String(line.get("text", ""))


# --- the death bill ---

## What the log says about this death, for the cause library's `requires`.
func death_facts(log: Dictionary) -> Dictionary:
	var by: Variant = log.get("killed_by", null)
	var how := String(by.get("how", "")) if by is Dictionary else ""
	var dmg: Dictionary = log.get("damage_by_source", {})
	var classes := 0
	for source: String in dmg:
		if float(dmg[source]) > 0.0:
			classes += 1
	return {
		"no_killer": by == null,
		"method_spit": how == "spit", "method_puddle": how == "puddle", "method_lunge": how == "lunge",
		"method_rifle": how == "rifle", "method_oxygen": how == "oxygen",
		"by_stalker": by is Dictionary and by.has("stalker"), "by_pirate": by is Dictionary and by.has("pirate"),
		"many_classes": classes >= 2,
		"hits_in_cover": int(log.get("hits_in_cover", 0)) > 0, "hits_in_open": int(log.get("hits_in_open", 0)) > 0,
		"puddle_on_file": float(dmg.get("puddle", 0.0)) > 0.0, "lunge_on_file": float(dmg.get("lunge", 0.0)) > 0.0,
		"rifle_on_file": float(dmg.get("rifle", 0.0)) > 0.0,
		"sheltered": int(log.get("shots_blocked_for_you", 0)) + int(log.get("times_protected", 0)) > 0,
	}


func death_bill(log: Dictionary, contract_doc: Dictionary, quota_facts: Dictionary) -> Dictionary:
	var facts := death_facts(log)
	var by: Variant = log.get("killed_by", null)
	var killer := _words("not_recorded")
	var method := _words("not_recorded")
	if by is Dictionary:
		for key: String in cfg.killer_keys:
			if by.has(key):
				killer = String(by[key])
				break
		method = String(by.get("how", method))
	var causes: Dictionary = cfg.causes
	var primary: Dictionary = LineBook.allowed(causes.primary, facts)[0]
	var party: Array = LineBook.allowed(causes.party, facts)
	var context := book.pick_first("context", LineBook.allowed(causes.context, facts))
	var d: Dictionary = cfg.death
	var carried := int(log.get("carried_at_death_value", 0))
	var lines: Array = [
		{"label": String(d.processing_label), "amount_cr": int(d.processing_cr)},
		{"label": String(d.suit_label), "amount_cr": int(d.suit_cr)},
	]
	if carried > 0:
		lines.append({"label": String(d.carried_label), "amount_cr": carried})
	lines.append({"label": String(d.cleanup_label), "amount_cr": int(d.cleanup_cr)})
	var total := 0
	for line: Dictionary in lines:
		total += int(line.amount_cr)
		line["amount"] = cr(int(line.amount_cr))
	var location: Variant = log.get("death_location", null)
	var doc := {
		"lines": lines, "outstanding_cr": total, "outstanding": cr(total),
		"killer": killer, "method": method, "location": _space_word(location), "location_recorded": location != null,
		"time_alive": clock(float(log.get("time_alive_s", 0.0))),
		"cause_id": String(primary.id), "cause": String(primary.text), "cause_line": String(primary.line),
		"party_line": String(party[0].line) if not party.is_empty() else "",
		"context_line": String(context.get("line", "")),
		"next_of_kin": contract_doc.next_of_kin, "contractor": contract_doc.contractor,
		"ref": _words("ref_invoice", {"id": contract_doc.id, "name": contract_doc.contractor}),
	}
	doc.merge(quota_fields(quota_facts))
	return doc


# --- the termination notice ---

func termination(contract_doc: Dictionary, q: Dictionary) -> Dictionary:
	var t: Dictionary = cfg.termination
	var rows: Array = []
	var total := 0
	for line: Dictionary in t.deductions:
		total += int(line.rate)
		rows.append({"label": String(line.label), "amount_cr": int(line.rate), "amount": cr(-int(line.rate))})
	var banked := int(q.banked)
	var facts := {
		"cycles_met": int(q.cycles_met) > 0, "deaths": int(q.deaths) > 0, "declined": int(q.declined) > 0,
		"in_debt": banked < 0, "no_cycles": int(q.cycles_met) == 0,
	}
	var pool := LineBook.allowed(t.lines, facts)
	var first := book.pick("termination", pool)
	var second := book.pick("termination", pool.filter(func(line: Dictionary) -> bool: return line.id != first.id))
	var final_balance := banked - total
	return {
		"ref": _words("ref_notice", {"id": contract_doc.id, "name": contract_doc.contractor}), "contractor": contract_doc.contractor,
		"quota_due_cr": int(q.quota_due), "banked_cr": banked, "shortfall_cr": int(q.shortfall),
		"quota_due": cr(int(q.quota_due)), "banked": cr(banked), "shortfall": cr(int(q.shortfall)),
		"deductions": rows, "deductions_total_cr": total, "final_balance_cr": final_balance, "final_balance": cr(final_balance),
		"balance_label": _words("final_negative") if final_balance < 0 else _words("final_positive"),
		"cycle": str(int(q.cycle)), "shifts_billed": str(int(q.shifts_billed)), "deaths_on_file": str(int(q.deaths)), "declined": str(int(q.declined)),
		"line_one": String(first.get("text", "")), "line_two": String(second.get("text", "")),
	}
