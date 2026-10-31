extends RefCounted
## Scene-free suit OS: which words the HUD shows and how they read. The drawing is suit_os_hud.gd.
## Numbers and words: data/hud.json.

var cfg: Dictionary
var oxygen_left := 0.0
var oxygen_total := 0.0
var driven := false            # a shift owns the clock (src/shift); otherwise it's a placeholder

var _announce := ""
var _announce_left := 0.0
var _custodian := ""
var _custodian_left := 0.0


func _init(config: Dictionary) -> void:
	cfg = config
	reset()


func reset() -> void:
	_announce = ""
	_announce_left = 0.0
	_custodian = ""
	_custodian_left = 0.0
	if not driven:
		oxygen_total = float(cfg.oxygen.start_s)
		oxygen_left = oxygen_total


func step(delta: float) -> void:
	_announce_left = maxf(_announce_left - delta, 0.0)
	_custodian_left = maxf(_custodian_left - delta, 0.0)
	if not driven:
		oxygen_left = maxf(oxygen_left - delta, 0.0)


## The real clock: from here on the suit reads this and counts nothing itself.
func set_oxygen(left: float, total: float) -> void:
	driven = true
	oxygen_left = left
	oxygen_total = total


## One terse line across the top, in the suit's voice. A new one replaces the old.
func announce(line: String) -> void:
	_announce = line
	_announce_left = float(cfg.announce.life_s)


## The line showing now and how solid it is, or "" when there's none.
func announcement() -> String:
	return _announce if _announce_left > 0.0 else ""


func announcement_alpha() -> float:
	return minf(_announce_left / float(cfg.announce.fade_s), 1.0)


## The ship's own voice, on its own line under the suit's: neither talks over the other.
func custodian_say(line: String) -> void:
	_custodian = line
	_custodian_left = float(cfg.custodian.life_s)


func custodian_line() -> String:
	return _custodian if _custodian_left > 0.0 else ""


func custodian_alpha() -> float:
	return minf(_custodian_left / float(cfg.custodian.fade_s), 1.0)


func oxygen_text() -> String:
	var per_minute := int(cfg.oxygen.seconds_per_minute)
	var whole := ceili(oxygen_left)
	return "%02d:%02d" % [whole / per_minute, whole % per_minute]


func oxygen_fraction() -> float:
	return oxygen_left / oxygen_total


func suit_low(fraction: float) -> bool:
	return fraction <= float(cfg.suit.low_fraction)


func ammo_low(mag: int) -> bool:
	return mag <= int(cfg.ammo.low_rounds)


## Credits with thousands separated, as the company bills them.
func credits_text(credits: int) -> String:
	var digits := str(credits)
	var out := ""
	var group := int(cfg.salvage.group_digits)
	for i in digits.length():
		if i > 0 and (digits.length() - i) % group == 0:
			out += String(cfg.salvage.separator)
		out += digits[i]
	return out


## The hold as far as the suit knows: an estimate until the payslip.
func hold_text(estimate: int) -> String:
	return String(cfg.salvage.approx) + credits_text(estimate)


## The alarm strip over the right dock, most urgent first. `urgent`: keys of `words` that outrank the
## rest ("alarm", "o2_out").
func alerts(in_acid: bool, mag: int, urgent := []) -> Array:
	var out: Array = []
	for key: String in urgent:
		out.append({"word": String(cfg.words[key]), "color": String(cfg.colors.danger)})
	if in_acid:
		out.append({"word": String(cfg.words.acid), "color": String(cfg.colors.danger)})
	if ammo_low(mag):
		out.append({"word": String(cfg.words.low_ammo), "color": String(cfg.colors.warn)})
	return out


## The states over the operator. `f`: in_cover, lock ("", "locked", "exposed"), crouched, sprinting,
## reloading, empty, light_off, and maybe hands_full.
func status(f: Dictionary) -> Array:
	var w: Dictionary = cfg.words
	var c: Dictionary = cfg.colors
	var out: Array = []
	if bool(f.in_cover):
		out.append({"word": String(w.in_cover), "color": String(c.good), "shield": true})
	var lock := String(f.lock)
	if lock == "exposed":
		out.append({"word": String(w.locked_exposed), "color": String(c.danger)})
	elif lock == "locked":
		out.append({"word": String(w.locked), "color": String(c.good)})
	elif bool(f.crouched):
		out.append({"word": String(w.crouched), "color": String(c.text)})
	if bool(f.reloading):
		out.append({"word": String(w.reloading), "color": String(c.warn)})
	elif bool(f.empty):
		out.append({"word": String(w.empty), "color": String(c.danger)})
	elif bool(f.sprinting):
		out.append({"word": String(w.sprinting), "color": String(c.text)})
	if bool(f.get("hands_full", false)):
		out.append({"word": String(w.hands_full), "color": String(c.warn)})
	if bool(f.light_off):
		out.append({"word": String(w.light_off), "color": String(c.warn)})
	return out
