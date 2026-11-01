extends SceneTree
## T023: the part of choosing a ship the test runner can't reach, because it needs the running main scene:
## a session crossing ships under `rotate` keeps its quota, logs and contract count, and F1's picker pins one.
## usage: godot --headless --path . -s tools/t023_ship_check.gd     (add --ship survey to check the flag)

const SCENE := "res://scenes/shift/shift_deck.tscn"

var failed := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _ok(cond: bool, what: String) -> void:
	print("%s %s" % ["ok  " if cond else "FAIL", what])
	failed += 0 if cond else 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rotate(data: Node) -> void:
	data.load_data("shift").ship_pick = "rotate"


func _run() -> void:
	var data: Node = root.get_node("Data")
	if data.ship_arg(OS.get_cmdline_args()) != "":
		_ok(data.ship == "deck_survey" and data.ship_pinned, "--ship survey puts the game on %s, pinned" % data.ship)
		quit(failed)
		return
	_rotate(data)
	change_scene_to_file(SCENE)
	await _frames(5)
	var deck: Node = current_scene
	_ok(data.ship == "deck", "the first contract is on the first ship")
	_ok(deck.session_live and deck.paper.visible, "the briefing is open")
	var quota: RefCounted = deck.quota
	var book: RefCounted = deck.paperwork
	deck.quota.banked = 777
	deck.past_logs.append({"marker": true})
	deck._brief()
	await _frames(5)
	deck = current_scene
	_ok(data.ship == "deck_survey", "rotate moved the second contract to %s" % data.ship)
	_ok(deck.layout.space_order.has("bridge"), "and the deck is the survey's")
	_ok(deck.quota == quota and deck.session.quota == quota and int(deck.quota.banked) == 777, "the quota came along")
	_ok(deck.paperwork == book and deck.past_logs.size() == 1, "and the logs and the book")
	_ok(int(deck._contracts) == 2, "it's contract %d" % deck._contracts)
	_ok(deck.session_live and deck.paper.visible, "and the briefing is open again")
	_rotate(data)
	deck._brief()
	await _frames(5)
	deck = current_scene
	_ok(data.ship == "deck" and deck.layout.space_order.has("medbay"), "the third is back on the first ship")
	_ok(int(deck._contracts) == 3 and deck.quota == quota, "still the same session")
	deck.pick_ship("deck_survey")
	await _frames(5)
	deck = current_scene
	_ok(data.ship == "deck_survey" and data.ship_pinned, "F1's picker pins a ship")
	_ok(int(deck._contracts) == 1, "in a new session")
	_rotate(data)
	deck._brief()
	await _frames(3)
	_ok(data.ship == "deck_survey", "and rotate leaves a pinned ship alone")
	data.reset_ship()
	print("SHIP CHECK: %d failed" % failed)
	quit(failed)
