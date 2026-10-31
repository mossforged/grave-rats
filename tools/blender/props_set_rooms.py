"""Room prop sets: engineering, bio lab, bridge, crew quarters, mess (lead, Blender by script).

Run: python3 tools/blender/props_set_rooms.py [out_dir]   (pip install bpy)
Same conventions as tools/blender/props.py (metres, base-centre origin, front +Z in glTF,
material slots named after data/kit.json materials). One preview pair per room.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"


# ---------------------------------------------------------------- engineering

def reactor_core():
    """The engineering centrepiece: a caged cylindrical core with a cool emissive band, coolant
    pipes and a hazard ring on the floor. Tall cover. 2.0 x 2.4 x 2.0."""
    b = P.Builder("reactor_core")
    b.cyl(0, 0, 0.06, 1.0, 0.12, "z", "steel", 24)
    b.cyl(0, 0, 0.125, 0.98, 0.012, "z", "hazard", 24)
    b.cyl(0, 0, 1.2, 0.6, 2.0, "z", "steel", 20)
    b.cyl(0, 0, 1.2, 0.62, 0.5, "z", "emit_blue", 20)
    for z in (0.5, 1.9):
        b.cyl(0, 0, z, 0.66, 0.08, "z", "brass", 20)
    b.cyl(0, 0, 2.3, 0.4, 0.2, "z", "steel", 16)
    for x, y in ((0.85, 0), (-0.85, 0), (0, 0.85), (0, -0.85)):
        b.box(x, y, 1.2, 0.06, 0.06, 2.2, "steel", 0.006)  # cage posts
    for x in (-0.75, 0.75):
        b.cyl(x, 0.55, 0.9, 0.07, 1.6, "z", "hull", 10)  # coolant risers
    return b.build()


def power_cell_rack():
    """A rack of power cells, some glowing, some dead. Tall cover. 1.2 x 1.8 x 0.5."""
    b = P.Builder("power_cell_rack")
    b.box(0, 0.02, 0.9, 1.2, 0.46, 1.8, "steel", 0.012)
    for r in range(3):
        for c in range(4):
            x = -0.42 + c * 0.28
            z = 0.35 + r * 0.55
            b.box(x, -0.2, z, 0.2, 0.08, 0.4, "hull", 0.01)
            m = "emit_blue" if (r * 4 + c) % 3 != 1 else "rubber"
            b.box(x, -0.245, z + 0.12, 0.12, 0.006, 0.05, m, 0.0)
    b.box(0, -0.22, 1.76, 1.0, 0.006, 0.05, "hazard", 0.0)
    return b.build()


def control_desk():
    """An engineering control desk: sloped panels approximated by stepped blocks, gauges, a big red
    shutdown button. Low cover. 1.8 x 1.1 x 0.8."""
    b = P.Builder("control_desk")
    b.box(0, 0.08, 0.4, 1.8, 0.64, 0.8, "steel", 0.015)
    b.box(0, -0.1, 0.85, 1.7, 0.4, 0.1, "clinical", 0.012)
    b.box(0, 0.12, 0.98, 1.7, 0.3, 0.2, "clinical", 0.012)
    for i in range(5):
        b.cyl(-0.6 + i * 0.3, 0.0, 1.085, 0.07, 0.012, "z", "glass", 12)  # gauges
    b.cyl(0.7, -0.2, 0.92, 0.06, 0.05, "z", "emit_red", 12)  # shutdown
    b.box(0.7, -0.2, 0.9, 0.18, 0.18, 0.012, "hazard", 0.0)
    for i in range(8):
        b.box(-0.7 + i * 0.12, -0.22, 0.91, 0.06, 0.06, 0.02, "steel", 0.004)  # switches
    return b.build()


def toolbox_cart():
    """A tool cart with drawers and a welder on top. Clutter. 0.8 x 1.0 x 0.5."""
    b = P.Builder("toolbox_cart")
    for x in (-0.33, 0.33):
        for y in (-0.18, 0.18):
            b.cyl(x, y, 0.04, 0.04, 0.03, "x", "rubber", 8)
    b.box(0, 0, 0.48, 0.78, 0.46, 0.72, "hull", 0.012)
    for i in range(4):
        b.box(0, -0.235, 0.22 + i * 0.16, 0.7, 0.012, 0.13, "hull", 0.006)
        b.box(0, -0.245, 0.25 + i * 0.16, 0.3, 0.01, 0.02, "steel", 0.004)
    b.box(0, 0, 0.86, 0.8, 0.48, 0.03, "steel", 0.006)
    b.box(0.15, 0.05, 0.95, 0.3, 0.2, 0.16, "hazard", 0.012)  # welder
    return b.build()


# ---------------------------------------------------------------- bio lab

def specimen_tank():
    """A tall specimen tank: glass cylinder with a dim green-blue glow, steel caps, cabling.
    Tall cover. 0.9 x 2.2 x 0.9."""
    b = P.Builder("specimen_tank")
    b.cyl(0, 0, 0.15, 0.45, 0.3, "z", "steel", 20)
    b.cyl(0, 0, 1.1, 0.38, 1.6, "z", "glass", 20)
    b.cyl(0, 0, 1.1, 0.3, 1.5, "z", "emit_blue", 16)  # the fluid glow (tunable in game)
    b.cyl(0, 0, 2.0, 0.45, 0.3, "z", "steel", 20)
    for x in (-0.3, 0.3):
        b.box(x, 0.3, 1.1, 0.05, 0.05, 1.7, "steel", 0.006)
    b.box(0, -0.42, 0.2, 0.2, 0.012, 0.08, "hazard", 0.0)
    return b.build()


def lab_bench():
    """A lab bench with a fume hood upstand, sample racks and a microscope block. Low cover.
    2.0 x 0.95 (hood to 1.9) x 0.75."""
    b = P.Builder("lab_bench")
    b.box(0, 0.02, 0.43, 2.0, 0.7, 0.86, "clinical", 0.012)
    b.box(0, 0.02, 0.88, 2.0, 0.75, 0.04, "steel", 0.008)  # worktop
    b.box(-0.55, 0.25, 1.4, 0.8, 0.25, 1.0, "clinical", 0.012)  # hood
    b.box(-0.55, 0.12, 1.4, 0.7, 0.01, 0.8, "glass", 0.0)
    for i in range(6):
        b.cyl(0.25 + i * 0.07, -0.1, 0.96, 0.02, 0.12, "z", "glass", 8)  # sample tubes
    b.box(0.45, -0.1, 0.92, 0.45, 0.1, 0.04, "steel", 0.004)
    b.box(0.75, 0.1, 1.02, 0.14, 0.2, 0.24, "hull", 0.01)  # microscope
    for i in range(3):
        b.box(-0.7 + i * 0.7, -0.335, 0.45, 0.6, 0.012, 0.6, "clinical", 0.006)
    return b.build()


def centrifuge():
    """A floor centrifuge with a lid and a status lamp. Clutter. 0.7 x 1.0 x 0.7."""
    b = P.Builder("centrifuge")
    b.box(0, 0, 0.45, 0.7, 0.7, 0.9, "clinical", 0.02)
    b.cyl(0, 0, 0.92, 0.28, 0.06, "z", "steel", 16)
    b.cyl(0, 0, 0.955, 0.22, 0.012, "z", "glass", 16)
    b.box(0.2, -0.351, 0.75, 0.14, 0.006, 0.06, "emit_blue", 0.0)
    return b.build()


def sample_freezer():
    """An upright sample freezer: frosted door, keypad, biohazard plate. Tall cover. 0.8 x 1.95 x 0.75."""
    b = P.Builder("sample_freezer")
    b.box(0, 0.015, 0.975, 0.8, 0.72, 1.95, "clinical", 0.02)
    b.box(0, -0.35, 1.0, 0.7, 0.012, 1.7, "clinical", 0.01)
    b.box(0.26, -0.362, 1.1, 0.03, 0.03, 0.4, "steel", 0.006)
    b.box(-0.2, -0.36, 1.6, 0.16, 0.008, 0.1, "emit_blue", 0.0)
    b.box(-0.2, -0.36, 1.35, 0.2, 0.006, 0.2, "hazard", 0.0)
    return b.build()


# ---------------------------------------------------------------- bridge

def captain_chair():
    """The command chair on a pedestal, armrest panels. Clutter. 0.9 x 1.3 x 0.9."""
    b = P.Builder("captain_chair")
    b.cyl(0, 0, 0.05, 0.4, 0.1, "z", "steel", 16)
    b.cyl(0, 0, 0.3, 0.1, 0.45, "z", "steel", 10)
    b.box(0, 0, 0.55, 0.62, 0.6, 0.12, "rubber", 0.03)
    b.box(0, 0.27, 0.95, 0.62, 0.12, 0.75, "rubber", 0.03)
    for x in (-0.38, 0.38):
        b.box(x, -0.02, 0.72, 0.12, 0.55, 0.08, "hull", 0.02)
        b.box(x, -0.18, 0.765, 0.08, 0.14, 0.012, "emit_blue", 0.0)
    return b.build()


def helm_console():
    """A curved helm console as three angled segments (straight blocks), screens and a throttle.
    Low cover. 2.4 x 1.05 x 0.9."""
    b = P.Builder("helm_console")
    for x, y in ((-0.8, 0.12), (0, 0), (0.8, 0.12)):
        b.box(x, y, 0.4, 0.78, 0.6, 0.8, "steel", 0.015)
        b.box(x, y - 0.05, 0.88, 0.74, 0.45, 0.08, "clinical", 0.012)
        b.box(x, y + 0.2, 0.98, 0.6, 0.06, 0.12, "glass", 0.006)
    b.box(0, -0.18, 0.95, 0.06, 0.1, 0.1, "hazard", 0.008)  # throttle
    b.box(0.8, -0.05, 0.93, 0.3, 0.2, 0.012, "emit_blue", 0.0)
    return b.build()


def nav_table():
    """A navigation table: a low plinth with a glowing chart surface. Low cover. 1.6 x 0.95 x 1.0."""
    b = P.Builder("nav_table")
    b.box(0, 0, 0.42, 1.4, 0.8, 0.84, "steel", 0.02)
    b.box(0, 0, 0.88, 1.6, 1.0, 0.08, "clinical", 0.015)
    b.box(0, 0, 0.925, 1.4, 0.8, 0.01, "emit_blue", 0.0)
    for x in (-0.7, 0.7):
        b.box(x, -0.45, 0.88, 0.12, 0.08, 0.1, "hazard", 0.006)
    return b.build()


def wall_screen_bank():
    """WALL: a bank of three dead/flickering screens. 2.0 x 0.9 x 0.12."""
    b = P.Builder("wall_screen_bank")
    b.box(0, 0.01, 0.45, 2.0, 0.1, 0.9, "steel", 0.012)
    for i, m in enumerate(("glass", "emit_blue", "glass")):
        b.box(-0.65 + i * 0.65, -0.045, 0.47, 0.58, 0.006, 0.72, m, 0.0)
    b.box(0, -0.048, 0.07, 1.8, 0.004, 0.05, "hazard", 0.0)
    return b.build()


# ---------------------------------------------------------------- crew quarters

def bunk_bed():
    """A double bunk with thin mattresses and a privacy curtain rail. Tall cover. 1.0 x 1.9 x 2.0."""
    b = P.Builder("bunk_bed")
    for x in (-0.47, 0.47):
        for y in (-0.97, 0.97):
            b.box(x, y, 0.95, 0.05, 0.05, 1.9, "steel", 0.006)
    for z in (0.35, 1.25):
        b.box(0, 0, z, 0.98, 1.98, 0.05, "steel", 0.008)
        b.box(0, 0, z + 0.07, 0.9, 1.9, 0.1, "hull", 0.03)
        b.box(0, 0.8, z + 0.15, 0.6, 0.25, 0.08, "clinical", 0.03)  # pillow
    b.box(-0.49, 0, 1.85, 0.02, 1.95, 0.02, "steel", 0.0)
    for i in range(4):  # ladder rungs
        b.box(0.5, -0.9, 0.4 + i * 0.25, 0.03, 0.03, 0.03, "steel", 0.0)
    return b.build()


def footlocker():
    """A footlocker with a stencilled name plate. Low clutter. 0.8 x 0.45 x 0.45."""
    b = P.Builder("footlocker")
    b.box(0, 0, 0.21, 0.8, 0.45, 0.42, "hull", 0.02)
    b.box(0, 0, 0.43, 0.82, 0.47, 0.04, "steel", 0.01)
    b.box(0, -0.226, 0.25, 0.3, 0.004, 0.08, "clinical", 0.0)
    for x in (-0.3, 0.3):
        b.box(x, -0.23, 0.36, 0.06, 0.012, 0.04, "steel", 0.004)
    return b.build()


def desk_chair():
    """A fold-down wall desk with a chair and a personal terminal. Clutter. 1.2 x 1.0 x 0.7."""
    b = P.Builder("desk_chair")
    b.box(0, 0.1, 0.74, 1.2, 0.5, 0.04, "hull", 0.008)
    for x in (-0.55, 0.55):
        b.box(x, 0.1, 0.37, 0.04, 0.45, 0.74, "steel", 0.006)
    b.box(0.25, 0.25, 0.9, 0.36, 0.04, 0.26, "glass", 0.006)
    b.box(-0.2, -0.2, 0.45, 0.42, 0.4, 0.06, "rubber", 0.02)  # chair seat
    b.box(-0.2, -0.38, 0.72, 0.42, 0.05, 0.5, "rubber", 0.02)
    b.cyl(-0.2, -0.2, 0.22, 0.03, 0.42, "z", "steel", 8)
    return b.build()


# ---------------------------------------------------------------- mess

def mess_table():
    """A bolted-down mess table with two benches. Low cover. 2.0 x 0.78 x 1.6."""
    b = P.Builder("mess_table")
    b.box(0, 0, 0.75, 2.0, 0.8, 0.05, "steel", 0.01)
    for x in (-0.8, 0.8):
        b.box(x, 0, 0.36, 0.08, 0.6, 0.72, "steel", 0.008)
    for y in (-0.65, 0.65):
        b.box(0, y, 0.44, 1.9, 0.3, 0.05, "hull", 0.01)
        for x in (-0.75, 0.75):
            b.box(x, y, 0.21, 0.06, 0.2, 0.42, "steel", 0.006)
    b.box(0.3, 0.1, 0.79, 0.3, 0.22, 0.03, "clinical", 0.006)  # a tray left behind
    return b.build()


def food_dispenser():
    """A meal dispenser: a payment slot (of course), a dispensing bay, a menu screen. Tall cover.
    1.0 x 2.0 x 0.6."""
    b = P.Builder("food_dispenser")
    b.box(0, 0.02, 1.0, 1.0, 0.56, 2.0, "hull", 0.02)
    b.box(0, -0.27, 1.45, 0.7, 0.01, 0.4, "glass", 0.0)
    b.box(0, -0.272, 1.45, 0.3, 0.006, 0.08, "emit_red", 0.0)  # "INSUFFICIENT FUNDS"
    b.box(0, -0.2, 0.85, 0.6, 0.16, 0.35, "steel", 0.01)  # dispensing bay
    b.box(0.32, -0.275, 1.1, 0.12, 0.012, 0.04, "hazard", 0.0)  # card slot
    b.box(0, -0.275, 1.85, 0.8, 0.004, 0.12, "clinical", 0.0)
    return b.build()


def galley_counter():
    """A galley counter with a sink, a hob and overhead cupboards. Low cover (cupboards are wall
    height). 2.4 x 0.95 (cupboards to 2.1) x 0.65."""
    b = P.Builder("galley_counter")
    b.box(0, 0.02, 0.45, 2.4, 0.6, 0.9, "clinical", 0.012)
    b.box(0, 0.02, 0.92, 2.4, 0.65, 0.04, "steel", 0.008)
    b.box(-0.6, 0.0, 0.92, 0.5, 0.4, 0.03, "rubber", 0.0)  # sink
    for x in (0.4, 0.7):
        for y in (-0.1, 0.12):
            b.cyl(x, y, 0.945, 0.1, 0.01, "z", "rubber", 12)  # hob rings
    b.box(0, 0.2, 1.75, 2.4, 0.3, 0.6, "clinical", 0.012)  # overhead cupboards
    for i in range(4):
        b.box(-0.9 + i * 0.6, 0.045, 1.75, 0.55, 0.012, 0.55, "clinical", 0.006)
        b.box(-0.9 + i * 0.6, 0.035, 1.55, 0.2, 0.012, 0.02, "steel", 0.004)
    return b.build()


ROOMS = {
    "engineering": [reactor_core, power_cell_rack, control_desk, toolbox_cart],
    "biolab": [specimen_tank, lab_bench, centrifuge, sample_freezer],
    "bridge": [captain_chair, helm_console, nav_table, wall_screen_bank],
    "quarters": [bunk_bed, footlocker, desk_chair],
    "mess": [mess_table, food_dispenser, galley_counter],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    P.reset()
    total = 0
    for fs in ROOMS.values():
        for f in fs:
            total += P.export(f(), OUT)
    print("total tris", total)
    for room, fs in ROOMS.items():
        P.reset()
        P.preview([f() for f in fs], os.path.join(OUT, f"preview_{room}.png"))


if __name__ == "__main__":
    main()
