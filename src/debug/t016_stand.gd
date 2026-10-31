extends "res://src/shift/shift_deck.gd"
## Root of scenes/dev/t016_stand.tscn: T016's capture stands on the real shift deck, not a game scene.
## tools/capture.sh scenes/dev/t016_stand.tscn docs/screens/T016 2

const DisplayAA := preload("res://src/debug/display_aa.gd")

const ROW_AT := [0.72, 0.4]
const ROW_BACK_M := 2.0
const ROW_STEP_M := {"small": 0.7, "medium": 0.9, "heavy": 1.2}
const AA_AT := [0.25, 0.3]
const PANEL_SETTLE_S := 0.6
const CLOSEUP_FROM := Vector3(2.2, 1.1, 1.4)
const CLOSEUP_AT_Y := 0.45
const CLOSEUP_LIGHT := 3.0
const CLOSEUP_RANGE_M := 8.0

var _closeup_cam: Camera3D


func capture_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = [
		{"name": "t016_medbay_room", "do": "room"},
		{"name": "t016_medbay_01b_off", "do": "frame", "view": "off"},
		{"name": "t016_medbay_01b_play", "do": "frame", "view": "play"},
		{"name": "t016_salvage_small", "do": "row", "klass": "small"},
		{"name": "t016_salvage_medium", "do": "row", "klass": "medium"},
		{"name": "t016_salvage_heavy", "do": "row", "klass": "heavy"},
		{"name": "t016_salvage_dark", "do": "row", "klass": "heavy", "dark": true},
		{"name": "t016_carry_medium", "do": "carry", "klass": "medium"},
		{"name": "t016_carry_heavy", "do": "carry", "klass": "heavy"},
		{"name": "t016_bed_tipping", "do": "tip", "share": 0.5},
		{"name": "t016_bed_tipped_your_side", "do": "tip", "share": 1.0},
		{"name": "t016_bed_tipped_shield_side", "do": "tip", "share": 1.0, "from_far": true},
		{"name": "t016_bed_plate_closeup", "do": "closeup"},
		{"name": "t016_panel_display", "do": "panel"},
	]
	for mode: Dictionary in DisplayAA.modes():
		shots.append({"name": "t016_aa_%s" % mode.id, "do": "aa", "mode": mode.id})
	# The first mode again: what differs from its first shot isn't the anti-aliasing.
	shots.append({"name": "t016_aa_%s_again" % DisplayAA.modes()[0].id, "do": "aa", "mode": DisplayAA.modes()[0].id})
	return shots


func apply_shot(shot: Dictionary) -> void:
	if _closeup_cam:
		_closeup_cam.queue_free()
		_closeup_cam = null
	_demo_t = -1.0
	Engine.time_scale = 1.0
	panel.visible = false
	sight_debug.visible = false
	_close_form()
	session_live = false
	DisplayAA.apply(get_tree().root, DisplayAA.starting_mode())
	respawn()
	rig.set_preset(int(Data.value("camera", "default_preset")))
	flashlight.set_on(true)
	ambush.fired = true
	match String(shot.do):
		"room":
			set_kit_view("off")
			await _stand_at(layout.point_in("medbay", [0.5, 0.45]), layout.point_in("medbay", [0.5, 0.1]))
		"frame":
			await _open_medbay_door()
			var behind: Vector2 = _bed_spot()
			await _stand_at(behind, behind + Vector2(-float(pack.cfg.lunge.range_m), 0.0))
			set_kit_view(String(shot.view))
		"row":
			await _row_shot(String(shot.klass), bool(shot.get("dark", false)))
		"carry":
			await _carry_shot(String(shot.klass))
		"tip":
			await _tip_shot(float(shot.share), bool(shot.get("from_far", false)))
		"closeup":
			await _closeup()
		"panel":
			await _stand_at(layout.point_in("junction", [0.5, 0.45]), layout.point_in("junction", [0.5, 0.1]))
			panel.visible = true
			await _sim(PANEL_SETTLE_S)
		"aa":
			set_kit_view("off")
			DisplayAA.apply(get_tree().root, String(shot.mode))
			# Light off, so the beam isn't in the crop.
			flashlight.set_on(false)
			await _stand_at(layout.point_in("medbay", AA_AT), layout.point_in("medbay", [0.25, 0.0]))
	await _sim(0.25)
	Engine.time_scale = 0.0


## The stand of A006-01b (`stalker_deck` "01b"): west of the overturned bed, looking west.
func _bed_spot() -> Vector2:
	var r: Rect2 = beds[2].footprint()
	return Vector2(r.position.x - float(_cover_cfg.bed.reach_m) * 0.5, r.get_center().y)


## One of each kind in a class on the lit floor ahead, the rest of the ship put away. Heavy adds the prize.
func _row_shot(klass: String, dark: bool) -> void:
	set_kit_view("known")
	var mid: Vector2 = layout.point_in("medbay", ROW_AT)
	await _stand_at(mid, mid + Vector2(0.0, -ROW_BACK_M))
	var row := {}
	for item: RefCounted in field.items:
		if String(item.klass) == klass and not row.has(item.kind):
			row[item.kind] = item
	var k := 0
	for item: RefCounted in field.items:
		if not row.values().has(item):
			field.put_away(item)
			continue
		field.lay_down(item, mid + Vector2((k - (row.size() - 1) * 0.5) * ROW_STEP_M[klass], -ROW_BACK_M))
		k += 1
	flashlight.set_on(not dark)


## Tipping bed 1 from the east, so it falls west and shows you its mattress. The shield side is the
## room's overturned bed from past it: the steep camera only shows a side face when it's off to one side.
func _tip_shot(share: float, from_far: bool) -> void:
	set_kit_view("known")
	await _open_medbay_door()
	if from_far:
		var lying: Rect2 = beds[2].footprint()
		await _stand_at(_door("medbay", 0.7).opening.get_center(), lying.get_center())
		return
	var bed: TipBed = beds[1]
	var r: Rect2 = bed.upright_rect
	var c := r.get_center()
	var east := Vector2(r.end.x + float(_cover_cfg.bed.reach_m) * 0.6, c.y)
	await _stand_at(east, c)
	bed.try_tip(east)
	await _sim(float(_cover_cfg.bed.tip_s) * share + (0.1 if share >= 1.0 else 0.0))


## Not a game view: a low camera and a lamp on the shield side, since the steep game camera sees little
## of a standing face.
func _closeup() -> void:
	set_kit_view("off")
	var lying: Rect2 = beds[2].footprint()
	var at := Vector3(lying.get_center().x, CLOSEUP_AT_Y, lying.get_center().y)
	_closeup_cam = Camera3D.new()
	add_child(_closeup_cam)
	_closeup_cam.global_position = at + CLOSEUP_FROM
	_closeup_cam.look_at(at)
	_closeup_cam.current = true
	var lamp := OmniLight3D.new()
	lamp.light_energy = CLOSEUP_LIGHT
	lamp.omni_range = CLOSEUP_RANGE_M
	_closeup_cam.add_child(lamp)
