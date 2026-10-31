extends RefCounted
## Scene-free: what's been banked for the shift. One hold for the crew. The suit knows only the
## estimate; the true value waits for the payslip.

const SalvageItem := preload("res://src/salvage/salvage_item.gd")

var items: Array = []


func clear() -> void:
	items = []


func deposit(item: SalvageItem) -> void:
	items.append(item)


func estimate() -> int:
	var total := 0
	for item: SalvageItem in items:
		total += item.base
	return total


func actual() -> int:
	var total := 0
	for item: SalvageItem in items:
		total += item.value
	return total


## {class: {count, value}}, only the classes it holds.
func by_class() -> Dictionary:
	var out := {}
	for item: SalvageItem in items:
		var row: Dictionary = out.get(item.klass, {"count": 0, "value": 0})
		row.count = int(row.count) + 1
		row.value = int(row.value) + item.value
		out[item.klass] = row
	return out
