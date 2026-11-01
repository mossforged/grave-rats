extends "res://tools/t014_bots.gd"
## Q003: T014's session bots with T012's door bug put back (T023 fixed it), to split T023's bot fix from game changes.
## usage as tools/t014_bots.gd.


func _init() -> void:
	super()
	_old_door_press = true
