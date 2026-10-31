"""Weapons, modelled by script (lead, 2026-10-31). A016's designs; the art tool refused the images.

Run: python3 tools/blender/props_weapons.py [out_dir]   (pip install bpy)
Conventions (differ from room props, because these are held):
  - origin at the right-hand grip point (where the hand bone attaches);
  - barrel/forward along +Z in glTF (Blender -Y), up +Y in glTF (Blender +Z);
  - material slots are data/kit.json keys, so the game binds kit materials (wear, grime) by name;
  - `muzzle_m` in catalogue.json is the muzzle point from the origin, in glTF metres (x, y, z).
Lengths follow A016's design records (assets/source/A016-arsenal/manifest.json).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"
MUZZLE = {}  # name -> Blender-space muzzle point


def ribs(b, y0, y1, n, z, w, h, m="steel"):
    for i in range(n):
        y = y0 + (y1 - y0) * i / max(n - 1, 1)
        b.box(0, y, z, w, 0.008, h, m, 0.001)


def issue_rifle():
    """A016-07: company issue carbine, the baseline. 0.94 m. 'Rental continues while unloaded.'"""
    b = P.Builder("weapon_issue_rifle")
    b.box(0, -0.13, 0.05, 0.06, 0.34, 0.11, "hull", 0.008)            # receiver
    b.box(0, -0.13, 0.112, 0.045, 0.30, 0.016, "steel", 0.003)        # top rail
    for i in range(6):
        b.box(0, -0.25 + i * 0.045, 0.123, 0.05, 0.012, 0.008, "steel", 0.001)
    b.box(0, -0.40, 0.045, 0.066, 0.22, 0.085, "clinical", 0.01)      # handguard
    for i in range(4):
        b.box(0.0335, -0.46 + i * 0.04, 0.05, 0.002, 0.022, 0.04, "steel", 0.0)
        b.box(-0.0335, -0.46 + i * 0.04, 0.05, 0.002, 0.022, 0.04, "steel", 0.0)
    b.box(0, -0.44, 0.0885, 0.067, 0.03, 0.004, "hazard", 0.0)
    b.cyl(0, -0.565, 0.055, 0.012, 0.13, "y", "steel", 10)            # barrel
    b.cyl(0, -0.61, 0.055, 0.019, 0.05, "y", "steel", 8)              # muzzle brake
    for z in (0.065, 0.045):
        b.box(0, -0.615, z, 0.04, 0.012, 0.004, "rubber", 0.0)         # brake ports
    b.cyl(0, -0.43, -0.012, 0.016, 0.09, "y", "steel", 10)            # under-barrel torch
    b.cyl(0, -0.476, -0.012, 0.014, 0.004, "y", "emit_cool", 10)
    b.box(0, -0.15, -0.065, 0.034, 0.065, 0.14, "steel", 0.006, rot=(-14, 0, 0))   # magazine
    b.box(0, -0.165, -0.13, 0.038, 0.07, 0.014, "hazard", 0.002, rot=(-14, 0, 0))
    b.box(0, 0.005, -0.045, 0.032, 0.045, 0.11, "rubber", 0.01, rot=(16, 0, 0))     # pistol grip
    b.box(0, -0.035, -0.012, 0.01, 0.065, 0.006, "steel", 0.0)                       # guard
    b.box(0, 0.165, 0.045, 0.046, 0.25, 0.085, "hull", 0.01)          # stock
    b.box(0, 0.18, 0.045, 0.048, 0.10, 0.03, "rubber", 0.0)           # cutout insert
    b.box(0, 0.30, 0.035, 0.052, 0.02, 0.11, "rubber", 0.006)         # butt pad
    b.box(0, -0.09, 0.145, 0.026, 0.07, 0.04, "steel", 0.004)         # sight
    b.box(0, -0.124, 0.15, 0.004, 0.002, 0.004, "emit_red", 0.0)
    b.box(0.031, -0.12, 0.05, 0.002, 0.08, 0.035, "clinical", 0.0)    # rental tag plate
    MUZZLE["weapon_issue_rifle"] = Vector((0, -0.635, 0.055))
    return b.build()


def budget_shotgun():
    """A016-08: cheap self-loading shotgun, short and fat, taped up. 0.83 m. 'Every pellet separately accounted.'"""
    b = P.Builder("weapon_budget_shotgun")
    b.box(0, -0.10, 0.05, 0.07, 0.30, 0.12, "clinical", 0.012)        # boxy plastic receiver
    b.box(0, -0.10, 0.111, 0.071, 0.30, 0.006, "hazard", 0.0)
    b.cyl(0, -0.40, 0.075, 0.022, 0.34, "y", "steel", 12)             # fat barrel
    b.cyl(0, -0.37, 0.028, 0.018, 0.28, "y", "steel", 12)             # tube under it
    b.box(0, -0.33, 0.05, 0.072, 0.14, 0.07, "rubber", 0.01)          # slab forend
    for y in (-0.47, -0.52):
        b.cyl(0, y, 0.06, 0.026, 0.018, "y", "rubber", 10)            # tape wraps
    b.box(0, -0.12, -0.06, 0.04, 0.09, 0.11, "steel", 0.006)          # box magazine
    b.box(0, -0.12, -0.115, 0.042, 0.095, 0.012, "hazard", 0.002)
    b.box(0, 0.01, -0.04, 0.034, 0.05, 0.11, "rubber", 0.01, rot=(18, 0, 0))
    b.box(0, -0.03, -0.01, 0.01, 0.06, 0.006, "steel", 0.0)
    b.box(0, 0.155, 0.045, 0.05, 0.21, 0.10, "clinical", 0.012)       # stock
    b.box(0, 0.265, 0.045, 0.055, 0.02, 0.12, "rubber", 0.006)
    b.box(0.036, -0.06, 0.06, 0.002, 0.1, 0.05, "hull", 0.0)          # pellet-count window
    b.box(0.037, -0.06, 0.06, 0.002, 0.05, 0.015, "emit_red", 0.0)
    b.box(0, -0.20, 0.13, 0.012, 0.03, 0.03, "steel", 0.003)          # bead sight
    MUZZLE["weapon_budget_shotgun"] = Vector((0, -0.57, 0.075))
    return b.build()


def flare_gun():
    """A016-04: magazine flare pistol, fat orange bore. 0.31 m. 'Illumination is a premium service.'"""
    b = P.Builder("weapon_flare_gun")
    b.box(0, -0.06, 0.06, 0.04, 0.14, 0.06, "hazard", 0.01)           # frame
    b.cyl(0, -0.15, 0.075, 0.026, 0.14, "y", "hazard", 14)            # big bore barrel
    b.cyl(0, -0.22, 0.075, 0.029, 0.02, "y", "steel", 14)             # muzzle ring
    b.cyl(0, -0.225, 0.075, 0.018, 0.012, "y", "emit_red", 12)        # flare glow in the bore
    b.box(0, 0.0, -0.02, 0.034, 0.05, 0.11, "rubber", 0.01, rot=(14, 0, 0))   # grip
    b.box(0, 0.012, -0.08, 0.036, 0.045, 0.012, "steel", 0.002, rot=(14, 0, 0))  # mag base
    b.box(0, -0.035, 0.01, 0.008, 0.05, 0.005, "steel", 0.0)          # guard
    b.box(0, 0.02, 0.085, 0.022, 0.03, 0.02, "steel", 0.003)          # hammer block
    b.box(0.021, -0.08, 0.06, 0.002, 0.06, 0.03, "clinical", 0.0)     # premium-service sticker
    MUZZLE["weapon_flare_gun"] = Vector((0, -0.235, 0.075))
    return b.build()


def plasma_cutter():
    """A016-01: industrial plasma cutter, glowing cell, prong emitter, heat fins. 0.72 m. 'Cutting time billed by the second.'"""
    b = P.Builder("weapon_plasma_cutter")
    b.box(0, -0.10, 0.05, 0.075, 0.30, 0.10, "hazard", 0.012)         # body
    b.cyl(0, 0.03, 0.115, 0.032, 0.16, "y", "steel", 12)              # cell housing on top
    b.cyl(0, 0.03, 0.115, 0.026, 0.12, "y", "emit_blue", 12)          # the cell's glow window
    for y in (-0.045, 0.105):
        b.cyl(0, y, 0.115, 0.036, 0.018, "y", "steel", 12)
    ribs(b, -0.20, -0.10, 6, 0.05, 0.09, 0.115)                        # heat fins
    b.box(0, -0.31, 0.06, 0.06, 0.12, 0.07, "steel", 0.01)            # emitter neck
    for x, z in ((0.0, 0.10), (0.03, 0.035), (-0.03, 0.035)):
        b.box(x, -0.40, z, 0.014, 0.08, 0.014, "steel", 0.003)          # three prongs
    b.cyl(0, -0.38, 0.06, 0.022, 0.02, "y", "glass", 12)
    b.cyl(0, -0.39, 0.06, 0.012, 0.01, "y", "emit_cool", 10)          # arc point
    b.cyl(0.04, -0.12, 0.10, 0.008, 0.26, "y", "rubber", 6, rot=(8, 0, 0))   # cable cell->head
    b.box(0, -0.26, -0.03, 0.03, 0.04, 0.09, "rubber", 0.008, rot=(-8, 0, 0))  # fore grip
    b.box(0, 0.02, -0.04, 0.034, 0.05, 0.11, "rubber", 0.01, rot=(16, 0, 0))   # main grip
    b.box(0, 0.135, 0.05, 0.05, 0.17, 0.08, "steel", 0.01)            # short brace
    b.box(0, 0.225, 0.05, 0.055, 0.02, 0.10, "rubber", 0.005)
    b.box(0.039, -0.08, 0.04, 0.002, 0.07, 0.03, "clinical", 0.0)     # per-second meter plate
    b.box(0.04, -0.08, 0.04, 0.002, 0.04, 0.01, "emit_red", 0.0)
    MUZZLE["weapon_plasma_cutter"] = Vector((0, -0.44, 0.06))
    return b.build()


def rivet_driver():
    """A016-02: pneumatic rivet driver, drum magazine, yellow industrial. 0.88 m. 'Fasteners remain company property.'"""
    b = P.Builder("weapon_rivet_driver")
    b.cyl(0, -0.12, 0.06, 0.04, 0.32, "y", "hazard", 14)              # main cylinder
    b.cyl(0, -0.30, 0.06, 0.048, 0.05, "y", "steel", 14)              # front collar
    b.box(0, -0.38, 0.06, 0.07, 0.10, 0.08, "hazard", 0.01)           # nose block
    b.box(0, -0.435, 0.06, 0.05, 0.02, 0.05, "steel", 0.004)          # driver face
    b.box(0, -0.06, 0.01, 0.05, 0.22, 0.05, "steel", 0.006)           # lower receiver joins it all
    b.cyl(0, -0.13, -0.05, 0.035, 0.08, "z", "hazard", 14)            # drum magazine
    b.cyl(0, -0.13, -0.05, 0.03, 0.06, "z", "brass", 14)              # rivets visible
    b.cyl(0, -0.13, -0.095, 0.037, 0.012, "z", "steel", 14)
    b.box(0, -0.05, 0.135, 0.012, 0.25, 0.012, "steel", 0.002)        # carry handle bar
    for y in (-0.17, 0.07):
        b.box(0, y, 0.11, 0.012, 0.012, 0.05, "steel", 0.002)
    b.cyl(0.035, -0.05, 0.03, 0.01, 0.30, "y", "steel", 8)            # air line
    b.box(0, 0.03, -0.04, 0.034, 0.05, 0.11, "rubber", 0.01, rot=(16, 0, 0))
    b.box(0, -0.01, -0.005, 0.01, 0.06, 0.006, "steel", 0.0)
    b.box(0, 0.20, 0.05, 0.05, 0.32, 0.07, "hazard", 0.01)            # skeletal stock
    b.box(0, 0.21, 0.05, 0.052, 0.18, 0.03, "rubber", 0.0)
    b.box(0, 0.365, 0.05, 0.055, 0.02, 0.10, "rubber", 0.006)
    b.box(0.041, -0.10, 0.06, 0.002, 0.05, 0.012, "emit_red", 0.0)    # pressure lamp
    MUZZLE["weapon_rivet_driver"] = Vector((0, -0.45, 0.06))
    return b.build()


def frag_charge():
    """A016-15: thrown charge, a gripped puck with a pull ring. 0.14 m. 'Disposal fee applies after detonation.'"""
    b = P.Builder("weapon_frag_charge")
    b.cyl(0, 0, 0.0, 0.035, 0.11, "y", "hull", 14)
    for y in (-0.03, 0.0, 0.03):
        b.cyl(0, y, 0.0, 0.038, 0.012, "y", "steel", 14)                # grip bands
    b.cyl(0, -0.058, 0.0, 0.03, 0.01, "y", "hazard", 14)
    b.cyl(0, 0.06, 0.0, 0.02, 0.016, "y", "steel", 10)                 # fuse cap
    b.cyl(0, 0.075, 0.018, 0.012, 0.004, "x", "brass", 12)             # pull ring
    b.box(0.036, 0.0, 0.0, 0.002, 0.012, 0.012, "emit_red", 0.0)
    MUZZLE["weapon_frag_charge"] = Vector((0, 0, 0))
    return b.build()


def decoy_beacon():
    """A016-18: thrown decoy, teal case, speaker grille, orange handle loop, amber light. 0.22 m (body).
    'Attention sold in thirty-second blocks.'"""
    b = P.Builder("weapon_decoy_beacon")
    b.box(0, -0.02, 0.0, 0.04, 0.18, 0.065, "hull", 0.012)            # case
    for y in (-0.10, 0.06):
        b.box(0, y, 0.0, 0.044, 0.02, 0.07, "rubber", 0.008)            # bumpers
    b.cyl(0.021, -0.06, 0.0, 0.022, 0.004, "x", "steel", 16)          # speaker grille
    for i in range(3):
        b.box(0.0235, -0.06, -0.012 + i * 0.012, 0.002, 0.03, 0.004, "rubber", 0.0)
    b.box(0.021, -0.105, 0.0, 0.003, 0.01, 0.016, "emit_red", 0.0)    # amber/red light
    b.box(0, 0.093, 0.025, 0.014, 0.064, 0.012, "hazard", 0.003)      # handle loop
    b.box(0, 0.093, -0.025, 0.014, 0.064, 0.012, "hazard", 0.003)
    b.box(0, 0.12, 0.0, 0.014, 0.012, 0.062, "hazard", 0.003)
    MUZZLE["weapon_decoy_beacon"] = Vector((0, 0, 0))
    return b.build()


WEAPONS = [issue_rifle, budget_shotgun, flare_gun, plasma_cutter, rivet_driver, frag_charge, decoy_beacon]
INFO = {
    "weapon_issue_rifle": ("A016-07", "long gun"), "weapon_budget_shotgun": ("A016-08", "long gun"),
    "weapon_flare_gun": ("A016-04", "sidearm"), "weapon_plasma_cutter": ("A016-01", "long gun"),
    "weapon_rivet_driver": ("A016-02", "long gun"), "weapon_frag_charge": ("A016-15", "thrown"),
    "weapon_decoy_beacon": ("A016-18", "thrown"),
}


def to_gltf(v):  # Blender (x, y, z) -> glTF (x, z, -y)
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


def preview(path):
    """One tile per weapon: side profile (muzzle right) and three-quarter, light card background."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"; scn.cycles.samples = 32; scn.cycles.device = "CPU"
    scn.render.resolution_x, scn.render.resolution_y = 900, 420
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.53, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scn.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40), math.radians(-20), math.radians(-60)); scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    outs = []
    for ob in objs:
        for o in objs:
            o.hide_render = o is not ob
        pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c = (mn + mx) / 2; L = max((mx - mn).y, (mx - mn).z * 2.1, 0.12)
        cam.data.type = "ORTHO"; cam.data.ortho_scale = L * 1.25
        cam.location = c + Vector((-2.0, 0, 0)); cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
        f = path.replace(".png", f"_{ob.name}_side.png"); scn.render.filepath = f; bpy.ops.render.render(write_still=True); outs.append(f)
        cam.data.type = "PERSP"; cam.data.lens = 50
        cam.location = c + Vector((-1.1, -0.9, 0.75)) * L
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        f = path.replace(".png", f"_{ob.name}_34.png"); scn.render.filepath = f; bpy.ops.render.render(write_still=True); outs.append(f)
    return outs


def main():
    os.makedirs(OUT, exist_ok=True)
    cat_path = os.path.join(OUT, "catalogue.json")
    cat = json.load(open(cat_path)) if os.path.exists(cat_path) else {}
    total = 0
    for f in WEAPONS:
        P.reset()
        ob = f()
        d = ob.dimensions
        total += P.export(ob, OUT)
        src, hold = INFO[ob.name]
        cat[ob.name] = {"size_m": [round(d.x, 3), round(d.z, 3), round(d.y, 3)], "role": "weapon", "set": "weapons",
                        "hold": hold, "design": src, "muzzle_m": to_gltf(MUZZLE[ob.name]),
                        "note": "origin at the right-hand grip; forward is +Z"}
    json.dump(cat, open(cat_path, "w"), indent=1)
    print("total tris", total)
    P.reset()
    for f in WEAPONS:
        f()
    preview(os.path.join(OUT, "preview_weapons.png"))


if __name__ == "__main__":
    main()
