extends "res://tests/test_case.gd"
## T003 tuning panel: every study lever has a slider bound to real data, a slider changes the
## live number, Save round-trips through JSON and only touches changed files.

const TuningPanel := preload("res://src/debug/tuning_panel.gd")
const LEVERS := [
	["player", "turn.standing_deg_s"], ["player", "turn.firing_deg_s"], ["player", "turn.crouched_deg_s"],
	["weapons", "rifle.cone.wide_deg"], ["weapons", "rifle.cone.tight_deg"], ["weapons", "rifle.cone.settle_s"],
	["weapons", "rifle.cone.moving_min_deg"], ["player", "turn.torso_lead_deg"],
	["player", "move.accel_s"], ["player", "move.decel_s"], ["weapons", "rifle.reload_s"],
	["player", "crouch.stand_up_s"], ["weapons", "rifle.recoil.kick_deg"], ["weapons", "rifle.recoil.recover_deg_s"],
	["weapons", "rifle.camera_kick.kick_m"], ["camera", "follow.smoothing_hz"], ["weapons", "targets.flinch_deg"],
]
const TMP := "user://t003_tuning"

var _panel: TuningPanel


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	_panel = TuningPanel.new()
	_panel.save_dir = TMP
	(Engine.get_main_loop() as SceneTree).root.add_child(_panel)


func after_each() -> void:
	_panel.free()
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	Data.clear_cache()


func test_every_study_lever_has_a_slider() -> void:
	for l: Array in LEVERS:
		check(_panel.sliders.has("%s:%s" % l), "slider for %s %s" % l)


func test_every_entry_resolves_and_starts_inside_its_range() -> void:
	for e: Dictionary in Data.value("debug", "tuning"):
		if e.has("section"):
			continue
		var r := TuningPanel.resolve(String(e.file), String(e.path))
		if check(not r.is_empty(), "%s %s exists" % [e.file, e.path]):
			var v := float(r[0][r[1]])
			check(v >= float(e.min) and v <= float(e.max), "%s %.3f inside %.3f..%.3f" % [e.path, v, float(e.min), float(e.max)])


func test_slider_changes_the_live_number_and_save_round_trips() -> void:
	var slider: HSlider = _panel.sliders["player:turn.standing_deg_s"]
	slider.value = 175.0
	check_eq(float((Data.load_data("player") as Dictionary).turn.standing_deg_s), 175.0, "live data changed")
	var fine: HSlider = _panel.sliders["player:move.accel_s"]
	fine.value = 0.27
	var written := _panel.save()
	check_eq(Array(written), ["player"], "only the changed file is written")
	var text := FileAccess.get_file_as_string(TMP.path_join("player.json"))
	var back: Dictionary = JSON.parse_string(text)
	check_eq(float(back.turn.standing_deg_s), 175.0, "saved value")
	check(absf(float(back.move.accel_s) - 0.27) < 0.000001, "saved fine value")
	check(text.contains("\"accel_s\": 0.27"), "saved as a clean number, for a clean data diff")
	check_eq(Array(_panel.save()), [], "nothing left to save")
	# The rest of the file comes through unchanged.
	Data.clear_cache()
	var orig: Dictionary = Data.load_data("player")
	back.turn.standing_deg_s = orig.turn.standing_deg_s
	back.move.accel_s = orig.move.accel_s
	check_eq(JSON.stringify(back, "", true), JSON.stringify(orig, "", true), "other keys unchanged")


## The rig keeps a reference to the loaded camera data, so the follow slider works without touching src/camera.
func test_camera_follow_slider_reaches_the_rig() -> void:
	var rig: Node3D = preload("res://src/camera/camera_rig.gd").new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	(_panel.sliders["camera:follow.smoothing_hz"] as HSlider).value = 9.5
	check_eq(float(rig._follow.smoothing_hz), 9.5, "the rig sees the new follow rate")
	rig.free()
