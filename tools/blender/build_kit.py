"""Dead Circuit environment kit (Blender 5.2 headless): `python3 assets-src/build_kit.py`

Exports dist/assets/kit.glb: one top-level node per kit piece, pivot at floor level.
Conventions (three.js space after export): pieces are 2.2 m grid modules; wall pieces run
along X, their room-facing side faces +Z, height is +Y. Material slots are named after
the shared texture library (dist/src/materials.js) and are bound at runtime.

Hard-surface rules used throughout: every exposed edge is bevelled (light catches the
chamfer, which is what reads as "manufactured" from a steep camera), large planes are
broken by trims, and props carry their own contact base so they sit into the deck.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'source', 'legacy-pass05')
D = math.radians
T = 2.2
WALL_H = 2.6
LOW_H = .78
TH = .40

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = ['wall_panel', 'wall_med', 'dark_metal', 'hull_top', 'floor_plate', 'floor_grate', 'paint_yellow', 'paint_hazard',
        'paint_orange', 'paint_white', 'paint_robot', 'rubber', 'medical_fabric', 'light_white', 'light_amber', 'light_cyan',
        'light_red', 'screen_cyan', 'glass']
for n in MATS:
    bpy.data.materials.new(n)


# ------------------------------------------------------------------ geometry helpers (Blender: Z up, three: Y up, -Y -> +Z)
def box(sx, sy, sz, bevel=.02, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(sx, sy, sz) * .45), offset_type='OFFSET',
                        segments=seg, profile=.5, affect='EDGES', clamp_overlap=True)
    return bm


def tube(a, b, r1, r2=None, seg=16, cap=.0):
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2 or r1, depth=d.length)
    if cap > 0:
        rim = [e for e in bm.edges if all(abs(abs(v.co.z) - d.length / 2) < 1e-5 for v in e.verts) and e.verts[0].co.xy.length > r1 * .6]
        bmesh.ops.bevel(bm, geom=rim, offset=r1 * cap, offset_type='OFFSET', segments=2, profile=.5, affect='EDGES', clamp_overlap=True)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=bm.verts)
    return bm


def ell(rx, ry, rz, u=16, v=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vv in bm.verts:
        vv.co = Vector((vv.co.x * rx, vv.co.y * ry, vv.co.z * rz))
    return bm


def at(bm, loc=(0, 0, 0), rot=(0, 0, 0)):
    m = Matrix.Translation(loc) @ Euler([D(x) for x in rot], 'XYZ').to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def uv_box(scale):
    def fn(co, n):
        ax = max(range(3), key=lambda i: abs(n[i]))
        u, v = {0: (co.y, co.z), 1: (co.x, co.z), 2: (co.x, co.y)}[ax]
        return u * scale, v * scale
    return fn


def uv_wall(co, n):
    """Wall panel texture: one 2.2 m bay across U, full 2.6 m height on V; caps use box mapping."""
    if abs(n.z) > .7:
        return co.x / 1.5, co.y / 1.5
    if abs(n.x) > .7:
        return co.y / T, co.z / WALL_H
    return co.x / T + .5, co.z / WALL_H


def uv_floor(co, n):
    if abs(n.z) > .7:
        return co.x / T + .5, co.y / T + .5
    return co.x / T, co.z / T


PIECES = []


def piece(name, parts):
    """parts: list of (bmesh, material, uv_fn)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    for src, mat, uvf in parts:
        src.normal_update()
        vmap = {v: bm.verts.new(v.co) for v in src.verts}
        for f in src.faces:
            try:
                nf = bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = MATS.index(mat)
            nf.smooth = True
            for loop in nf.loops:
                loop[uv].uv = (uvf or uv_box(1.0))(loop.vert.co, f.normal)
        src.free()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.set_sharp_from_angle(angle=D(35))
    used = sorted({p.material_index for p in me.polygons})
    for n in MATS:
        me.materials.append(bpy.data.materials[n])
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    PIECES.append(ob)
    print(f'{name:22s} tris {sum(len(p.vertices) - 2 for p in me.polygons):6d}  mats {[MATS[i] for i in used]}')
    return ob


# In Blender coordinates the room side of a wall faces -Y (exports to three +Z).
def wall_core(h, mat='wall_panel'):
    P = [(at(box(T, TH, h, .015, 1), (0, 0, h / 2)), mat, uv_wall)]
    # dark structural cap: the thick "cut section" seen from the steep camera
    P.append((at(box(T + .02, TH + .10, .10, .02), (0, .02, h + .05)), 'hull_top', uv_box(.7)))
    P.append((at(box(T, .05, .045, .012), (0, -TH / 2 - .045, h - .02)), 'dark_metal', uv_box(1)))
    # kick plate and mid rail
    P.append((at(box(T, .07, .16, .02), (0, -TH / 2 - .02, .08)), 'dark_metal', uv_box(1)))
    if h > 1.5:
        P.append((at(box(T, .06, .07, .02), (0, -TH / 2 - .03, 1.86)), 'dark_metal', uv_box(1)))
    return P


def build_walls():
    piece('wall_tall', wall_core(WALL_H))
    p = wall_core(WALL_H)
    # ceiling-edge light strip: housing + emissive diffuser (bloom picks it up)
    p.append((at(box(1.5, .16, .12, .02), (0, -TH / 2 - .08, 2.30)), 'dark_metal', uv_box(1)))
    p.append((at(box(1.38, .02, .06, .008), (0, -TH / 2 - .165, 2.29)), 'light_white', None))
    piece('wall_tall_light', p)
    p = wall_core(WALL_H)
    for z, r, m in ((.42, .055, 'paint_orange'), (.62, .045, 'dark_metal'), (.78, .03, 'paint_yellow')):
        p.append((tube((-T / 2, -TH / 2 - .12, z), (T / 2, -TH / 2 - .12, z), r, seg=12), m, uv_box(2)))
        for x in (-.75, .75):
            p.append((tube((x - .04, -TH / 2 - .12, z), (x + .04, -TH / 2 - .12, z), r * 1.45, seg=12), 'dark_metal', uv_box(2)))
    for x in (-.75, .75):
        p.append((at(box(.06, .16, .52, .01), (x, -TH / 2 - .06, .60)), 'dark_metal', uv_box(1)))
    p.append((tube((.3, -TH / 2 - .12, .62), (.3, -TH / 2 - .24, .62), .03, seg=10), 'dark_metal', uv_box(2)))
    p.append((at(box(.16, .03, .16, .01), (.3, -TH / 2 - .25, .62)), 'paint_orange', uv_box(2)))
    piece('wall_tall_pipes', p)
    p = wall_core(WALL_H)
    p.append((at(box(.92, .07, .62, .03), (0, -TH / 2 - .03, 1.25)), 'dark_metal', uv_box(1)))
    for k in range(7):
        p.append((at(box(.80, .04, .025, .006), (0, -TH / 2 - .07, 1.0 + k * .075)), 'rubber', uv_box(1)))
    p.append((at(box(.10, .02, .05, .006), (.38, -TH / 2 - .075, 1.62)), 'light_amber', None))
    piece('wall_tall_vent', p)
    p = wall_core(WALL_H)
    p.append((at(box(.95, .10, .62, .03), (0, -TH / 2 - .045, 1.38)), 'dark_metal', uv_box(1)))
    p.append((at(box(.82, .02, .48, .004), (0, -TH / 2 - .10, 1.38)), 'screen_cyan', None))
    for k in range(4):
        p.append((at(box(.10, .04, .05, .01), (-.3 + k * .2, -TH / 2 - .08, 1.0)), 'light_amber' if k == 0 else 'rubber', None))
    piece('wall_tall_screen', p)
    # medbay walls: pale clinical paint, red-cross plaque on the sign variant
    piece('wall_med', wall_core(WALL_H, 'wall_med'))
    p = wall_core(WALL_H, 'wall_med')
    p.append((at(box(1.5, .16, .12, .02), (0, -TH / 2 - .08, 2.30)), 'dark_metal', uv_box(1)))
    p.append((at(box(1.38, .02, .06, .008), (0, -TH / 2 - .165, 2.29)), 'light_white', None))
    piece('wall_med_light', p)
    p = wall_core(WALL_H, 'wall_med')
    p.append((at(box(.62, .05, .62, .03), (0, -TH / 2 - .02, 1.45)), 'paint_white', uv_box(1)))
    p.append((at(box(.40, .02, .12, .01), (0, -TH / 2 - .05, 1.45)), 'light_red', None))
    p.append((at(box(.12, .02, .40, .01), (0, -TH / 2 - .05, 1.45)), 'light_red', None))
    piece('wall_med_sign', p)
    # cutaway walls between camera and room: low, thick dark top, hazard lip
    p = [(at(box(T, TH, LOW_H, .015, 1), (0, 0, LOW_H / 2)), 'wall_panel', uv_box(1 / 2.2)),
         (at(box(T + .02, TH + .10, .10, .02), (0, -.02, LOW_H + .05)), 'hull_top', uv_box(.7)),
         (at(box(T, .05, .04, .01), (0, -TH / 2 - .05, LOW_H + .02)), 'paint_hazard', uv_box(3)),
         (at(box(T, .07, .16, .02), (0, -TH / 2 - .02, .08)), 'dark_metal', uv_box(1))]
    piece('wall_low', p)
    # pilasters sit on every wall vertex, hiding joints and giving the bay rhythm
    p = [(at(box(.50, .50, WALL_H + .14, .04, 2), (0, 0, (WALL_H + .14) / 2)), 'dark_metal', uv_box(1.2)),
         (at(box(.56, .56, .08, .02), (0, 0, WALL_H + .1)), 'hull_top', uv_box(1)),
         (at(box(.36, .56, .05, .015), (0, 0, 1.2)), 'paint_hazard', uv_box(3)),
         (at(box(.54, .54, .14, .03), (0, 0, .07)), 'rubber', uv_box(1))]
    for z in (.5, 1.8):
        p.append((at(box(.54, .54, .05, .015), (0, 0, z)), 'dark_metal', uv_box(1)))
    piece('post_tall', p)
    piece('post_low', [(at(box(.50, .50, LOW_H + .14, .04, 2), (0, 0, (LOW_H + .14) / 2)), 'dark_metal', uv_box(1.2)),
                       (at(box(.56, .56, .08, .02), (0, 0, LOW_H + .1)), 'hull_top', uv_box(1))])


def build_floors():
    piece('floor_tile', [(at(box(T - .02, T - .02, .12, .012, 1), (0, 0, -.06)), 'floor_plate', uv_floor)])
    p = [(at(box(T - .02, .55, .12, .012, 1), (0, s * .825, -.06)), 'floor_plate', uv_floor) for s in (-1, 1)]
    p.append((at(box(1.1, T - .02, .03, .004, 1), (0, 0, -.11)), 'rubber', uv_box(1)))
    p.append((at(box(T - .02, 1.08, .025, .004, 1), (0, 0, -.025)), 'floor_grate', lambda co, n: (co.x / 1.1, co.y / 1.1)))
    for s in (-1, 1):
        p.append((at(box(T - .02, .05, .03, .008), (0, s * .53, -.01)), 'paint_yellow', uv_box(2)))
    p.append((at(box(T - .02, T - .02, .02), (0, 0, -.13)), 'dark_metal', uv_box(1)))
    piece('floor_grate_tile', p)


def build_door():
    W = 4.35
    p = []
    for s in (-1, 1):
        p.append((at(box(.5, .7, 2.75, .04, 2), (s * (W / 2 + .2), 0, 1.375)), 'dark_metal', uv_box(1)))
        p.append((at(box(.06, .72, 2.3, .01), (s * (W / 2 - .02), 0, 1.15)), 'paint_hazard', uv_box(2.5)))
        p.append((at(box(.08, .06, .30, .01), (s * (W / 2 + .2), -.37, 1.25)), 'light_amber', None))
    p.append((at(box(W + 1.0, .7, .42, .04, 2), (0, 0, 2.62)), 'dark_metal', uv_box(1)))
    p.append((at(box(W + 1.04, .76, .08, .02), (0, 0, 2.86)), 'hull_top', uv_box(1)))
    p.append((at(box(W * .7, .02, .1, .01), (0, -.36, 2.55)), 'paint_hazard', uv_box(2.5)))
    p.append((at(box(.3, .02, .06, .01), (0, -.37, 2.68)), 'light_red', None))
    p.append((at(box(W, .36, .05, .01), (0, 0, .025)), 'paint_hazard', uv_box(1.2)))
    piece('door_frame', p)
    # one sliding leaf (instanced twice, mirrored); pivot at the jamb, extends toward +X
    L = W / 2 + .02
    p = [(at(box(L, .22, 2.32, .03, 2), (L / 2, 0, 1.18)), 'wall_panel', uv_box(1 / 2.2)),
         (at(box(.08, .26, 2.32, .02), (L - .04, 0, 1.18)), 'paint_hazard', uv_box(3)),
         (at(box(L * .8, .24, .45, .02), (L * .45, 0, .40)), 'dark_metal', uv_box(1)),
         (at(box(.22, .25, .9, .02), (L * .45, 0, 1.55)), 'glass', uv_box(1))]
    piece('door_leaf', p)


def build_props():
    # ---------- medbay
    p = [(at(box(1.05, 2.25, .12, .03), (0, 0, .62)), 'dark_metal', uv_box(1)),
         (at(box(.95, 2.05, .16, .07, 3), (0, 0, .76)), 'medical_fabric', lambda co, n: (co.x / 1.0 + .5, co.y / 2.0 + .5)),
         (at(box(.7, .38, .1, .05, 3), (0, .80, .88)), 'paint_white', uv_box(2)),
         (at(box(.9, .25, .5, .04), (0, -.98, .45)), 'paint_white', uv_box(1))]
    for sx in (-.42, .42):
        for sy in (-.85, .85):
            p.append((tube((sx, sy, .05), (sx, sy, .56), .035, seg=10), 'dark_metal', uv_box(2)))
            p.append((tube((sx, sy, .02), (sx, sy, .07), .06, seg=10), 'rubber', uv_box(2)))
        p.append((tube((sx * 1.18, -.7, .82), (sx * 1.18, .7, .82), .02, seg=8), 'dark_metal', uv_box(2)))
    # monitor boom with live screen
    p += [(tube((.62, -.9, .1), (.62, -.9, 1.55), .03, seg=10), 'dark_metal', uv_box(2)),
          (at(box(.46, .06, .32, .02), (.62, -.65, 1.45), (-25, 0, 0)), 'dark_metal', uv_box(1)),
          (at(box(.40, .01, .26, .004), (.62, -.615, 1.455), (-25, 0, 0)), 'screen_cyan', None),
          (tube((.62, -.9, 1.5), (.62, -.68, 1.47), .02, seg=8), 'dark_metal', uv_box(2))]
    piece('med_bed', p)
    p = [(at(box(1.6, .55, 1.95, .03), (0, 0, .975)), 'paint_white', uv_box(1)),
         (at(box(1.5, .02, 1.1, .01), (0, -.28, 1.25)), 'glass', uv_box(1)),
         (at(box(1.62, .58, .1, .02), (0, 0, 1.98)), 'dark_metal', uv_box(1)),
         (at(box(1.5, .04, .55, .02), (0, -.27, .38)), 'paint_white', uv_box(1)),
         (at(box(.3, .02, .05, .01), (0, -.30, .62)), 'light_cyan', None)]
    for k in range(3):
        for j in range(4):
            p.append((at(box(.22, .25, .16 + (j % 2) * .06, .02), (-.55 + j * .36, -.02, .9 + k * .36 + .09)), 'paint_white' if (j + k) % 3 else 'paint_orange', uv_box(2)))
    piece('med_cabinet', p)
    p = [(at(box(1.6, .7, .9, .03), (0, 0, .45)), 'paint_white', uv_box(1)),
         (at(box(1.66, .76, .06, .02), (0, 0, .93)), 'dark_metal', uv_box(1)),
         (at(box(.7, .08, .48, .02), (-.38, .2, 1.24), (-12, 0, 0)), 'dark_metal', uv_box(1)),
         (at(box(.62, .01, .40, .004), (-.38, .155, 1.24), (-12, 0, 0)), 'screen_cyan', None),
         (at(box(.5, .08, .36, .02), (.42, .22, 1.18), (-12, 0, 8)), 'dark_metal', uv_box(1)),
         (at(box(.44, .01, .30, .004), (.42, .175, 1.18), (-12, 0, 8)), 'screen_cyan', None),
         (at(box(.55, .25, .03, .01), (0, -.2, .975)), 'rubber', uv_box(1))]
    for k in range(5):
        p.append((at(box(.06, .06, .02, .005), (-.5 + k * .25, -.3, .97)), 'light_amber' if k == 2 else 'dark_metal', None))
    piece('med_console', p)
    piece('stool', [(tube((0, 0, .05), (0, 0, .5), .03, seg=10), 'dark_metal', uv_box(2)),
                    (tube((0, 0, .5), (0, 0, .58), .2, seg=20, cap=.3), 'rubber', uv_box(2)),
                    (tube((0, 0, 0), (0, 0, .06), .24, .18, seg=20), 'dark_metal', uv_box(2))])
    p = [(tube((0, 0, .02), (0, 0, 1.75), .02, seg=8), 'dark_metal', uv_box(2)),
         (tube((0, 0, 0), (0, 0, .04), .22, seg=5), 'dark_metal', uv_box(2)),
         (at(box(.12, .05, .2, .03), (.1, 0, 1.6)), 'glass', uv_box(2)),
         (tube((-.12, 0, 1.75), (.12, 0, 1.75), .012, seg=6), 'dark_metal', uv_box(2))]
    piece('iv_stand', p)
    # ---------- cargo
    def crate(name, w, d, h, paint, stripe=True, icon=None):
        p = [(at(box(w, d, h, .05, 2), (0, 0, h / 2)), paint, uv_box(1.1))]
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append((at(box(.12, .12, h + .02, .025), (sx * (w / 2 - .05), sy * (d / 2 - .05), h / 2)), 'dark_metal', uv_box(1)))
        for z in (.06, h - .06):
            p.append((at(box(w + .02, d + .02, .1, .025), (0, 0, z)), 'dark_metal', uv_box(1)))
        if stripe:
            p.append((at(box(w * .4, d + .03, .12, .01), (0, 0, h * .55)), 'paint_hazard', uv_box(3)))
        # lid: inset panel, latches, lifting rails and a stencil stripe, because from the steep camera the top IS the crate
        p.append((at(box(w - .34, d - .34, .05, .02), (0, 0, h + .015)), 'dark_metal', uv_box(1)))
        p.append((at(box(w - .44, d - .44, .04, .015), (0, 0, h + .035)), paint, uv_box(1.1)))
        for s_ in (-1, 1):
            p.append((at(box(w * .55, .06, .05, .015), (0, s_ * (d / 2 - .26), h + .06)), 'dark_metal', uv_box(1)))
            p.append((at(box(.12, .1, .05, .012), (s_ * (w / 2 - .1), 0, h - .06)), 'rubber', uv_box(1)))
        p.append((at(box(.14, d - .5, .012, .004), (w * .28, 0, h + .056)), 'paint_hazard' if paint != 'paint_yellow' else 'dark_metal', uv_box(3)))
        for s in (-1, 1):
            p.append((at(box(.22, .06, .06, .02), (s * w * .25, -d / 2 - .03, h * .78)), 'rubber', uv_box(1)))
        if icon == 'ammo':
            for k in range(3):
                p.append((tube((-.12 + k * .12, -d / 2 - .015, h * .33), (-.12 + k * .12, -d / 2 - .015, h * .33 + .18), .03, seg=8), 'dark_metal', None))
        p.append((at(box(.1, .02, .04, .008), (w * .3, -d / 2 - .02, h * .9)), 'light_amber' if paint != 'paint_robot' else 'light_cyan', None))
        piece(name, p)
    crate('crate_large', 1.9, 1.7, 1.25, 'paint_robot')
    crate('crate_tall', 1.5, 1.5, 1.7, 'paint_robot', stripe=False)
    crate('crate_yellow', 1.5, 1.2, 1.0, 'paint_yellow', stripe=False, icon='ammo')
    crate('crate_small', .9, .8, .7, 'paint_orange', stripe=False)
    p = [(at(box(2.6, 2.1, .14, .02), (0, 0, .07)), 'dark_metal', uv_box(1))]
    for x in (-1.1, 0, 1.1):
        p.append((at(box(.18, 2.1, .1, .01), (x, 0, .15)), 'paint_yellow', uv_box(2)))
    piece('pallet', p)
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append((at(box(.08, .08, 2.2, .015), (sx * 1.0, sy * .32, 1.1)), 'paint_yellow', uv_box(1)))
    for z in (.18, .9, 1.62):
        p.append((at(box(2.1, .72, .05, .01), (0, 0, z)), 'dark_metal', uv_box(1)))
        for k in range(3):
            w = .4 + (k * 37 % 5) * .06
            p.append((at(box(w, .5, .32 + (k % 2) * .12, .02), (-.65 + k * .62, 0, z + .2 + (k % 2) * .06)), ['paint_robot', 'paint_white', 'paint_orange'][(k + int(z * 10)) % 3], uv_box(1.5)))
    piece('shelf', p)
    p = [(tube((0, 0, 0), (0, 0, 1.05), .32, seg=20, cap=.15), 'paint_orange', uv_box(1.2)),
         (tube((0, 0, .98), (0, 0, 1.08), .34, seg=20), 'dark_metal', uv_box(2)),
         (tube((0, 0, .04), (0, 0, .12), .34, seg=20), 'dark_metal', uv_box(2)),
         (at(box(.25, .02, .3, .01), (0, -.325, .6)), 'paint_hazard', uv_box(3))]
    piece('canister', p)
    # ---------- pickups (small, readable silhouettes)
    piece('pickup_ammo', [(at(box(.62, .40, .32, .04), (0, 0, .16)), 'paint_yellow', uv_box(2)),
                          (at(box(.64, .42, .05, .015), (0, 0, .30)), 'dark_metal', uv_box(2)),
                          (at(box(.2, .02, .06, .01), (0, -.21, .2)), 'light_cyan', None)])
    piece('pickup_med', [(at(box(.62, .42, .26, .05), (0, 0, .13)), 'paint_white', uv_box(2)),
                         (at(box(.36, .1, .025, .01), (0, 0, .27)), 'light_red', None),
                         (at(box(.1, .36, .025, .01), (0, 0, .27)), 'light_red', None),
                         (at(box(.5, .06, .05, .01), (0, .23, .2)), 'rubber', uv_box(2))])
    piece('pickup_recorder', [(at(box(.7, .5, .42, .06), (0, 0, .21)), 'paint_orange', uv_box(2)),
                              (at(box(.5, .52, .06, .02), (0, 0, .30)), 'dark_metal', uv_box(2)),
                              (at(box(.24, .02, .1, .01), (0, -.26, .24)), 'light_amber', None),
                              (tube((.25, .15, .42), (.25, .15, .7), .01, seg=6), 'dark_metal', None)])
    # ---------- corridor dressing
    piece('floor_hatch', [(at(box(1.2, 1.2, .03, .02), (0, 0, .012)), 'dark_metal', uv_box(1)),
                          (at(box(1.0, 1.0, .02, .01), (0, 0, .025)), 'floor_grate', lambda co, n: (co.x, co.y)),
                          (at(box(1.24, .08, .035, .01), (0, .6, .012)), 'paint_hazard', uv_box(3)),
                          (at(box(1.24, .08, .035, .01), (0, -.6, .012)), 'paint_hazard', uv_box(3))])
    p = []
    pts = [(-1.0, 0, .02), (-.5, .15, .03), (0, -.1, .02), (.6, .1, .03), (1.0, -.05, .02)]
    for (a, b) in zip(pts, pts[1:]):
        for o, m in ((0, 'rubber'), (.06, 'paint_orange'), (-.06, 'rubber')):
            p.append((tube((a[0], a[1] + o, a[2] + .02), (b[0], b[1] + o, b[2] + .02), .025, seg=8), m, None))
    piece('cable_run', p)


build_walls()
build_floors()
build_door()
build_props()
bpy.ops.object.select_all(action='DESELECT')
for o in PIECES:
    o.select_set(True)
path = os.path.join(OUT, 'kit.glb')
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=False,
                          export_image_format='NONE', export_yup=True, export_apply=False, export_extras=False)
print('exported', path, os.path.getsize(path) // 1024, 'KB')
