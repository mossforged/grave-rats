extends Node3D
## All the deck's doors, placed from data/deck.json "doors" (their openings come from DeckLayout).
## Steps them, answers E, and shows one prompt over the door in reach.

const Door := preload("res://src/doors/door.gd")

signal door_used(door: Node3D, answer: String)

var doors: Array = []
var cfg: Dictionary
## `actors` are {position: Vector2, radius: float}: who a closing panel must not shut on.
var actors: Array = []

var _label: Label3D


## `layout` is a DeckLayout; layout.doors and layout.data.doors share their order.
func setup(layout: RefCounted) -> void:
	cfg = Data.load_data("doors")
	var specs: Array = layout.data.doors
	for i in layout.doors.size():
		var d := Door.new()
		add_child(d)
		d.setup(layout.doors[i], specs[i], cfg, float(layout.data.wall_height_m))
		doors.append(d)
	_label = Label3D.new()
	_label.name = "Prompt"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = float(cfg.label_pixel_size)
	_label.font_size = int(cfg.label_font_size)
	_label.visible = false
	add_child(_label)


func _physics_process(delta: float) -> void:
	if delta > 0.0:
		tick(delta)


func tick(delta: float) -> void:
	for d: Door in doors:
		d.tick(delta, actors)


## The nearest door within reach of `p`, or null.
func door_in_reach(p: Vector2) -> Door:
	var best: Door = null
	var best_d := float(cfg.reach_m)
	for d: Door in doors:
		var dist := p.distance_to(d.opening.get_center())
		if dist <= best_d:
			best_d = dist
			best = d
	return best


## E pressed at `p`. Returns the answer, or "" when no door is in reach.
func interact(p: Vector2) -> String:
	var d := door_in_reach(p)
	if d == null:
		return ""
	var answer := d.interact(actors)
	door_used.emit(d, answer)
	return answer


## Shows the prompt for whichever door is in reach of `p`.
func show_prompt(p: Vector2) -> void:
	var d := door_in_reach(p)
	_label.visible = d != null
	if d == null:
		return
	var key := d.door_state.prompt_key()
	_label.text = String(cfg.words[key])
	_label.modulate = Color(cfg.colors.label_locked if key == "locked" or key == "broken" else cfg.colors.label)
	var c := d.opening.get_center()
	_label.global_position = Vector3(c.x, float(cfg.label_height_m), c.y)
