extends RefCounted
## Scene-free suit OS: which words the HUD shows and how they read. The drawing is suit_os_hud.gd.
## Numbers and words: data/hud.json.

var cfg: Dictionary
var oxygen_left := 0.0


func _init(config: Dictionary) -> void:
	cfg = config
	reset()


func reset() -> void:
	oxygen_left = float(cfg.oxygen.start_s)


func step(delta: float) -> void:
	oxygen_left = maxf(oxygen_left - delta, 0.0)


func oxygen_text() -> String:
	var per_minute := int(cfg.oxygen.seconds_per_minute)
	var whole := ceili(oxygen_left)
	return "%02d:%02d" % [whole / per_minute, whole % per_minute]


func oxygen_fraction() -> float:
	return oxygen_left / float(cfg.oxygen.start_s)


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


## The alarm strip over the right dock, most urgent first.
func alerts(in_acid: bool, mag: int) -> Array:
	var out: Array = []
	if in_acid:
		out.append({"word": String(cfg.words.acid), "color": String(cfg.colors.danger)})
	if ammo_low(mag):
		out.append({"word": String(cfg.words.low_ammo), "color": String(cfg.colors.warn)})
	return out


## The states over the operator. `f`: in_cover, lock ("", "locked", "exposed"), crouched, sprinting,
## reloading, empty, light_off.
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
	if bool(f.light_off):
		out.append({"word": String(w.light_off), "color": String(c.warn)})
	return out
