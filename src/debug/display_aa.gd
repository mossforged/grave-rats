extends RefCounted
## The anti-aliasing modes in data/display.json: the 3D viewport's MSAA plus a screen-space pass (Godot
## 4.7 offers FXAA and SMAA). Env DISPLAY_AA overrides the saved mode at start, for frame-time pricing.

const FILE := "display"
const MSAA := {"2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X}
const SCREEN := {"off": Viewport.SCREEN_SPACE_AA_DISABLED, "fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}


static func modes() -> Array:
	return Data.value(FILE, "aa_modes", [])


static func starting_mode() -> String:
	var env := OS.get_environment("DISPLAY_AA")
	return env if env != "" else String(Data.value(FILE, "aa_mode"))


## Sets `viewport` to mode `id`, live. False, changing nothing, if there's no such mode.
static func apply(viewport: Viewport, id: String) -> bool:
	for mode: Dictionary in modes():
		if String(mode.id) == id:
			viewport.msaa_3d = MSAA[String(mode.msaa)]
			viewport.screen_space_aa = SCREEN[String(mode.screen_space)]
			return true
	push_warning("display: no aa mode %s" % id)
	return false


## The id of the mode `viewport` is in, "" if it's in none.
static func mode_of(viewport: Viewport) -> String:
	for mode: Dictionary in modes():
		if viewport.msaa_3d == MSAA[String(mode.msaa)] and viewport.screen_space_aa == SCREEN[String(mode.screen_space)]:
			return String(mode.id)
	return ""
