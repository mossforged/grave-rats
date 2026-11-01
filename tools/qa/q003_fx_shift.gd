extends "res://src/shift/shift_deck.gd"
## Q003: the shift deck held in one state for a capture window. See q003_fx_driver.gd.

const Q003Driver := preload("res://tools/qa/q003_fx_driver.gd")

var q003_driver: RefCounted


func _ready() -> void:
	super()
	q003_driver = Q003Driver.new(self)
	q003_driver.run()


func simulate_world(_delta: float) -> void:
	pass

