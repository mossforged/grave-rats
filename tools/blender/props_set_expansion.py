"""Prop expansion (lead, Blender by script, 2026-10-31): hallway wall-depth set, plus a second
batch for every room type so each room has twice the props.

Run: python3 tools/blender/props_set_expansion.py [out_dir]   (pip install bpy)
Same conventions as tools/blender/props.py: metres, origin at the base centre, front faces +Z in
glTF (Blender -Y), width on X, material slots named after data/kit.json materials.

Two kinds of wall prop:
  role "wall"      - back at the rear face, origin at its own base: the game picks the height.
  role "wall_high" - origin ON THE FLOOR under the prop, mounting height baked in (walls are
                     2.6 m, data/deck.json wall_height_m). Pipes, ducts, cable trays, lintels.
Also writes the new entries into assets/source/props/catalogue.json.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"
WALL_H = 2.6


def bolts(b, xs, y, zs, r=0.014, m="steel"):
    for x in xs:
        for z in zs:
            b.cyl(x, y, z, r, 0.012, "y", m, 6)


# ================================================================ hallway: wall depth

def wall_rib():
    """Structural I-beam rib, floor to ceiling, with a knee bracket and a base gusset."""
    b = P.Builder("wall_rib")
    b.box(0, -0.09, WALL_H / 2, 0.32, 0.04, WALL_H, "steel", 0.006)
    b.box(0, 0.0, WALL_H / 2, 0.06, 0.16, WALL_H, "hull", 0.004)
    b.box(0, 0.09, WALL_H / 2, 0.32, 0.04, WALL_H, "steel", 0.006)
    b.box(0, -0.03, 0.2, 0.22, 0.12, 0.4, "steel", 0.008)
    b.box(0, -0.06, WALL_H - 0.2, 0.26, 0.16, 0.3, "steel", 0.008)
    b.box(0, -0.112, 0.75, 0.3, 0.006, 0.12, "hazard", 0.0)
    bolts(b, (-0.11, 0.11), -0.115, (0.1, 0.35, 1.3, 2.3))
    return b.build()


def wall_panel_recessed():
    """A 1.2 m wall bay: raised frame, recessed plate, mid rail, kick vent, corner bolts."""
    b = P.Builder("wall_panel_recessed")
    for z, sz in ((0.06, 0.12), (2.34, 0.12)):
        b.box(0, -0.02, z, 1.2, 0.1, sz, "clinical", 0.01)
    for x in (-0.55, 0.55):
        b.box(x, -0.02, 1.2, 0.1, 0.1, 2.4, "clinical", 0.01)
    b.box(0, 0.025, 1.2, 1.0, 0.03, 2.2, "hull", 0.004)
    b.box(0, -0.01, 1.35, 1.0, 0.06, 0.08, "clinical", 0.006)
    for i in range(5):
        b.box(0, 0.0, 0.25 + i * 0.07, 0.62, 0.03, 0.025, "steel", 0.002)
    b.box(0.3, 0.005, 1.9, 0.22, 0.01, 0.1, "hazard", 0.0)
    bolts(b, (-0.55, 0.55), -0.072, (0.06, 2.34))
    return b.build()


def wall_panel_breached():
    """The same bay with its plate torn off: pipes and cables exposed, the plate on the floor."""
    b = P.Builder("wall_panel_breached")
    for z, sz in ((0.06, 0.12), (2.34, 0.12)):
        b.box(0, -0.02, z, 1.2, 0.1, sz, "clinical", 0.01)
    for x in (-0.55, 0.55):
        b.box(x, -0.02, 1.2, 0.1, 0.1, 2.4, "clinical", 0.01)
    b.box(0, 0.045, 1.2, 1.0, 0.01, 2.2, "rubber", 0.0)  # dark cavity back
    for x, r, m in ((-0.3, 0.05, "steel"), (-0.12, 0.035, "brass"), (0.25, 0.06, "hull")):
        b.cyl(x, 0.0, 1.2, r, 2.2, "z", m, 10)
    for x, m in ((0.05, "rubber"), (0.1, "hazard"), (0.4, "rubber")):
        b.cyl(x, -0.01, 1.4, 0.016, 1.9, "z", m, 6)
    b.cyl(0.33, -0.12, 0.55, 0.016, 0.7, "z", "rubber", 6, rot=(25, 0, 0))  # torn cable
    b.box(0.33, -0.27, 0.22, 0.03, 0.03, 0.03, "emit_blue", 0.0)  # sparking end
    b.box(0.05, -0.05, 2.1, 0.9, 0.03, 0.18, "hull", 0.004)  # strip of plate still bolted
    b.box(-0.1, -0.33, 0.45, 0.95, 0.03, 1.0, "hull", 0.006, rot=(-28, 0, 4))  # plate leaning
    return b.build()


def pipe_run_low():
    """Three pipes along the wall base on brackets, a flange joint and a hand valve. Low."""
    b = P.Builder("pipe_run_low")
    for z, y, r, m in ((0.16, -0.02, 0.07, "hull"), (0.33, 0.0, 0.045, "steel"), (0.45, 0.04, 0.03, "brass")):
        b.cyl(0, y, z, r, 2.0, "x", m, 12)
    b.cyl(0.25, -0.02, 0.16, 0.095, 0.06, "x", "steel", 12)
    b.cyl(0.25, -0.02, 0.16, 0.085, 0.14, "x", "hazard", 12)
    for x in (-0.8, 0.8):
        b.box(x, 0.02, 0.27, 0.06, 0.2, 0.54, "steel", 0.006)
    b.cyl(-0.4, 0.0, 0.42, 0.012, 0.12, "z", "steel", 6)
    b.cyl(-0.4, 0.0, 0.49, 0.055, 0.015, "z", "emit_red", 12)
    return b.build()


def pipe_run_high():
    """WALL_HIGH: a pipe bundle near the ceiling on wall arms, with a drip pipe down."""
    b = P.Builder("pipe_run_high")
    for z, y, r, m in ((2.15, -0.12, 0.06, "steel"), (2.3, -0.03, 0.08, "hull"), (2.45, -0.12, 0.04, "brass")):
        b.cyl(0, y, z, r, 2.0, "x", m, 12)
    for x in (-0.75, 0.75):
        b.box(x, -0.06, 2.3, 0.05, 0.26, 0.05, "steel", 0.004)
        b.box(x, 0.06, 2.3, 0.05, 0.04, 0.4, "steel", 0.004)
    b.cyl(0.55, -0.12, 1.8, 0.02, 0.7, "z", "steel", 8)
    b.cyl(0.55, -0.12, 1.45, 0.03, 0.04, "z", "brass", 8)
    return b.build()


def conduit_tray():
    """WALL_HIGH: a cable tray full of cables at ceiling height; one loop sags out."""
    b = P.Builder("conduit_tray")
    b.box(0, -0.09, 2.2, 2.0, 0.3, 0.02, "steel", 0.004)
    b.box(0, -0.235, 2.24, 2.0, 0.01, 0.08, "steel", 0.002)
    for x in (-0.85, 0.85):
        b.box(x, -0.09, 2.38, 0.04, 0.3, 0.03, "steel", 0.003)
        b.box(x, 0.05, 2.3, 0.04, 0.03, 0.2, "steel", 0.003)
    for y, r, m in ((-0.2, 0.03, "rubber"), (-0.15, 0.022, "hazard"), (-0.1, 0.035, "rubber"),
                    (-0.04, 0.025, "hull"), (0.02, 0.03, "rubber")):
        b.cyl(0, y, 2.21 + r, r, 2.0, "x", m, 8)
    # sag: three segments hanging out of the tray between x 0.2 and 0.7
    b.cyl(0.27, -0.24, 2.05, 0.022, 0.38, "z", "rubber", 8, rot=(0, 28, 0))
    b.cyl(0.45, -0.24, 1.88, 0.022, 0.22, "x", "rubber", 8)
    b.cyl(0.63, -0.24, 2.05, 0.022, 0.38, "z", "rubber", 8, rot=(0, -28, 0))
    return b.build()


def air_duct():
    """WALL_HIGH: a square air duct along the wall top, seam collars, an underside grille."""
    b = P.Builder("air_duct")
    b.box(0, -0.2, 2.3, 2.0, 0.44, 0.42, "hull", 0.02)
    for x in (-0.66, 0.0, 0.66):
        b.box(x, -0.2, 2.3, 0.05, 0.47, 0.45, "steel", 0.008)
    for i in range(6):
        b.box(0.4, -0.38 + i * 0.07, 2.085, 0.4, 0.035, 0.02, "steel", 0.002)
    b.box(-0.35, -0.425, 2.3, 0.3, 0.005, 0.1, "hazard", 0.0)
    for x in (-0.9, 0.9):
        b.box(x, 0.04, 2.3, 0.04, 0.04, 0.5, "steel", 0.003)
    return b.build()


def wall_light_strip():
    """WALL: a caged strip light (cool). 1.0 x 0.18 x 0.12; the game sets the height."""
    b = P.Builder("wall_light_strip")
    b.box(0, 0.03, 0.09, 1.0, 0.06, 0.18, "steel", 0.008)
    b.box(0, -0.02, 0.09, 0.86, 0.04, 0.08, "emit_cool", 0.006)
    for x in (-0.35, -0.12, 0.12, 0.35):
        b.box(x, -0.05, 0.09, 0.015, 0.02, 0.16, "steel", 0.002)
    b.box(0, -0.05, 0.09, 0.9, 0.02, 0.015, "steel", 0.002)
    for x in (-0.47, 0.47):
        b.box(x, -0.01, 0.09, 0.06, 0.1, 0.18, "hazard", 0.004)
    return b.build()


def emergency_lamp():
    """WALL: a caged red emergency lamp. 0.24 x 0.3 x 0.2."""
    b = P.Builder("emergency_lamp")
    b.box(0, 0.08, 0.15, 0.24, 0.04, 0.3, "steel", 0.006)
    b.cyl(0, -0.01, 0.15, 0.085, 0.14, "y", "emit_red", 12)
    for z in (0.07, 0.15, 0.23):
        b.box(0, -0.06, z, 0.2, 0.06, 0.012, "steel", 0.002)
    b.box(0, -0.085, 0.15, 0.012, 0.012, 0.18, "steel", 0.002)
    return b.build()


def door_jamb():
    """A thick door jamb with hazard chevron bands and a keypad. Pairs with door_lintel."""
    b = P.Builder("door_jamb")
    b.box(0, 0, WALL_H / 2, 0.34, 0.3, WALL_H, "steel", 0.012)
    for i in range(10):
        m = "hazard" if i % 2 == 0 else "rubber"
        b.box(0.07, -0.153, 0.06 + i * 0.12, 0.16, 0.008, 0.12, m, 0.0)
    b.box(-0.05, -0.155, 1.25, 0.12, 0.02, 0.18, "clinical", 0.004)
    b.box(-0.05, -0.167, 1.29, 0.06, 0.004, 0.04, "emit_blue", 0.0)
    b.box(0, -0.13, WALL_H - 0.12, 0.3, 0.06, 0.24, "hull", 0.006)
    return b.build()


def door_lintel():
    """WALL_HIGH: the header block over a door (2.2-2.6 m) with status lamps and a deck plate."""
    b = P.Builder("door_lintel")
    b.box(0, -0.02, 2.4, 2.0, 0.3, 0.4, "steel", 0.012)
    b.box(0, -0.175, 2.4, 1.6, 0.02, 0.24, "hull", 0.004)
    b.box(0, -0.19, 2.42, 0.5, 0.01, 0.12, "clinical", 0.0)
    for x, m in ((-0.6, "emit_red"), (0.6, "emit_blue")):
        b.box(x, -0.19, 2.42, 0.1, 0.02, 0.06, m, 0.0)
    b.box(0, -0.175, 2.215, 2.0, 0.02, 0.03, "hazard", 0.0)
    return b.build()


def corner_pillar():
    """An inner-corner column: chamfered guard, vertical pipe, hazard bands. Sits in a corner."""
    b = P.Builder("corner_pillar")
    b.box(0, 0, WALL_H / 2, 0.4, 0.4, WALL_H, "hull", 0.01)
    b.box(-0.13, -0.13, WALL_H / 2, 0.16, 0.16, WALL_H - 0.1, "steel", 0.006, rot=(0, 0, 45))
    for z in (0.45, 1.5):
        b.box(-0.13, -0.13, z, 0.18, 0.18, 0.2, "hazard", 0.004, rot=(0, 0, 45))
    b.cyl(0.12, -0.24, WALL_H / 2, 0.035, WALL_H, "z", "brass", 8)
    return b.build()


def handrail():
    """WALL: a grab rail on three stand-offs at 1.0 m, worn sleeve in the middle."""
    b = P.Builder("handrail")
    b.cyl(0, -0.08, 1.0, 0.022, 2.0, "x", "steel", 10)
    b.cyl(0, -0.08, 1.0, 0.028, 0.4, "x", "rubber", 10)
    for x in (-0.9, 0.0, 0.9):
        b.cyl(x, -0.03, 1.0, 0.014, 0.1, "y", "steel", 8)
        b.box(x, 0.01, 1.0, 0.08, 0.02, 0.12, "steel", 0.004)
    return b.build()


def floor_grate():
    """A floor grate (walk over it): frame, slats, a pipe showing through the gaps."""
    b = P.Builder("floor_grate")
    b.box(0, 0, 0.004, 1.15, 1.15, 0.008, "rubber", 0.0)
    b.cyl(0, 0.15, 0.02, 0.016, 1.1, "x", "hull", 8)
    for x, y, sx, sy in ((0, -0.57, 1.2, 0.06), (0, 0.57, 1.2, 0.06), (-0.57, 0, 0.06, 1.2), (0.57, 0, 0.06, 1.2)):
        b.box(x, y, 0.025, sx, sy, 0.05, "steel", 0.004)
    for i in range(10):
        b.box(0, -0.48 + i * 0.107, 0.035, 1.1, 0.04, 0.03, "steel", 0.002)
    b.box(0.5, -0.5, 0.051, 0.08, 0.08, 0.004, "hazard", 0.0)
    return b.build()


def kick_plate():
    """WALL: a dented steel kick plate along the wall foot with a hazard top edge. 2.0 x 0.3."""
    b = P.Builder("kick_plate")
    b.box(-0.55, 0, 0.15, 0.9, 0.05, 0.3, "steel", 0.006)
    b.box(0.5, -0.005, 0.15, 1.0, 0.05, 0.3, "steel", 0.006, rot=(0, 0, 2.5))  # buckled section
    b.box(0, -0.03, 0.29, 2.0, 0.02, 0.03, "hazard", 0.0)
    bolts(b, (-0.95, -0.1, 0.95), -0.03, (0.08, 0.22))
    return b.build()


def wall_sign_arrow():
    """WALL: a direction plate with a raised chevron arrow. 0.6 x 0.35. Text goes on as decals."""
    b = P.Builder("wall_sign_arrow")
    b.box(0, 0, 0.175, 0.6, 0.02, 0.35, "clinical", 0.004)
    b.box(0, -0.012, 0.175, 0.56, 0.004, 0.31, "hull", 0.0)
    for z, a in ((0.225, 33.7), (0.125, -33.7)):
        b.box(0.125, -0.018, z, 0.2, 0.01, 0.045, "hazard", 0.0, rot=(0, a, 0))
    b.box(-0.03, -0.018, 0.175, 0.36, 0.01, 0.045, "hazard", 0.0)
    return b.build()


def maintenance_hatch():
    """WALL: a low maintenance hatch with a wheel lock and a hazard border. 0.8 x 0.9 x 0.14."""
    b = P.Builder("maintenance_hatch")
    b.box(0, 0.02, 0.45, 0.8, 0.08, 0.9, "steel", 0.012)
    b.box(0, -0.035, 0.45, 0.66, 0.04, 0.76, "hull", 0.01)
    b.cyl(0, -0.065, 0.45, 0.13, 0.02, "y", "steel", 16)
    b.cyl(0, -0.065, 0.45, 0.1, 0.025, "y", "hull", 16)
    for a in (0, 60, 120):
        b.box(0, -0.07, 0.45, 0.24, 0.02, 0.02, "steel", 0.002, rot=(0, a, 0))
    for z in (0.03, 0.87):
        b.box(0, -0.025, z, 0.8, 0.01, 0.04, "hazard", 0.0)
    return b.build()


def fire_hose_reel():
    """WALL: an open fire hose cabinet, reel and nozzle. 0.6 x 0.7 x 0.25."""
    b = P.Builder("fire_hose_reel")
    b.box(0, 0.11, 0.35, 0.6, 0.03, 0.7, "clinical", 0.006)
    for x in (-0.285, 0.285):
        b.box(x, 0.0, 0.35, 0.03, 0.25, 0.7, "clinical", 0.006)
    for z in (0.015, 0.685):
        b.box(0, 0.0, z, 0.6, 0.25, 0.03, "clinical", 0.006)
    b.cyl(0, 0.0, 0.38, 0.22, 0.16, "y", "hazard", 16)
    b.cyl(0, -0.02, 0.38, 0.06, 0.22, "y", "steel", 10)
    b.cyl(0.2, -0.08, 0.12, 0.025, 0.16, "z", "brass", 8)
    b.box(0, -0.125, 0.66, 0.4, 0.004, 0.04, "emit_red", 0.0)
    return b.build()


def debris_pile():
    """Clutter: a fallen ceiling panel, a snapped pipe, a cable tangle and a dead light."""
    b = P.Builder("debris_pile")
    b.box(-0.15, 0.0, 0.14, 1.0, 0.7, 0.03, "hull", 0.006, rot=(12, 6, 22))
    b.cyl(0.35, -0.2, 0.06, 0.06, 0.9, "x", "steel", 10, rot=(0, 4, -30))
    b.cyl(0.35, -0.2, 0.06, 0.07, 0.05, "x", "steel", 10, rot=(0, 4, -30))
    for i, (x, y, a) in enumerate(((-0.4, 0.3, 20), (-0.2, 0.25, 70), (0.1, 0.35, 140), (0.3, 0.2, 100))):
        b.cyl(x, y, 0.025, 0.018, 0.5, "x", "rubber" if i % 2 else "hazard", 6, rot=(0, 0, a))
    b.box(-0.45, -0.3, 0.05, 0.5, 0.15, 0.08, "steel", 0.006, rot=(0, 0, -15))
    b.box(-0.45, -0.38, 0.05, 0.4, 0.02, 0.03, "emit_cool", 0.0, rot=(0, 0, -15))
    for x, y in ((0.55, 0.3), (0.62, 0.2), (-0.6, 0.05), (0.1, -0.35)):
        b.box(x, y, 0.02, 0.06, 0.05, 0.04, "steel", 0.004, rot=(0, 0, x * 90))
    return b.build()


def hanging_cables():
    """WALL_HIGH: cables spilling from a broken ceiling tile by the wall; one end sparks."""
    b = P.Builder("hanging_cables")
    b.box(0, -0.15, WALL_H - 0.02, 0.6, 0.3, 0.04, "steel", 0.004)  # torn ceiling hatch frame
    b.box(0, -0.15, WALL_H - 0.03, 0.5, 0.2, 0.02, "rubber", 0.0)
    for x, ln, m, tilt in ((-0.2, 0.9, "rubber", 6), (-0.05, 1.1, "hazard", -4), (0.1, 0.75, "rubber", 10),
                           (0.22, 1.0, "rubber", -8)):
        b.cyl(x, -0.12, WALL_H - ln / 2, 0.018, ln, "z", m, 6, rot=(tilt, 0, 0))
    b.box(-0.05, -0.08, WALL_H - 1.12, 0.04, 0.04, 0.04, "emit_blue", 0.0)
    return b.build()


# ================================================================ medbay, batch 2

def cryo_pod():
    """A frosted cryo pod with something vaguely person-shaped inside. Tall cover."""
    b = P.Builder("cryo_pod")
    b.cyl(0, 0, 0.1, 0.45, 0.2, "z", "steel", 20)
    b.cyl(0, 0, 1.0, 0.38, 1.6, "z", "glass", 20)
    b.box(0, 0.02, 0.95, 0.3, 0.2, 1.4, "hull", 0.08)  # occupant (do not look too closely)
    b.cyl(0, 0, 0.25, 0.4, 0.06, "z", "emit_cool", 20)
    b.cyl(0, 0, 1.93, 0.45, 0.26, "z", "steel", 20)
    b.box(0, -0.42, 0.13, 0.3, 0.06, 0.14, "clinical", 0.004)
    b.box(0, -0.452, 0.14, 0.12, 0.004, 0.05, "emit_red", 0.0)
    b.cyl(0.25, 0.38, 1.0, 0.03, 1.8, "z", "rubber", 8)
    return b.build()


def scrub_sink():
    """WALL: a steel scrub trough with knee pedals and a splashback. 1.2 x 1.2 x 0.55."""
    b = P.Builder("scrub_sink")
    b.box(0, 0.24, 0.75, 1.2, 0.04, 0.9, "clinical", 0.006)
    b.box(0, -0.02, 0.82, 1.2, 0.5, 0.2, "steel", 0.012)
    b.box(0, -0.04, 0.9, 1.08, 0.38, 0.06, "rubber", 0.0)  # basin hollow
    for x in (-0.3, 0.3):
        b.cyl(x, 0.15, 1.05, 0.015, 0.25, "z", "steel", 8)
        b.cyl(x, 0.08, 1.17, 0.015, 0.15, "y", "steel", 8)
        b.box(x, -0.2, 0.25, 0.12, 0.04, 0.08, "rubber", 0.004)
    b.box(0, 0.1, 0.36, 0.08, 0.25, 0.72, "steel", 0.006)
    return b.build()


def privacy_screen():
    """A three-panel folding screen on castors, panels zig-zagged. Clutter."""
    b = P.Builder("privacy_screen")
    for x, y, a in ((-0.5, -0.08, 25), (0, 0, 0), (0.5, -0.08, -25)):
        b.box(x, y, 0.98, 0.5, 0.03, 1.6, "steel", 0.006, rot=(0, 0, a))
        b.box(x, y, 1.0, 0.44, 0.04, 1.45, "clinical", 0.004, rot=(0, 0, a))
        b.cyl(x - 0.2, y, 0.06, 0.03, 0.03, "x", "rubber", 8)
        b.cyl(x + 0.2, y, 0.06, 0.03, 0.03, "x", "rubber", 8)
    return b.build()


def defib_cart():
    """A crash cart: drawers, a defib unit on top with a red screen, paddles. Clutter."""
    b = P.Builder("defib_cart")
    b.box(0, 0, 0.5, 0.6, 0.45, 0.8, "clinical", 0.012)
    for i in range(4):
        b.box(0, -0.228, 0.22 + i * 0.18, 0.54, 0.01, 0.15, "hull", 0.004)
        b.box(0, -0.236, 0.27 + i * 0.18, 0.2, 0.01, 0.02, "steel", 0.0)
    b.box(0, 0.02, 0.98, 0.42, 0.34, 0.16, "steel", 0.012)
    b.box(-0.06, -0.152, 1.0, 0.2, 0.006, 0.1, "emit_red", 0.0)
    for x in (0.12, 0.2):
        b.cyl(x, -0.08, 1.08, 0.035, 0.07, "z", "hazard", 10)
    for x in (-0.25, 0.25):
        for y in (-0.18, 0.18):
            b.cyl(x, y, 0.05, 0.05, 0.04, "x", "rubber", 10)
    return b.build()


def biohazard_bin():
    """A pedal bin for biohazard waste. Clutter."""
    b = P.Builder("biohazard_bin")
    b.cyl(0, 0, 0.32, 0.2, 0.6, "z", "hazard", 16)
    b.cyl(0, 0, 0.64, 0.21, 0.05, "z", "steel", 16)
    b.cyl(0, 0, 0.02, 0.21, 0.04, "z", "steel", 16)
    b.box(0, -0.22, 0.03, 0.14, 0.08, 0.03, "steel", 0.004)
    b.box(0, -0.2, 0.35, 0.12, 0.004, 0.12, "rubber", 0.0)
    return b.build()


def body_bag():
    """A zipped body bag on the floor with a toe tag. Clutter. It is a horror game."""
    b = P.Builder("body_bag")
    b.box(0, 0.0, 0.1, 0.55, 1.8, 0.2, "rubber", 0.08)
    b.box(0, -0.7, 0.13, 0.36, 0.3, 0.12, "rubber", 0.06)
    b.box(0, 0.0, 0.205, 0.025, 1.7, 0.01, "steel", 0.0)
    b.box(0.08, 0.92, 0.12, 0.08, 0.004, 0.05, "clinical", 0.0, rot=(0, 0, 20))
    return b.build()


# ================================================================ cargo, batch 2

def _crate(b, x, y, z, w, h, d, rot=None, m="hull"):
    b.box(x, y, z, w, d, h, m, 0.02, rot=rot)
    b.box(x, y, z, w + 0.02, d + 0.02, 0.06, "steel", 0.006, rot=rot)


def crate_pile_tipped():
    """Two crates upright, a third tipped against them. Low cover."""
    b = P.Builder("crate_pile_tipped")
    _crate(b, -0.45, 0.1, 0.35, 0.8, 0.7, 0.8)
    _crate(b, 0.35, 0.15, 0.3, 0.6, 0.6, 0.6, m="clinical")
    _crate(b, 0.3, -0.35, 0.3, 0.7, 0.5, 0.5, rot=(0, 20, 12))
    b.box(-0.45, -0.31, 0.45, 0.3, 0.004, 0.16, "hazard", 0.0)
    return b.build()


def container_section():
    """The open end of a shipping container: ribbed walls, doors swung back, lock bars. Tall cover."""
    b = P.Builder("container_section")
    W, H, D = 2.4, 2.4, 1.2
    for x in (-W / 2 + 0.03, W / 2 - 0.03):
        b.box(x, 0, H / 2, 0.06, D, H, "hull", 0.006)
        for i in range(6):
            b.box(x * 1.02, -D / 2 + 0.1 + i * 0.2, H / 2, 0.04, 0.08, H - 0.1, "hull", 0.004)
    b.box(0, 0, H - 0.03, W, D, 0.06, "hull", 0.006)
    b.box(0, D / 2 - 0.03, H / 2, W, 0.06, H, "rubber", 0.0)
    for x in (-W / 2, W / 2):
        b.box(x, -D / 2, H / 2, 0.12, 0.12, H, "steel", 0.01)
        b.box(x, -D / 2, 0.15, 0.13, 0.13, 0.3, "hazard", 0.004)
    for x in (-W / 2 + 0.16, W / 2 - 0.16):
        b.cyl(x, -D / 2 - 0.02, H / 2, 0.025, H - 0.2, "z", "steel", 8)
    b.box(0, -D / 2 + 0.05, 0.05, W - 0.2, 0.08, 0.1, "steel", 0.006)
    return b.build()


def pallet_jack():
    """A manual pallet jack: forks, hydraulic body, angled tiller. Clutter."""
    b = P.Builder("pallet_jack")
    for x in (-0.2, 0.2):
        b.box(x, 0.2, 0.05, 0.16, 1.2, 0.07, "steel", 0.006)
        b.cyl(x, 0.75, 0.03, 0.03, 0.08, "x", "rubber", 8)
    b.box(0, -0.45, 0.2, 0.56, 0.2, 0.3, "hazard", 0.012)
    b.cyl(0, -0.45, 0.06, 0.07, 0.3, "x", "rubber", 12)
    b.cyl(0, -0.62, 0.7, 0.025, 1.0, "z", "steel", 8, rot=(-22, 0, 0))
    b.box(0, -0.8, 1.15, 0.4, 0.05, 0.05, "rubber", 0.006)
    return b.build()


def tarp_pile():
    """Something under a tarp, strapped down. Low cover. Probably just cargo."""
    b = P.Builder("tarp_pile")
    b.box(-0.2, 0.05, 0.4, 1.1, 0.95, 0.8, "hull", 0.18)
    b.box(0.35, -0.1, 0.32, 0.8, 0.8, 0.64, "hull", 0.16, rot=(0, 0, 10))
    b.box(-0.35, 0.2, 0.86, 0.5, 0.5, 0.25, "hull", 0.1, rot=(0, 8, 0))
    for x in (-0.45, 0.25):
        b.box(x, 0.0, 0.42, 0.06, 1.05, 0.86, "hazard", 0.01)
    return b.build()


def cargo_net_wall():
    """WALL: boxes held against the wall under a cargo net. 2.0 x 1.7 x 0.55."""
    b = P.Builder("cargo_net_wall")
    for x, w, h, m in ((-0.6, 0.7, 0.9, "hull"), (0.15, 0.7, 0.7, "clinical"), (0.75, 0.45, 1.1, "hull"),
                       (-0.55, 0.6, 0.6, "clinical")):
        z = h / 2 if m == "hull" or x > 0 else 0.9 + h / 2
        b.box(x, 0.0, z, w, 0.48, h, m, 0.02)
    for z in (0.3, 0.7, 1.1, 1.5):
        b.cyl(0, -0.26, z, 0.01, 2.0, "x", "rubber", 6)
    for x in (-0.9, -0.5, -0.1, 0.3, 0.7):
        b.cyl(x, -0.26, 0.85, 0.01, 1.7, "z", "rubber", 6)
    for x in (-0.98, 0.98):
        for z in (0.1, 1.6):
            b.box(x, -0.2, z, 0.06, 0.1, 0.06, "hazard", 0.004)
    return b.build()


def manifest_terminal():
    """A post-mounted manifest terminal with a tilted screen and a holstered scanner. Clutter."""
    b = P.Builder("manifest_terminal")
    b.box(0, 0, 0.03, 0.4, 0.4, 0.06, "steel", 0.006)
    b.box(0, 0, 0.6, 0.1, 0.1, 1.1, "hazard", 0.006)
    b.box(0, -0.05, 1.22, 0.36, 0.08, 0.28, "steel", 0.01, rot=(-30, 0, 0))
    b.box(0, -0.1, 1.24, 0.3, 0.01, 0.2, "emit_blue", 0.0, rot=(-30, 0, 0))
    b.box(0.1, -0.08, 0.85, 0.06, 0.08, 0.16, "rubber", 0.006)
    return b.build()


# ================================================================ engineering, batch 2

def coolant_pump():
    """A horizontal coolant pump: tank, motor, risers, gauge. Low cover."""
    b = P.Builder("coolant_pump")
    b.box(0, 0, 0.08, 1.6, 0.8, 0.16, "steel", 0.01)
    b.cyl(-0.25, 0, 0.5, 0.33, 0.9, "x", "hull", 18)
    b.cyl(0.5, 0, 0.45, 0.24, 0.5, "x", "steel", 14)
    b.cyl(0.2, 0, 0.5, 0.36, 0.06, "x", "hazard", 18)
    for x in (-0.5, -0.05):
        b.cyl(x, 0.1, 0.9, 0.06, 0.3, "z", "brass", 10)
    b.cyl(-0.3, -0.33, 0.7, 0.07, 0.02, "y", "clinical", 12)
    b.box(0.5, -0.25, 0.68, 0.12, 0.004, 0.06, "emit_cool", 0.0)
    return b.build()


def transformer():
    """A caged step-down transformer: cooling fins, insulators, warning lamp. Tall cover."""
    b = P.Builder("transformer")
    b.box(0, 0, 0.85, 1.0, 0.6, 1.7, "hull", 0.015)
    for x in (-0.53, 0.53):
        for i in range(7):
            b.box(x, -0.24 + i * 0.08, 0.85, 0.06, 0.02, 1.4, "steel", 0.002)
    for x in (-0.3, 0.0, 0.3):
        for i in range(3):
            b.cyl(x, 0, 1.75 + i * 0.07, 0.07 - i * 0.012, 0.05, "z", "clinical", 10)
        b.cyl(x, 0, 1.97, 0.02, 0.06, "z", "brass", 6)
    for x in (-0.36, -0.12, 0.12, 0.36):
        b.box(x, -0.33, 0.85, 0.02, 0.02, 1.5, "steel", 0.002)
    b.box(0, -0.31, 1.3, 0.4, 0.004, 0.2, "hazard", 0.0)
    b.cyl(0.38, -0.31, 1.55, 0.04, 0.04, "y", "emit_red", 10)
    return b.build()


def catwalk_section():
    """A raised grated walkway with railings both sides (walkable; rails block side entry)."""
    b = P.Builder("catwalk_section")
    L = 2.4
    b.box(0, 0, 0.1, 1.2, L, 0.04, "steel", 0.004)
    for i in range(12):
        b.box(0, -L / 2 + 0.1 + i * 0.2, 0.125, 1.1, 0.04, 0.01, "steel", 0.0)
    for x in (-0.58, 0.58):
        for y in (-L / 2 + 0.05, 0, L / 2 - 0.05):
            b.box(x, y, 0.6, 0.04, 0.04, 1.0, "steel", 0.004)
            b.box(x, y, 0.05, 0.08, 0.08, 0.1, "steel", 0.004)
        b.cyl(x, 0, 1.1, 0.02, L, "y", "hazard", 8)
        b.cyl(x, 0, 0.6, 0.015, L, "y", "steel", 8)
    return b.build()


def workbench():
    """A workbench with a vise, a lower shelf and a pegboard of tools. Low cover."""
    b = P.Builder("workbench")
    b.box(0, 0, 0.9, 1.8, 0.75, 0.06, "steel", 0.008)
    for x in (-0.84, 0.84):
        for y in (-0.32, 0.32):
            b.box(x, y, 0.45, 0.06, 0.06, 0.9, "steel", 0.004)
    b.box(0, 0, 0.25, 1.7, 0.65, 0.03, "steel", 0.004)
    b.box(0, 0.36, 1.35, 1.8, 0.04, 0.85, "clinical", 0.006)
    for i, x in enumerate((-0.6, -0.35, -0.1, 0.2, 0.45)):
        b.box(x, 0.33, 1.4 + (i % 2) * 0.1, 0.05 + (i % 3) * 0.04, 0.02, 0.28, "steel" if i % 2 else "hazard", 0.004)
    b.box(-0.7, -0.3, 0.98, 0.18, 0.12, 0.1, "steel", 0.008)
    b.box(0.5, 0.0, 0.97, 0.4, 0.3, 0.08, "hull", 0.008)
    b.box(0.6, 0.3, 1.72, 0.3, 0.06, 0.04, "emit_cool", 0.0)
    for x in (-0.3, 0.2):
        b.box(x, -0.1, 0.33, 0.35, 0.4, 0.13, "hull", 0.01)
    return b.build()


# ================================================================ bio lab, batch 2

def incubator_shelf():
    """A glass-fronted incubator: four lit shelves of culture trays. Tall cover."""
    b = P.Builder("incubator_shelf")
    b.box(0, 0.02, 0.95, 1.2, 0.56, 1.9, "clinical", 0.015)
    b.box(0, -0.12, 0.95, 1.08, 0.3, 1.7, "rubber", 0.0)
    for i in range(4):
        z = 0.35 + i * 0.4
        b.box(0, -0.12, z, 1.06, 0.3, 0.02, "steel", 0.0)
        b.box(0, -0.12, z + 0.33, 1.0, 0.02, 0.012, "emit_blue", 0.0)
        for k in range(5):
            b.cyl(-0.4 + k * 0.2, -0.12, z + 0.025, 0.06, 0.02, "z", "glass", 12)
    for x in (-0.54, 0.0, 0.54):
        b.box(x, -0.28, 0.95, 0.03, 0.02, 1.72, "steel", 0.003)  # door frames (glass left open)
    b.box(0.45, -0.285, 0.1, 0.2, 0.004, 0.06, "emit_cool", 0.0)
    return b.build()


def chem_cabinet():
    """A ventilated chemical cabinet, glass doors, bottles, hazard top. Tall cover."""
    b = P.Builder("chem_cabinet")
    b.box(0, 0, 0.92, 0.9, 0.5, 1.84, "steel", 0.012)
    b.box(0, -0.1, 0.95, 0.8, 0.28, 1.6, "rubber", 0.0)
    for z in (0.5, 1.0, 1.5):
        b.box(0, -0.1, z, 0.8, 0.28, 0.02, "steel", 0.0)
        for k, (r, h, m) in enumerate(((0.04, 0.22, "glass"), (0.05, 0.18, "hazard"), (0.035, 0.26, "glass"),
                                       (0.05, 0.14, "clinical"), (0.04, 0.2, "glass"))):
            b.cyl(-0.3 + k * 0.15, -0.1, z + 0.01 + h / 2, r, h, "z", m, 10)
    for x in (-0.41, 0.0, 0.41):
        b.box(x, -0.26, 0.95, 0.03, 0.02, 1.62, "steel", 0.003)
    b.box(0, 0, 1.87, 0.9, 0.5, 0.06, "hazard", 0.006)
    b.cyl(0.25, 0.05, 1.96, 0.07, 0.14, "z", "steel", 10)
    return b.build()


def autopsy_table():
    """A steel autopsy table: lipped slab, drain, pedestal, instrument tray. Low cover."""
    b = P.Builder("autopsy_table")
    b.box(0, 0, 0.45, 0.3, 0.6, 0.9, "steel", 0.01)
    b.box(0, 0, 0.92, 0.8, 2.0, 0.05, "steel", 0.008)
    for x in (-0.39, 0.39):
        b.box(x, 0, 0.96, 0.03, 2.0, 0.05, "steel", 0.004)
    for y in (-0.99, 0.99):
        b.box(0, y, 0.96, 0.8, 0.03, 0.05, "steel", 0.004)
    b.box(0, 0.0, 0.946, 0.06, 1.8, 0.004, "rubber", 0.0)
    b.cyl(0, 0.92, 0.946, 0.04, 0.006, "z", "rubber", 10)
    b.cyl(0.6, -0.6, 0.45, 0.02, 0.9, "z", "steel", 8)
    b.box(0.6, -0.6, 0.92, 0.35, 0.25, 0.02, "steel", 0.004)
    for k in range(3):
        b.box(0.5 + k * 0.08, -0.6, 0.94, 0.02, 0.18, 0.01, "clinical", 0.0)
    return b.build()


def containment_cell():
    """A glass containment wall section: frame, door with red lock lamp, cracked pane.
    Tall cover; whether the glass blocks sight is deck data's call."""
    b = P.Builder("containment_cell")
    W, H = 2.4, WALL_H
    for x in (-W / 2 + 0.06, -0.2, W / 2 - 0.06):
        b.box(x, 0, H / 2, 0.12, 0.25, H, "steel", 0.01)
    b.box(0, 0, H - 0.08, W, 0.25, 0.16, "steel", 0.01)
    b.box(0, 0, 0.06, W, 0.25, 0.12, "hazard", 0.006)
    b.box(-0.7, 0, 1.3, 0.88, 0.03, 2.3, "glass", 0.0)
    b.box(0.5, 0, 1.15, 1.2, 0.08, 2.05, "clinical", 0.01)
    b.box(0.5, -0.045, 1.4, 0.5, 0.01, 0.6, "glass", 0.0)
    b.box(1.0, -0.06, 1.2, 0.08, 0.03, 0.12, "emit_red", 0.0)
    for z, a, ln in ((1.5, 35, 0.5), (1.35, -50, 0.4), (1.62, -10, 0.35), (1.3, 80, 0.3)):
        b.box(-0.75, -0.02, z, ln, 0.006, 0.008, "clinical", 0.0, rot=(0, a, 0))
    return b.build()


# ================================================================ bridge, batch 2

def crew_station():
    """A crew station: a desk console with two screens and a seat. Low cover."""
    b = P.Builder("crew_station")
    b.box(0, 0.2, 0.4, 1.2, 0.6, 0.8, "hull", 0.015)
    b.box(0, 0.12, 0.83, 1.2, 0.5, 0.06, "steel", 0.008, rot=(-12, 0, 0))
    for x in (-0.3, 0.3):
        b.box(x, 0.38, 1.05, 0.5, 0.04, 0.32, "steel", 0.008)
        b.box(x, 0.355, 1.05, 0.44, 0.006, 0.26, "emit_blue" if x < 0 else "glass", 0.0)
    b.cyl(0, -0.4, 0.22, 0.04, 0.44, "z", "steel", 8)
    b.box(0, -0.4, 0.47, 0.5, 0.48, 0.08, "rubber", 0.03)
    b.box(0, -0.62, 0.78, 0.48, 0.08, 0.55, "rubber", 0.03)
    return b.build()


def holo_projector():
    """A holo table pedestal throwing a faint ring display. Clutter."""
    b = P.Builder("holo_projector")
    b.cyl(0, 0, 0.35, 0.3, 0.7, "z", "steel", 16)
    b.cyl(0, 0, 0.72, 0.45, 0.06, "z", "hull", 24)
    b.cyl(0, 0, 0.76, 0.35, 0.02, "z", "emit_blue", 24)
    for z, r in ((0.95, 0.3), (1.05, 0.22), (1.12, 0.12)):
        b.cyl(0, 0, z, r, 0.006, "z", "emit_cool", 24)
    b.box(0, -0.31, 0.4, 0.16, 0.004, 0.08, "hazard", 0.0)
    return b.build()


def comms_rack():
    """A tall comms rack: stacked units, blinking LEDs, a cable spill. Tall cover."""
    b = P.Builder("comms_rack")
    b.box(0, 0, 1.0, 0.8, 0.7, 2.0, "steel", 0.012)
    for i in range(8):
        z = 0.2 + i * 0.22
        b.box(0, -0.33, z, 0.7, 0.04, 0.18, "hull" if i % 2 else "steel", 0.004)
        for k in range(3):
            m = "emit_red" if (i + k) % 4 == 0 else ("emit_blue" if (i * k) % 3 == 1 else "rubber")
            b.box(0.22 + k * 0.05, -0.355, z, 0.02, 0.006, 0.02, m, 0.0)
    for x in (-0.15, -0.05):
        b.cyl(x, -0.38, 0.1, 0.02, 0.3, "x", "rubber", 6, rot=(0, 0, 60 + x * 200))
    return b.build()


def viewport_frame():
    """WALL_HIGH: a viewport out to space (0.9-2.3 m): thick frame, mullions, sill, stars."""
    b = P.Builder("viewport_frame")
    b.box(0, 0.06, 1.6, 2.8, 0.04, 1.3, "glass", 0.0)
    for k, (x, z) in enumerate(((-1.1, 2.0), (-0.6, 1.4), (-0.2, 2.1), (0.3, 1.2), (0.7, 1.8), (1.15, 1.5),
                                (-0.9, 1.1), (0.0, 1.65), (0.95, 2.15))):
        b.box(x, 0.07, z, 0.015, 0.004, 0.015, "emit_cool", 0.0)
    for z in (0.92, 2.28):
        b.box(0, -0.04, z, 3.0, 0.24, 0.14, "steel", 0.012)
    for x in (-1.45, -0.48, 0.48, 1.45):
        b.box(x, -0.04, 1.6, 0.1 if abs(x) > 1 else 0.06, 0.2, 1.5, "steel", 0.008)
    b.box(0, -0.12, 0.84, 3.0, 0.3, 0.06, "clinical", 0.008)
    b.box(0, -0.272, 0.84, 2.6, 0.006, 0.02, "hazard", 0.0)
    return b.build()


# ================================================================ crew quarters, batch 2

def wardrobe_locker():
    """A personal locker left ajar: clothes, a shelf, a name plate. Tall cover."""
    b = P.Builder("wardrobe_locker")
    b.box(0, 0.02, 1.0, 0.6, 0.5, 2.0, "clinical", 0.012)
    b.box(0, -0.06, 1.0, 0.54, 0.36, 1.9, "rubber", 0.0)
    b.box(0, -0.06, 1.6, 0.54, 0.36, 0.02, "steel", 0.0)
    for x, m in ((-0.12, "hull"), (0.05, "hazard"), (0.15, "hull")):
        b.box(x, -0.06, 1.15, 0.09, 0.3, 0.75, m, 0.03)
    b.box(-0.05, -0.31, 1.0, 0.56, 0.02, 1.92, "clinical", 0.008, rot=(0, 0, -15))
    b.box(-0.03, -0.33, 1.7, 0.18, 0.004, 0.05, "steel", 0.0, rot=(0, 0, -15))
    return b.build()


def sleeping_pod():
    """A capsule bunk, long side open to the room: shell, mattress, pillow, reading light,
    half-drawn curtain. Tall cover. 2.1 x 1.2 x 1.0."""
    b = P.Builder("sleeping_pod")
    L, H, D = 2.1, 1.2, 1.0
    b.box(0, D / 2 - 0.05, H / 2, L, 0.1, H, "clinical", 0.03)       # back
    b.box(0, 0, H - 0.05, L, D, 0.1, "clinical", 0.04)               # roof
    b.box(0, 0, 0.12, L, D, 0.24, "clinical", 0.04)                  # base
    for x in (-L / 2 + 0.05, L / 2 - 0.05):
        b.box(x, 0, H / 2, 0.1, D, H, "clinical", 0.03)              # ends
    b.box(0, D / 2 - 0.11, H / 2, L - 0.2, 0.02, H - 0.34, "rubber", 0.0)  # dark interior
    b.box(0, 0.03, 0.3, L - 0.24, D - 0.2, 0.12, "hull", 0.03)       # mattress
    b.box(-0.75, 0.15, 0.4, 0.35, 0.4, 0.08, "clinical", 0.03)       # pillow
    b.box(-0.6, D / 2 - 0.13, 0.95, 0.2, 0.03, 0.05, "emit_cool", 0.0)
    b.box(0.55, -D / 2 + 0.03, 0.66, 0.85, 0.03, 0.78, "hull", 0.004)  # curtain
    b.cyl(0, -D / 2 + 0.04, H - 0.14, 0.012, L - 0.2, "x", "steel", 6)
    return b.build()


def shower_stall():
    """A shower cubicle: tray, frosted glass, shower head, a drain. Tall cover."""
    b = P.Builder("shower_stall")
    b.box(0, 0, 0.05, 1.0, 1.0, 0.1, "clinical", 0.02)
    b.cyl(0.1, 0.1, 0.105, 0.05, 0.01, "z", "steel", 10)
    b.box(0, 0.48, 1.1, 1.0, 0.04, 2.2, "clinical", 0.006)
    b.box(0.48, 0, 1.1, 0.04, 1.0, 2.2, "clinical", 0.006)
    b.box(-0.49, 0, 1.1, 0.02, 0.98, 2.0, "glass", 0.0)
    b.box(0.2, -0.49, 1.1, 0.6, 0.02, 2.0, "glass", 0.0)
    for x, y, sx, sy in ((-0.49, 0, 0.04, 1.0), (0, -0.49, 1.0, 0.04)):
        b.box(x, y, 2.17, sx, sy, 0.06, "steel", 0.004)
    b.cyl(0, 0.42, 1.95, 0.08, 0.03, "y", "steel", 12)
    b.cyl(0, 0.38, 1.95, 0.07, 0.01, "y", "brass", 12)
    b.box(0.3, 0.44, 1.1, 0.1, 0.04, 0.14, "steel", 0.006)
    return b.build()


def personal_shelf():
    """WALL: a shelf of someone's things: books, a framed photo, a mug, a dead plant. 1.0 x 0.5."""
    b = P.Builder("personal_shelf")
    b.box(0, 0, 0.04, 1.0, 0.25, 0.03, "steel", 0.004)
    for x in (-0.4, 0.4):
        b.box(x, 0.08, -0.05, 0.03, 0.1, 0.18, "steel", 0.003)
    for i, (w, h, m) in enumerate(((0.04, 0.24, "hull"), (0.05, 0.22, "clinical"), (0.035, 0.26, "hazard"),
                                   (0.045, 0.2, "hull"))):
        b.box(-0.42 + i * 0.05, 0.0, 0.055 + h / 2, w, 0.18, h, m, 0.004)
    b.box(-0.18, 0.02, 0.18, 0.05, 0.18, 0.04, "steel", 0.004, rot=(0, 20, 0))  # leaning book
    b.box(0.08, 0.06, 0.17, 0.2, 0.02, 0.24, "brass", 0.004, rot=(-10, 0, 0))
    b.box(0.08, 0.048, 0.17, 0.16, 0.004, 0.19, "glass", 0.0, rot=(-10, 0, 0))
    b.cyl(0.28, -0.02, 0.1, 0.04, 0.09, "z", "clinical", 10)
    b.cyl(0.42, 0.0, 0.1, 0.05, 0.09, "z", "hull", 10)
    b.cyl(0.42, 0.0, 0.19, 0.008, 0.12, "z", "rubber", 5, rot=(0, 25, 0))
    return b.build()


# ================================================================ mess, batch 2

def drinks_cooler():
    """A glass-door drinks cooler, still humming, still charging. Tall cover."""
    b = P.Builder("drinks_cooler")
    b.box(0, 0.02, 0.97, 0.8, 0.66, 1.94, "steel", 0.015)
    b.box(0, 0.3, 0.95, 0.68, 0.02, 1.6, "emit_cool", 0.0)
    for z in (0.35, 0.75, 1.15, 1.55):
        b.box(0, 0.0, z, 0.68, 0.55, 0.015, "steel", 0.0)
        for k in range(5):
            b.cyl(-0.26 + k * 0.13, -0.12, z + 0.11, 0.035, 0.2, "z", "hazard" if (k + int(z * 10)) % 3 else "glass", 8)
    for x in (-0.36, 0.36):
        b.box(x, -0.32, 0.95, 0.04, 0.02, 1.62, "steel", 0.003)
    b.box(0.3, -0.34, 0.95, 0.03, 0.03, 0.4, "steel", 0.004)  # handle
    b.box(0, -0.305, 1.86, 0.7, 0.02, 0.12, "emit_red", 0.0)
    return b.build()


def tray_trolley():
    """A tray return trolley, half full; one tray on the floor. Clutter."""
    b = P.Builder("tray_trolley")
    for x in (-0.28, 0.28):
        for y in (-0.36, 0.36):
            b.box(x, y, 0.65, 0.03, 0.03, 1.2, "steel", 0.003)
            b.cyl(x, y, 0.04, 0.04, 0.03, "x", "rubber", 8)
    for i in range(7):
        z = 0.2 + i * 0.15
        b.box(0, 0, z, 0.56, 0.74, 0.015, "steel", 0.0)
        if i % 3 != 2:
            b.box(0, -0.02, z + 0.02, 0.5, 0.66, 0.02, "clinical", 0.004)
    b.box(0.1, -0.7, 0.015, 0.5, 0.36, 0.02, "clinical", 0.004, rot=(0, 0, 25))
    return b.build()


def round_table():
    """A round mess table with four stools, one knocked over. Low cover."""
    b = P.Builder("round_table")
    b.cyl(0, 0, 0.73, 0.55, 0.04, "z", "clinical", 24)
    b.cyl(0, 0, 0.36, 0.06, 0.72, "z", "steel", 10)
    b.cyl(0, 0, 0.02, 0.3, 0.04, "z", "steel", 16)
    for x, y in ((-0.6, 0.0), (0.6, 0.0), (0.0, 0.6)):
        b.cyl(x, y, 0.45, 0.17, 0.05, "z", "hull", 14)
        b.cyl(x, y, 0.22, 0.03, 0.44, "z", "steel", 8)
    b.cyl(0.0, -0.75, 0.17, 0.17, 0.05, "y", "hull", 14, rot=(0, 0, 20))
    b.cyl(0.08, -0.52, 0.17, 0.03, 0.44, "y", "steel", 8, rot=(0, 0, 20))
    return b.build()


def waste_bin():
    """An overflowing waste bin with a swing flap and a spill. Clutter."""
    b = P.Builder("waste_bin")
    b.box(0, 0, 0.42, 0.5, 0.42, 0.84, "hull", 0.02)
    b.box(0, -0.05, 0.86, 0.5, 0.32, 0.05, "steel", 0.008)
    b.box(0, -0.2, 0.75, 0.3, 0.02, 0.14, "rubber", 0.004, rot=(20, 0, 0))
    for x, y, z, a in ((-0.1, 0.05, 0.92, 15), (0.12, 0.0, 0.94, -30), (0.0, 0.1, 0.97, 50)):
        b.box(x, y, z, 0.14, 0.1, 0.08, "clinical", 0.02, rot=(a, a * 0.5, a))
    b.box(0.3, -0.3, 0.004, 0.4, 0.3, 0.006, "rubber", 0.0, rot=(0, 0, 20))
    b.box(0.25, -0.35, 0.03, 0.1, 0.08, 0.05, "clinical", 0.01, rot=(0, 0, 40))
    return b.build()


# ================================================================ registry

SETS = {
    "hallway": [
        (wall_rib, "wall", "structural rib, floor to ceiling; repeat every 2-3 m to give corridors depth"),
        (wall_panel_recessed, "wall", "standard wall bay"),
        (wall_panel_breached, "wall", "bay with its plate torn off; the plate leans 0.35 m out (clutter)"),
        (pipe_run_low, "wall", "pipes along the wall base; reads strongly from the steep camera"),
        (pipe_run_high, "wall_high", None),
        (conduit_tray, "wall_high", None),
        (air_duct, "wall_high", None),
        (wall_light_strip, "wall", "light fixture; pair with a real light from data"),
        (emergency_lamp, "wall", "pair with a red light from data; good for alarm tiers"),
        (door_jamb, "wall", "either side of a door; flip X for the other side"),
        (door_lintel, "wall_high", "over the 2.2 m door aperture; scale X to the door width"),
        (corner_pillar, "wall", "inner corner; rotate to fit"),
        (handrail, "wall", None),
        (floor_grate, "clutter", "flush; walk over it"),
        (kick_plate, "wall", None),
        (wall_sign_arrow, "wall", "text and deck numbers go on as decals"),
        (maintenance_hatch, "wall", "low on the wall; stalker vent spawns could use it"),
        (fire_hose_reel, "wall", None),
        (debris_pile, "clutter", "no cover; small collision"),
        (hanging_cables, "wall_high", "hangs to ~1.5 m beside the wall; sparking end wants a flicker light"),
    ],
    "medbay": [
        (cryo_pod, "cover_tall", "something inside"),
        (scrub_sink, "wall", None),
        (privacy_screen, "clutter", "blocks sight if deck data says so"),
        (defib_cart, "clutter", None),
        (biohazard_bin, "clutter", None),
        (body_bag, "clutter", None),
    ],
    "cargo": [
        (crate_pile_tipped, "cover_low", None),
        (container_section, "cover_tall", "open end faces front; inside is enterable if deck data allows"),
        (pallet_jack, "clutter", None),
        (tarp_pile, "cover_low", None),
        (cargo_net_wall, "wall", None),
        (manifest_terminal, "clutter", None),
    ],
    "engineering": [
        (coolant_pump, "cover_low", None),
        (transformer, "cover_tall", None),
        (catwalk_section, "clutter", "walkable; rails along both long sides"),
        (workbench, "cover_low", None),
    ],
    "biolab": [
        (incubator_shelf, "cover_tall", None),
        (chem_cabinet, "cover_tall", None),
        (autopsy_table, "cover_low", None),
        (containment_cell, "cover_tall", "glass pane: sight is deck data's call"),
    ],
    "bridge": [
        (crew_station, "cover_low", None),
        (holo_projector, "clutter", None),
        (comms_rack, "cover_tall", None),
        (viewport_frame, "wall_high", "window to space, 0.84-2.35 m"),
    ],
    "quarters": [
        (wardrobe_locker, "cover_tall", "door ajar adds ~0.1 m in front"),
        (sleeping_pod, "cover_tall", None),
        (shower_stall, "cover_tall", None),
        (personal_shelf, "wall", None),
    ],
    "mess": [
        (drinks_cooler, "cover_tall", None),
        (tray_trolley, "clutter", None),
        (round_table, "cover_low", None),
        (waste_bin, "clutter", None),
    ],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    cat_path = os.path.join(OUT, "catalogue.json")
    cat = json.load(open(cat_path)) if os.path.exists(cat_path) else {}
    total = 0
    for set_name, entries in SETS.items():
        for fn, role, note in entries:
            P.reset()
            ob = fn()
            d = ob.dimensions
            total += P.export(ob, OUT)
            entry = {"size_m": [round(d.x, 2), round(d.z, 2), round(d.y, 2)], "role": role, "set": set_name}
            if note:
                entry["note"] = note
            cat[ob.name] = entry
    cat["_note"] = (cat.get("_note", "").split(" wall_high:")[0] +
                    " wall_high: origin on the floor under the prop, mounting height baked in.")
    json.dump(cat, open(cat_path, "w"), indent=1)
    print("total tris", total)
    groups = {"hall_a": SETS["hallway"][:7], "hall_b": SETS["hallway"][7:14], "hall_c": SETS["hallway"][14:]}
    for k, v in SETS.items():
        if k != "hallway":
            groups[f"{k}_b"] = v
    for g, entries in groups.items():
        P.reset()
        P.preview([fn() for fn, _, _ in entries], os.path.join(OUT, f"preview_{g}.png"))


if __name__ == "__main__":
    main()
