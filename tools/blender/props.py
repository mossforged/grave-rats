"""Hard-surface props for the Grave Rats slice, built by script (lead, 2026-10-31).

Run: python3 tools/blender/props.py [out_dir]   (needs the `bpy` module: pip install bpy)
Writes one .glb per prop variant to out_dir (default assets/source/props/) plus preview PNGs.

Conventions (match src/kit):
- metres, origin at the centre of the base, front faces +Z in glTF (Blender -Y);
- width along X, height along Y (glTF), depth along Z;
- material slot names are data/kit.json material keys (clinical, steel, hull, hazard, rubber,
  glass, emit_blue, emit_red, emit_cool), so the game binds its own kit materials by name.
Sizes come from data/deck.json props (console 1.4x1.1x0.6 and side consoles 1.2/1.0 wide,
cabinet 0.6x1.9x0.5, locker bank 2.4 long x 2.0 x 0.6 deep).
"""
import math
import os
import sys

import bpy  # must come first: it makes bmesh and mathutils importable
import bmesh
from mathutils import Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"

# Preview colours only (the game uses its kit materials by slot name).
PREVIEW = {
    "clinical": (0.80, 0.77, 0.68, 0.55, 0.0),
    "steel": (0.12, 0.13, 0.14, 0.45, 0.8),
    "hull": (0.18, 0.36, 0.37, 0.6, 0.2),
    "hazard": (0.85, 0.62, 0.05, 0.6, 0.0),
    "rubber": (0.03, 0.03, 0.03, 0.9, 0.0),
    "glass": (0.02, 0.05, 0.07, 0.08, 0.0),
    "emit_blue": (0.2, 0.6, 1.0, 0.3, 0.0),
    "emit_red": (1.0, 0.1, 0.05, 0.3, 0.0),
    "emit_cool": (0.8, 0.95, 1.0, 0.3, 0.0),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    r, g, b, rough, metal = PREVIEW[name]
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if name.startswith("emit_"):
        bsdf.inputs["Emission Color"].default_value = (r, g, b, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


class Builder:
    """Collects bevelled boxes into one mesh object with named material slots.

    Coordinates here are Blender's: x = width, y = -depth (front at -y), z = height."""

    def __init__(self, name):
        self.name = name
        self.parts = []  # (center, size, material, bevel)

    def box(self, cx, cy, cz, sx, sy, sz, m, bevel=0.008):
        self.parts.append((Vector((cx, cy, cz)), Vector((sx, sy, sz)), m, bevel))

    def build(self):
        objs = []
        for i, (c, s, m, bev) in enumerate(self.parts):
            me = bpy.data.meshes.new(f"{self.name}_{i}")
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * s.x, v.co.y * s.y, v.co.z * s.z)) + c
            if bev > 0:
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bev, min(s) * 0.45),
                                segments=1, affect="EDGES", profile=0.5)
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new(f"{self.name}_{i}", me)
            ob.data.materials.append(mat(m))
            bpy.context.collection.objects.link(ob)
            objs.append(ob)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in objs:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = self.name
        ob.data.name = self.name
        # smooth shading with sharp edges kept by angle
        for p in ob.data.polygons:
            p.use_smooth = True
        if hasattr(ob.data, "set_sharp_from_angle"):
            ob.data.set_sharp_from_angle(angle=math.radians(35))
        return ob


def console(width, height=1.1, depth=0.6):
    """Med/ops console after A007-09..12: ivory panels, dark frame, a dark screen and keyboard
    ledge, a side tower with a vent, a black plinth with a yellow hazard band."""
    b = Builder(f"console_{int(round(width * 1000))}")
    w, h, depth_total = width, height, depth
    d = depth_total - 0.16  # body depth; the keyboard ledge uses the front 0.16 m
    oy = 0.08  # body centre, pushed back
    hy = oy - d / 2  # body front face y
    plinth = 0.10
    b.box(0, oy, plinth / 2, w, d, plinth, "rubber", 0.01)
    b.box(0, hy + 0.004, plinth * 0.55, w * 0.98, 0.012, 0.035, "hazard", 0.0)
    tower_w = min(0.34, w * 0.26)
    main_w = w - tower_w - 0.02
    mx = -w / 2 + main_w / 2
    tx = w / 2 - tower_w / 2
    body_h = 0.62
    # lower cabinet body
    b.box(mx, oy, plinth + body_h / 2, main_w, d, body_h, "clinical", 0.012)
    b.box(mx, hy - 0.004, plinth + body_h * 0.45, main_w * 0.8, 0.012, body_h * 0.62, "clinical", 0.006)  # service hatch
    b.box(mx + main_w * 0.33, hy - 0.012, plinth + body_h * 0.5, 0.06, 0.012, 0.02, "steel", 0.003)  # hatch latch
    # keyboard ledge
    ledge_z = plinth + body_h
    b.box(mx, hy - 0.06, ledge_z + 0.025, main_w * 0.96, 0.18, 0.05, "steel", 0.01)
    b.box(mx, hy - 0.06, ledge_z + 0.055, main_w * 0.7, 0.12, 0.012, "rubber", 0.003)  # keys
    # screen housing, set back
    scr_h = h - ledge_z - 0.04
    b.box(mx, oy + 0.05, ledge_z + scr_h / 2 + 0.02, main_w * 0.92, d * 0.55, scr_h, "steel", 0.015)
    b.box(mx, oy + 0.05 - d * 0.275 - 0.004, ledge_z + scr_h / 2 + 0.03, main_w * 0.74, 0.01, scr_h * 0.7, "glass", 0.0)
    b.box(mx - main_w * 0.3, oy + 0.05 - d * 0.275 - 0.008, ledge_z + scr_h * 0.18, 0.05, 0.006, 0.015, "emit_blue", 0.0)
    # side tower
    b.box(tx, oy, plinth + (h - plinth) / 2, tower_w, d, h - plinth, "clinical", 0.012)
    for i in range(6):
        b.box(tx, hy - 0.004, plinth + 0.18 + i * 0.045, tower_w * 0.6, 0.01, 0.018, "steel", 0.002)  # vent slats
    b.box(tx, hy - 0.006, h - 0.08, tower_w * 0.35, 0.01, 0.03, "emit_red", 0.0)  # status lamp
    # frame trims (dark corner posts)
    for x in (-w / 2 + 0.015, w / 2 - 0.015):
        b.box(x, oy, plinth + (h - plinth) / 2, 0.03, d, h - plinth, "steel", 0.006)
    return b.build()


def cabinet(width=0.6, height=1.9, depth=0.5):
    """Medbay cabinet: glass-fronted upper half with shelves, drawers below, red cross plate."""
    b = Builder("cabinet")
    w, h, d0 = width, height, depth
    d = d0 - 0.03  # carcass; door fronts and the cross plate use the front 0.03 m
    hy = 0.015 - d / 2
    b.box(0, 0.015, 0.04, w, d, 0.08, "rubber", 0.008)
    b.box(0, 0.015, 0.08 + (h - 0.08) / 2, w, d, h - 0.08, "clinical", 0.012)
    split = 0.95
    # glass door with frame
    b.box(0, hy - 0.006, split + (h - split - 0.06) / 2, w * 0.86, 0.012, h - split - 0.08, "steel", 0.004)
    b.box(0, hy - 0.012, split + (h - split - 0.06) / 2, w * 0.76, 0.006, h - split - 0.16, "glass", 0.0)
    for i in range(3):
        b.box(0, 0.02, split + 0.18 + i * 0.22, w * 0.8, d * 0.8, 0.012, "steel", 0.002)  # shelves, inside the carcass
    # drawers
    for i in range(3):
        z = 0.14 + i * 0.26
        b.box(0, hy - 0.006, z + 0.11, w * 0.86, 0.012, 0.22, "clinical", 0.006)
        b.box(0, hy - 0.016, z + 0.17, w * 0.3, 0.012, 0.025, "steel", 0.004)
    # red cross plate
    b.box(0, hy - 0.02, h - 0.06, 0.12, 0.006, 0.035, "emit_red", 0.0)
    b.box(0, hy - 0.02, h - 0.06, 0.035, 0.006, 0.08, "emit_red", 0.0)
    return b.build()


def locker_bank(length=2.4, height=2.0, depth=0.6, count=4):
    """A freestanding, back-to-back bank of crew lockers (an island in the room, seen mostly
    from above): painted (owner teal) doors with vent slots, handles and name plates on BOTH long
    faces; a light clinical top cap with a raised vent grille and a stencil-plate inset, so the top
    reads from the steep camera; a plinth with hazard bands. Length runs along X."""
    b = Builder("locker_bank")
    L, h, d = length, height, depth
    inset = 0.035  # doors and handles use the outer 0.035 m on each face
    core = d - 2 * inset
    b.box(0, 0, 0.05, L, core, 0.1, "rubber", 0.01)
    b.box(0, 0, 0.1 + (h - 0.2) / 2, L, core, h - 0.2, "steel", 0.012)  # carcass, stops under the top cap
    door_w = (L - 0.05) / count
    for side in (-1, 1):  # -1 = front (-y), 1 = back (+y)
        fy = side * (core / 2)  # carcass face
        b.box(0, fy + side * 0.004, 0.055, L * 0.98, 0.012, 0.03, "hazard", 0.0)
        for i in range(count):
            x = -L / 2 + 0.025 + door_w * (i + 0.5)
            dh = h - 0.26
            b.box(x, fy + side * 0.012, 0.12 + dh / 2, door_w - 0.03, 0.02, dh, "hull", 0.008)
            for s_ in range(4):  # vent slots, top
                b.box(x, fy + side * 0.024, h - 0.36 + s_ * 0.04, door_w * 0.5, 0.006, 0.014, "steel", 0.002)
            for s_ in range(3):  # vent slots, bottom
                b.box(x, fy + side * 0.024, 0.3 + s_ * 0.04, door_w * 0.5, 0.006, 0.014, "steel", 0.002)
            hx = x + side * door_w * 0.3
            b.box(hx, fy + side * 0.027, 1.0, 0.03, 0.012, 0.16, "steel", 0.004)  # handle
            b.box(x, fy + side * 0.024, h - 0.52, door_w * 0.4, 0.006, 0.05, "clinical", 0.003)  # name plate
            b.box(x, fy + side * 0.024, 0.2, door_w * 0.12, 0.006, 0.02, "emit_red" if i == 1 else "steel", 0.0)  # lock lamp
    # light top cap: reads from above
    b.box(0, 0, h - 0.075, L, core + 0.04, 0.06, "clinical", 0.012)
    b.box(0, 0, h - 0.028, L, core + 0.04, 0.032, "clinical", 0.008)  # top panel, light
    for i in range(8):  # vent grille across the middle
        b.box(-L * 0.18 + i * 0.05, 0, h - 0.006, 0.028, core * 0.5, 0.012, "steel", 0.002)
    b.box(L * 0.3, 0, h - 0.009, 0.36, core * 0.45, 0.006, "hazard", 0.0)  # stencil plate
    return b.build()


def export(ob, out):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    path = os.path.join(out, f"{ob.name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB",
                              export_apply=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    dims = ob.dimensions
    print(f"{ob.name}: {tris} tris, {dims.x:.3f} x {dims.z:.3f} x {dims.y:.3f} m (w x h x d) -> {path}")
    return tris


def preview(objs, path):
    """Two views per prop: front three-quarter and the steep game camera (~60 deg)."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 24
    scn.cycles.device = "CPU"
    scn.render.resolution_x, scn.render.resolution_y = 1600, 800
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.055, 0.06, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scn.world = world
    x = -sum(o.dimensions.x for o in objs) / 2 - 0.3 * (len(objs) - 1) / 2
    for o in objs:
        o.location.x = x + o.dimensions.x / 2
        x += o.dimensions.x + 0.3
    floor = bpy.data.objects.new("floor", bpy.data.meshes.new("floor"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8)
    bm.to_mesh(floor.data)
    bm.free()
    floor.data.materials.append(mat("steel"))
    scn.collection.objects.link(floor)
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
    sun.data.energy = 900
    sun.data.size = 4
    sun.location = (-2.5, -3.5, 4.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    for tag, loc, rot, lens in (("34", (3.2, -5.6, 2.6), (72, 0, 30), 30),
                                ("game", (0, -4.2, 7.3), (30, 0, 0), 32)):
        cam.location = loc
        cam.rotation_euler = tuple(math.radians(a) for a in rot)
        cam.data.lens = lens
        scn.render.filepath = path.replace(".png", f"_{tag}.png")
        bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    reset()
    built = [console(1.6), console(1.4), console(1.2), console(1.0), cabinet(), locker_bank()]
    total = 0
    for ob in built:
        total += export(ob, OUT)
    print("total tris", total)
    reset()
    objs = [console(1.4), cabinet(), locker_bank()]
    preview(objs, os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
