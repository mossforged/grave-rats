extends RefCounted
## Scene-free rules of salvage: value rolls and what carrying a thing does to you. data/salvage.json.

const SalvageItem := preload("res://src/salvage/salvage_item.gd")

## What an empty pair of hands costs: nothing. The same keys as a class's entry in the data.
const FREE_KEYS := ["speed_mult", "can_sprint", "can_fire", "cone_extra_deg"]

var cfg: Dictionary


func _init(config: Dictionary) -> void:
	cfg = config


func class_of(item: SalvageItem) -> Dictionary:
	return cfg.classes[item.klass]


func kind_spec(kind: String) -> Dictionary:
	return cfg.kinds[kind]


## A new item of a kind: a base inside the class's range (or the kind's own), then the hidden spread.
func roll(kind: String, id: int, rng: RandomNumberGenerator) -> SalvageItem:
	var spec: Dictionary = kind_spec(kind)
	var c: Dictionary = cfg.classes[String(spec.class)]
	var item := SalvageItem.new()
	item.id = id
	item.kind = kind
	item.klass = String(spec.class)
	item.word = String(spec.word)
	item.prize = bool(spec.get("prize", false))
	item.base = rng.randi_range(int(spec.get("value_min", c.value_min)), int(spec.get("value_max", c.value_max)))
	var spread := float(cfg.value_spread)
	item.value = roundi(item.base * rng.randf_range(1.0 - spread, 1.0 + spread))
	return item


## The penalties of what's in hand. Pockets cost nothing, by the data's own numbers.
func penalties(in_hand: SalvageItem) -> Dictionary:
	if in_hand == null:
		return penalties_of(cfg.classes.small)
	return penalties_of(class_of(in_hand))


static func penalties_of(c: Dictionary) -> Dictionary:
	var out := {}
	for key: String in FREE_KEYS:
		out[key] = c[key]
	return out
