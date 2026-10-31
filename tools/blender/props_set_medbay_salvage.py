"""Prop set 1 and 2: medbay furniture and salvage pickups (lead, Blender by script, 2026-10-31).

Run: python3 tools/blender/props_set_medbay_salvage.py [out_dir]   (pip install bpy)
Same conventions as tools/blender/props.py (metres, base-centre origin, front +Z in glTF,
material slots named after data/kit.json materials). Writes .glb files and two preview sheets.

Sizes: the bed matches data/deck.json (0.9 x 0.75 x 2.0, its long side along depth); salvage
fits inside data/salvage.json class boxes (small 0.32x0.14x0.24, medium 0.55x0.40x0.40,
heavy 0.95x0.65x0.65). Wall props (med_station) have their back at the rear face, for mounting.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402  (imports bpy first)

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"


# ---------------------------------------------------------------- medbay set

def bed():
    """Treatment bed after A007-05..08: low caster base with a hazard band, lift columns, a SOLID
    plated deck underneath (the shield side when tipped), black mattress, raised head pad, ivory
    side rails, red tail lamps at the foot. 0.9 wide x 0.75 high x 2.0 long (long along depth)."""
    b = P.Builder("bed")
    w, h, L = 0.9, 0.75, 2.0
    # base frame
    b.box(0, 0, 0.12, w * 0.86, L * 0.9, 0.08, "steel", 0.01)
    b.box(0, 0, 0.12, w * 0.87, L * 0.6, 0.03, "hazard", 0.0)
    for x in (-w * 0.38, w * 0.38):  # casters
        for y in (-L * 0.42, L * 0.42):
            b.cyl(x, y, 0.05, 0.05, 0.05, "x", "rubber", 10)
    # lift columns
    for y in (-L * 0.25, L * 0.25):
        b.box(0, y, 0.3, 0.16, 0.12, 0.3, "steel", 0.01)
    # solid deck plate (shield side) and frame
    b.box(0, 0, 0.47, w, L, 0.05, "clinical", 0.012)
    b.box(0, 0, 0.445, w * 0.8, L * 0.85, 0.012, "steel", 0.0)  # underside stiffener
    # mattress, head pad raised
    b.box(0, 0.08, 0.555, w * 0.82, L * 0.82, 0.12, "rubber", 0.03)
    b.box(0, L * 0.38, 0.65, w * 0.6, 0.28, 0.08, "rubber", 0.03)
    # side rails
    for x in (-w * 0.47, w * 0.47):
        b.box(x, 0, 0.665, 0.035, L * 0.6, 0.07, "clinical", 0.01)
    # foot and head boards
    b.box(0, -L * 0.48, 0.6, w * 0.9, 0.04, 0.22, "clinical", 0.01)
    b.box(0, L * 0.48, 0.62, w * 0.9, 0.04, 0.26, "clinical", 0.01)
    for x in (-w * 0.38, w * 0.38):  # tail lamps
        b.box(x, -L * 0.5 + 0.003, 0.62, 0.08, 0.01, 0.035, "emit_red", 0.0)
    return b.build()


def surgical_lamp():
    """Floor-standing surgical lamp: weighted base, pole, arm, round head with a cool emissive face."""
    b = P.Builder("surgical_lamp")
    b.cyl(0, 0, 0.02, 0.26, 0.04, "z", "rubber", 16)
    b.cyl(0, 0, 0.06, 0.12, 0.05, "z", "steel", 12)
    b.cyl(0, 0, 0.8, 0.022, 1.5, "z", "steel", 8)
    b.box(0.08, 0, 1.56, 0.2, 0.05, 0.05, "clinical", 0.01)
    b.cyl(0.1, 0, 1.64, 0.18, 0.08, "z", "clinical", 16)
    b.cyl(0.1, 0, 1.595, 0.14, 0.012, "z", "emit_cool", 16)
    b.box(0.1, 0, 1.7, 0.04, 0.04, 0.04, "steel", 0.008)  # handle
    return b.build()


def iv_stand():
    """IV stand: star base on casters, pole, crossbar with two bags and a drip line."""
    b = P.Builder("iv_stand")
    b.box(0, 0, 0.06, 0.44, 0.05, 0.03, "steel", 0.008)
    b.box(0, 0, 0.06, 0.05, 0.44, 0.03, "steel", 0.008)
    for x, y in ((0.2, 0), (-0.2, 0), (0, 0.2), (0, -0.2)):
        b.cyl(x, y, 0.03, 0.03, 0.03, "x", "rubber", 8)
    b.cyl(0, 0, 0.98, 0.014, 1.84, "z", "steel", 8)
    b.box(0, 0, 1.86, 0.32, 0.02, 0.02, "steel", 0.004)
    for x in (-0.12, 0.12):
        b.box(x, 0, 1.68, 0.1, 0.035, 0.18, "glass", 0.01)
        b.box(x, 0, 1.585, 0.02, 0.02, 0.03, "clinical", 0.0)
    b.box(0.12, 0, 1.3, 0.006, 0.006, 0.55, "glass", 0.0)  # drip line
    return b.build()


def gurney():
    """Transport gurney: tubular frame on casters, thin pad, folded rails. 0.6 x 0.9 x 1.9."""
    b = P.Builder("gurney")
    w, L = 0.6, 1.9
    for x in (-w * 0.4, w * 0.4):
        for y in (-L * 0.42, L * 0.42):
            b.cyl(x, y, 0.06, 0.06, 0.04, "x", "rubber", 10)
            b.box(x, y, 0.38, 0.035, 0.035, 0.6, "steel", 0.006)
    b.box(0, 0, 0.7, w, L, 0.05, "steel", 0.008)
    b.box(0, 0, 0.76, w * 0.92, L * 0.94, 0.07, "hull", 0.02)  # pad
    for x in (-w * 0.48, w * 0.48):
        b.box(x, 0, 0.85, 0.025, L * 0.55, 0.025, "clinical", 0.006)
    b.box(0, L * 0.47, 0.85, w * 0.8, 0.03, 0.08, "clinical", 0.006)
    return b.build()


def trolley():
    """Supply trolley: drawer body on casters, raised-rim top tray, push handle. 0.55 x 0.95 x 0.45."""
    b = P.Builder("trolley")
    w, d = 0.55, 0.45
    hy = -d / 2 + 0.02
    for x in (-w * 0.4, w * 0.4):
        for y in (-d * 0.36, d * 0.36):
            b.cyl(x, y, 0.04, 0.04, 0.03, "x", "rubber", 8)
    b.box(0, 0.01, 0.48, w * 0.92, d * 0.86, 0.72, "clinical", 0.012)
    for i in range(3):
        z = 0.22 + i * 0.21
        b.box(0, hy, z, w * 0.82, 0.012, 0.18, "clinical", 0.006)
        b.box(0, hy - 0.008, z + 0.05, w * 0.3, 0.012, 0.02, "steel", 0.004)
    b.box(0, 0.01, 0.86, w * 0.96, d * 0.9, 0.03, "steel", 0.006)  # tray
    for x in (-w * 0.47, w * 0.47):
        b.box(x, 0.01, 0.89, 0.015, d * 0.9, 0.04, "steel", 0.004)
    b.box(0, d * 0.44, 0.93, w * 0.7, 0.025, 0.025, "steel", 0.006)  # handle
    b.box(-0.1, 0.0, 0.9, 0.12, 0.1, 0.05, "hazard", 0.006)  # a box of supplies
    return b.build()


def med_station():
    """Wall med-station (mount on a wall; back face at the rear): cabinet with a red-cross panel,
    a small screen and a defibrillator cradle. 0.9 x 0.8 x 0.22."""
    b = P.Builder("med_station")
    w, h, d = 0.9, 0.8, 0.22
    b.box(0, 0.01, h / 2, w, d - 0.02, h, "clinical", 0.012)
    hy = -d / 2 + 0.01
    b.box(-0.2, hy - 0.005, h * 0.55, 0.36, 0.012, 0.5, "clinical", 0.006)  # door
    b.box(-0.2, hy - 0.012, h * 0.68, 0.14, 0.006, 0.04, "emit_red", 0.0)
    b.box(-0.2, hy - 0.012, h * 0.68, 0.04, 0.006, 0.14, "emit_red", 0.0)
    b.box(0.22, hy - 0.004, h * 0.7, 0.3, 0.008, 0.18, "glass", 0.0)  # screen
    b.box(0.22, hy - 0.006, h * 0.32, 0.26, 0.012, 0.28, "hazard", 0.008)  # defib cradle
    b.box(0.22, hy - 0.014, h * 0.32, 0.16, 0.012, 0.16, "steel", 0.006)
    return b.build()


# ---------------------------------------------------------------- salvage pickups

def data_chips():
    """SMALL: a rugged data-chip case with a handle and a label strip."""
    b = P.Builder("salvage_data_chips")
    b.box(0, 0, 0.055, 0.28, 0.2, 0.1, "steel", 0.012)
    b.box(0, -0.1, 0.06, 0.2, 0.006, 0.03, "clinical", 0.0)
    b.box(0, 0, 0.115, 0.12, 0.03, 0.02, "rubber", 0.006)
    b.box(0.1, -0.101, 0.06, 0.02, 0.004, 0.012, "emit_blue", 0.0)
    return b.build()


def med_pack():
    """SMALL: a sealed medical pack with a red cross and a strap."""
    b = P.Builder("salvage_med_pack")
    b.box(0, 0, 0.055, 0.26, 0.18, 0.11, "clinical", 0.02)
    b.box(0, -0.091, 0.06, 0.08, 0.004, 0.025, "emit_red", 0.0)
    b.box(0, -0.091, 0.06, 0.025, 0.004, 0.08, "emit_red", 0.0)
    b.box(0, 0, 0.055, 0.03, 0.185, 0.115, "rubber", 0.0)
    return b.build()


def fuse():
    """SMALL: a heavy ceramic fuse with brass end caps in a small cradle."""
    b = P.Builder("salvage_fuse")
    b.box(0, 0, 0.02, 0.24, 0.12, 0.04, "steel", 0.006)
    b.cyl(0, 0, 0.085, 0.045, 0.2, "x", "clinical", 12)
    for x in (-0.11, 0.11):
        b.cyl(x, 0, 0.085, 0.05, 0.03, "x", "brass", 12)
    b.box(0, -0.046, 0.085, 0.06, 0.004, 0.02, "hazard", 0.0)
    return b.build()


def relay():
    """MEDIUM: a relay assembly: finned housing, connector studs, a warning label."""
    b = P.Builder("salvage_relay")
    b.box(0, 0, 0.15, 0.42, 0.3, 0.28, "steel", 0.015)
    for i in range(6):
        b.box(-0.15 + i * 0.06, 0, 0.3, 0.02, 0.26, 0.04, "steel", 0.004)  # fins
    for x in (-0.12, 0, 0.12):
        b.cyl(x, -0.165, 0.12, 0.025, 0.04, "y", "brass", 10)
    b.box(0.12, -0.151, 0.22, 0.12, 0.004, 0.06, "hazard", 0.0)
    return b.build()


def canister():
    """MEDIUM: a pressurised canister lying on its side, hazard band and valve."""
    b = P.Builder("salvage_canister")
    b.cyl(0, 0, 0.16, 0.15, 0.44, "x", "hull", 16)
    b.cyl(0, 0, 0.16, 0.152, 0.06, "x", "hazard", 16)
    b.cyl(0.24, 0, 0.16, 0.06, 0.05, "x", "steel", 10)
    b.box(0.27, 0, 0.2, 0.03, 0.03, 0.06, "steel", 0.004)
    for x in (-0.14, 0.14):
        b.box(x, 0, 0.02, 0.06, 0.22, 0.04, "rubber", 0.006)  # cradle feet
    return b.build()


def busbar():
    """MEDIUM: a strapped bundle of copper busbars."""
    b = P.Builder("salvage_busbar")
    for i in range(4):
        b.box(0, 0, 0.03 + i * 0.055, 0.5, 0.1, 0.045, "brass", 0.006)
    for x in (-0.16, 0.16):
        b.box(x, 0, 0.11, 0.035, 0.11, 0.22, "rubber", 0.004)
    b.box(0, -0.051, 0.14, 0.1, 0.004, 0.04, "hazard", 0.0)
    return b.build()


def cargo_pod():
    """HEAVY: a sealed cargo pod with steel bands, hazard corners and two handles."""
    b = P.Builder("salvage_cargo_pod")
    b.box(0, 0, 0.28, 0.88, 0.58, 0.52, "hull", 0.04)
    for x in (-0.3, 0, 0.3):
        b.box(x, 0, 0.28, 0.05, 0.6, 0.54, "steel", 0.01)
    for x in (-0.42, 0.42):
        b.box(x, 0, 0.3, 0.04, 0.22, 0.05, "rubber", 0.01)  # handles
    b.box(0.15, -0.291, 0.32, 0.2, 0.004, 0.12, "hazard", 0.0)
    b.box(-0.15, -0.291, 0.32, 0.16, 0.004, 0.05, "clinical", 0.0)
    return b.build()


def engine_part():
    """HEAVY: a turbine segment: a drum with brass flanges and cooling fins, on a skid."""
    b = P.Builder("salvage_engine_part")
    b.box(0, 0, 0.04, 0.8, 0.5, 0.08, "steel", 0.01)
    b.cyl(0, 0, 0.34, 0.26, 0.7, "x", "steel", 16)
    for x in (-0.36, 0.36):
        b.cyl(x, 0, 0.34, 0.29, 0.04, "x", "brass", 16)
    for i in range(5):
        b.cyl(-0.2 + i * 0.1, 0, 0.34, 0.275, 0.015, "x", "steel", 16)
    b.box(0, 0, 0.62, 0.2, 0.08, 0.04, "hazard", 0.006)
    return b.build()


def black_box():
    """HEAVY (the prize): a flight-data recorder: high-visibility case, steel corner guards, a red
    locator beacon and a label plate. Reads instantly as 'the thing'."""
    b = P.Builder("salvage_black_box")
    b.box(0, 0, 0.24, 0.6, 0.44, 0.44, "hazard", 0.03)
    for x in (-0.29, 0.29):
        for y in (-0.21, 0.21):
            b.box(x, y, 0.24, 0.05, 0.05, 0.46, "steel", 0.008)
    b.box(0, -0.221, 0.28, 0.3, 0.004, 0.12, "clinical", 0.0)
    b.cyl(0.18, 0, 0.475, 0.04, 0.03, "z", "emit_red", 12)
    b.box(0, 0, 0.47, 0.22, 0.05, 0.03, "rubber", 0.006)  # handle
    return b.build()


MEDBAY = [bed, surgical_lamp, iv_stand, gurney, trolley, med_station]
SALVAGE = [data_chips, med_pack, fuse, relay, canister, busbar, cargo_pod, engine_part, black_box]


def main():
    os.makedirs(OUT, exist_ok=True)
    P.reset()
    total = 0
    for f in MEDBAY + SALVAGE:
        total += P.export(f(), OUT)
    print("total tris", total)
    P.reset()
    P.preview([f() for f in MEDBAY], os.path.join(OUT, "preview_medbay.png"))
    P.reset()
    P.preview([f() for f in SALVAGE], os.path.join(OUT, "preview_salvage.png"))


if __name__ == "__main__":
    main()
