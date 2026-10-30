extends SceneTree
## One-off builder for the legacy pass-05 materials (mirrors docs/reference/dead-circuit-web/src/materials.js).
## Writes assets/game/legacy/materials/<name>.tres. The glb .import files bind them by slot name.
## Run: godot --headless --path . -s tools/godot/build_legacy_materials.gd

const TEX := "res://assets/game/legacy/tex/"
const OUT := "res://assets/game/legacy/materials/"
const PBR := ["suit_fabric", "paint_orange", "paint_white", "paint_yellow", "paint_hazard", "paint_robot",
	"rubber", "dark_metal", "floor_plate", "floor_grate", "wall_panel", "wall_med", "hull_top", "medical_fabric"]
## name: [color, emission energy]. char_* are the dimmer suit/robot status lights from characters.js.
const GLOW := {
	"light_cyan": [Color("5fe3ff"), 7.0], "light_amber": [Color("ff8a2a"), 7.0],
	"light_red": [Color("ff2a16"), 8.0], "light_white": [Color("dff3ff"), 6.5],
	"screen_cyan": [Color("2bc4d6"), 1.6],
	"char_cyan": [Color("5fe3ff"), 0.9], "char_amber": [Color("ff8a2a"), 0.9], "robot_eye_red": [Color("ff2a16"), 5.0],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for set_name in PBR:
		var m := ORMMaterial3D.new()
		m.resource_name = set_name
		m.albedo_texture = load(TEX + set_name + "_albedo.jpg")
		m.normal_enabled = true
		m.normal_texture = load(TEX + set_name + "_normal.jpg")
		m.orm_texture = load(TEX + set_name + "_orm.jpg")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_save(m, set_name)
	for n in GLOW:
		var g := StandardMaterial3D.new()
		g.resource_name = n
		g.albedo_color = Color("050505")
		g.roughness = 0.4
		g.metallic = 0.0
		g.emission_enabled = true
		g.emission = GLOW[n][0]
		g.emission_energy_multiplier = GLOW[n][1]
		_save(g, n)
	var visor := StandardMaterial3D.new()
	visor.resource_name = "visor"
	visor.albedo_color = Color("081014")
	visor.roughness = 0.12
	visor.metallic = 0.1
	visor.metallic_specular = 0.6
	visor.clearcoat_enabled = true
	visor.clearcoat = 0.6
	visor.clearcoat_roughness = 0.12
	_save(visor, "visor")
	var glass := StandardMaterial3D.new()
	glass.resource_name = "glass"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(Color("0d1b20"), 0.55)
	glass.roughness = 0.1
	glass.metallic = 0.0
	_save(glass, "glass")
	quit(0)


func _save(m: Material, n: String) -> void:
	var err := ResourceSaver.save(m, OUT + n + ".tres")
	print("%s -> %s" % [n, error_string(err)])
