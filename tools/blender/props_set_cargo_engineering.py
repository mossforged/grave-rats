"""Prop sets 3 and 4: cargo hold and corridor/engineering (lead, Blender by script, 2026-10-31).

Run: python3 tools/blender/props_set_cargo_engineering.py [out_dir]   (pip install bpy)
Same conventions as tools/blender/props.py. Wall props have their back at the rear face.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"


# ---------------------------------------------------------------- cargo set

def pallet():
    """A steel cargo pallet with fork slots (clutter; walk over it). 1.2 x 0.15 x 1.0."""
    b = P.Builder("pallet")
    for x in (-0.5, 0, 0.5):
        b.box(x, 0, 0.05, 0.12, 1.0, 0.1, "steel", 0.008)
    for y in (-0.42, -0.14, 0.14, 0.42):
        b.box(0, y, 0.125, 1.2, 0.12, 0.03, "steel", 0.006)
    b.box(0.55, -0.45, 0.13, 0.08, 0.06, 0.012, "hazard", 0.0)
    return b.build()


def barrel():
    """A ribbed drum with a hazard band and a bung (low cover in groups). 0.6 dia x 0.9."""
    b = P.Builder("barrel")
    b.cyl(0, 0, 0.45, 0.28, 0.88, "z", "hull", 16)
    for z in (0.22, 0.68):
        b.cyl(0, 0, z, 0.29, 0.03, "z", "steel", 16)
    b.cyl(0, 0, 0.45, 0.285, 0.12, "z", "hazard", 16)
    b.cyl(0.12, 0, 0.9, 0.04, 0.02, "z", "steel", 8)
    return b.build()


def gas_rack():
    """Three gas bottles strapped in a frame (tall clutter; blocks sight). 0.9 x 1.6 x 0.4."""
    b = P.Builder("gas_rack")
    b.box(0, 0, 0.04, 0.9, 0.4, 0.08, "steel", 0.008)
    for x in (-0.43, 0.43):
        b.box(x, 0.15, 0.8, 0.04, 0.04, 1.6, "steel", 0.006)
    b.box(0, 0.15, 1.1, 0.9, 0.04, 0.04, "steel", 0.006)
    b.box(0, 0.15, 0.6, 0.9, 0.04, 0.04, "steel", 0.006)
    for x, m in ((-0.27, "hull"), (0, "hazard"), (0.27, "hull")):
        b.cyl(x, 0, 0.72, 0.12, 1.3, "z", m, 12)
        b.cyl(x, 0, 1.42, 0.05, 0.1, "z", "steel", 8)
        b.cyl(x, 0, 1.48, 0.025, 0.04, "z", "brass", 8)
    return b.build()


def shelving_rack():
    """Open shelving rack loaded with boxes (tall cover, see-through at the shelves in sight data
    if wanted). 2.0 x 2.2 x 0.6."""
    b = P.Builder("shelving_rack")
    L, h, d = 2.0, 2.2, 0.6
    for x in (-L / 2 + 0.03, 0, L / 2 - 0.03):
        for y in (-d / 2 + 0.03, d / 2 - 0.03):
            b.box(x, y, h / 2, 0.05, 0.05, h, "steel", 0.006)
    for z in (0.12, 0.8, 1.45, 2.1):
        b.box(0, 0, z, L, d, 0.04, "steel", 0.006)
        b.box(0, -d / 2 + 0.01, z + 0.02, L, 0.02, 0.06, "hazard", 0.0)
    boxes = [(-0.65, 0.3, 0.45, "hull"), (-0.15, 0.4, 0.35, "clinical"), (0.5, 0.5, 0.4, "hull"),
             (-0.5, 0.45, 0.3, "clinical"), (0.3, 0.3, 0.45, "hazard"), (-0.2, 0.5, 0.25, "hull")]
    for i, (x, w, hh, m) in enumerate(boxes):
        z = (0.14, 0.82, 1.47)[i % 3] + hh / 2
        b.box(x, 0, z, w, d * 0.75, hh, m, 0.012)
    return b.build()


def strapped_stack():
    """Two crates strapped on a pallet (tall cover). 1.2 x 1.5 x 1.0."""
    b = P.Builder("strapped_stack")
    b.box(0, 0, 0.06, 1.2, 1.0, 0.12, "steel", 0.008)
    b.box(0, 0, 0.42, 1.1, 0.92, 0.6, "hull", 0.02)
    b.box(0.05, 0, 1.06, 0.95, 0.82, 0.68, "hull", 0.02)
    for x in (-0.3, 0.3):
        b.box(x, 0, 0.75, 0.05, 1.0, 1.5, "hazard", 0.004)
    b.box(-0.2, -0.462, 0.5, 0.3, 0.004, 0.16, "clinical", 0.0)
    return b.build()


def cargo_lift():
    """A cargo lift platform with hazard edging and a control post (clutter; walkable).
    2.4 x 0.25 x 2.4 (post to 1.2)."""
    b = P.Builder("cargo_lift")
    b.box(0, 0, 0.06, 2.4, 2.4, 0.12, "steel", 0.01)
    for (cx, cy, sx, sy) in ((0, -1.17, 2.4, 0.06), (0, 1.17, 2.4, 0.06), (-1.17, 0, 0.06, 2.4), (1.17, 0, 0.06, 2.4)):
        b.box(cx, cy, 0.125, sx, sy, 0.012, "hazard", 0.0)
    for i in range(5):
        b.box(0, -0.8 + i * 0.4, 0.125, 2.0, 0.04, 0.01, "rubber", 0.0)
    b.box(1.05, -1.05, 0.65, 0.12, 0.12, 1.1, "steel", 0.01)
    b.box(1.05, -1.12, 1.05, 0.1, 0.02, 0.14, "emit_red", 0.0)
    return b.build()


# ---------------------------------------------------------------- corridor / engineering set (wall props)

def junction_box():
    """WALL: an electrical junction box with conduit and a warning plate. 0.5 x 0.6 x 0.18."""
    b = P.Builder("junction_box")
    b.box(0, 0.01, 0.3, 0.5, 0.16, 0.6, "steel", 0.012)
    b.box(0, -0.075, 0.3, 0.42, 0.012, 0.52, "hull", 0.006)
    b.box(0, -0.084, 0.48, 0.2, 0.004, 0.06, "hazard", 0.0)
    b.box(0.15, -0.084, 0.15, 0.04, 0.004, 0.03, "emit_red", 0.0)
    b.cyl(-0.15, 0.0, 0.66, 0.03, 0.12, "z", "steel", 8)
    return b.build()


def fuse_panel():
    """WALL: a breaker/fuse panel, half the breakers tripped. 0.7 x 0.9 x 0.15."""
    b = P.Builder("fuse_panel")
    b.box(0, 0.01, 0.45, 0.7, 0.13, 0.9, "steel", 0.012)
    for r in range(4):
        for c in range(5):
            m = "emit_red" if (r + c) % 3 == 0 else "clinical"
            b.box(-0.24 + c * 0.12, -0.062, 0.2 + r * 0.17, 0.06, 0.02, 0.1, m, 0.004)
    b.box(0, -0.06, 0.85, 0.5, 0.004, 0.05, "hazard", 0.0)
    return b.build()


def wall_terminal():
    """WALL: a small terminal (CUSTODIAN's lens lives on these), dark screen, keypad. 0.5 x 0.55 x 0.16."""
    b = P.Builder("wall_terminal")
    b.box(0, 0.01, 0.28, 0.5, 0.14, 0.55, "clinical", 0.012)
    b.box(0, -0.062, 0.36, 0.38, 0.006, 0.24, "glass", 0.0)
    b.box(0, -0.064, 0.36, 0.06, 0.004, 0.06, "emit_blue", 0.0)
    b.box(0, -0.06, 0.12, 0.3, 0.02, 0.1, "steel", 0.004)
    return b.build()


def pipe_valve():
    """WALL: a pipe run section with a handwheel valve and a gauge. 1.2 x 0.6 x 0.3."""
    b = P.Builder("pipe_valve")
    for z, r in ((0.15, 0.07), (0.42, 0.05)):
        b.cyl(0, 0.05, z, r, 1.2, "x", "steel", 12)
    b.cyl(0, 0.05, 0.15, 0.1, 0.18, "x", "brass", 12)
    b.cyl(0, -0.07, 0.15, 0.13, 0.02, "y", "emit_red", 16)  # handwheel (red)
    b.cyl(0.35, -0.03, 0.42, 0.06, 0.02, "y", "clinical", 12)  # gauge
    for x in (-0.5, 0.5):
        b.box(x, 0.12, 0.3, 0.06, 0.06, 0.55, "steel", 0.006)  # brackets
    return b.build()


def emergency_locker():
    """WALL: a red-trimmed emergency locker (oxygen, extinguisher). 0.6 x 1.2 x 0.3."""
    b = P.Builder("emergency_locker")
    b.box(0, 0.01, 0.6, 0.6, 0.28, 1.2, "clinical", 0.012)
    b.box(0, -0.135, 0.6, 0.52, 0.012, 1.1, "glass", 0.0)
    b.cyl(-0.12, -0.05, 0.45, 0.07, 0.6, "z", "emit_red", 12)  # extinguisher behind glass
    b.cyl(0.13, -0.05, 0.55, 0.08, 0.7, "z", "hull", 12)  # oxygen bottle
    b.box(0, -0.142, 1.12, 0.4, 0.004, 0.06, "emit_red", 0.0)
    return b.build()


def cable_spool():
    """A cable spool on its side (low cover). 0.9 dia x 0.7 wide."""
    b = P.Builder("cable_spool")
    for x in (-0.33, 0.33):
        b.cyl(x, 0, 0.45, 0.45, 0.05, "x", "steel", 16)
    b.cyl(0, 0, 0.45, 0.32, 0.62, "x", "rubber", 16)
    b.cyl(0, 0, 0.45, 0.12, 0.72, "x", "steel", 10)
    b.box(0.2, -0.32, 0.45, 0.12, 0.004, 0.08, "hazard", 0.0)
    return b.build()


def vent_cover():
    """FLOOR/WALL: a louvered vent cover (the stalker spawn points can use these). 0.8 x 0.06 x 0.6."""
    b = P.Builder("vent_cover")
    b.box(0, 0, 0.02, 0.8, 0.6, 0.04, "steel", 0.008)
    for i in range(7):
        b.box(0, -0.24 + i * 0.08, 0.045, 0.7, 0.03, 0.02, "steel", 0.002)
    b.box(0.34, -0.26, 0.045, 0.06, 0.04, 0.015, "hazard", 0.0)
    return b.build()


CARGO = [pallet, barrel, gas_rack, shelving_rack, strapped_stack, cargo_lift]
ENGINEERING = [junction_box, fuse_panel, wall_terminal, pipe_valve, emergency_locker, cable_spool, vent_cover]


def main():
    os.makedirs(OUT, exist_ok=True)
    P.reset()
    total = 0
    for f in CARGO + ENGINEERING:
        total += P.export(f(), OUT)
    print("total tris", total)
    P.reset()
    P.preview([f() for f in CARGO], os.path.join(OUT, "preview_cargo.png"))
    P.reset()
    P.preview([f() for f in ENGINEERING], os.path.join(OUT, "preview_engineering.png"))


if __name__ == "__main__":
    main()
