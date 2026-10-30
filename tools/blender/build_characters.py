"""Dead Circuit character pipeline (Blender 5.2, runs headless: `python3 assets-src/build_characters.py`).

Builds two characters on ONE shared humanoid skeleton so every clip works on both:
  * operator.glb  - salvage operator: orange pressure suit, white helmet, life-support pack,
                    AR-4 rifle + SG-8 shotgun (toggle by mesh name), all animation clips.
  * robot.glb     - Kestrel security unit: same skeleton, no clips (it borrows the operator's).

Pipeline:
  1. Armature with deform bones + non-deform IK targets / poles.
  2. Meshes built from bevelled / tapered primitives in armature space, box-mapped UVs at
     a consistent texel density, rigid weights per part plus blended weights across bellows joints.
  3. Clips authored as keyed poses in armature-space axes (X right, Y forward, Z up).
  4. Arm IK (hands on the weapon), leg IK (planted feet in idle/crouch) evaluated and baked
     to plain FK keys ("visual keying"), then constraints removed so the export is engine-clean.
  5. Validation: roll clip's skinned mesh is sampled every frame and must stay above the deck.
Material slots are named after texture sets in dist/assets/tex; the game binds PBR maps by name.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'source', 'legacy-pass05')
os.makedirs(OUT, exist_ok=True)
FPS = 30
D = math.radians

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

MATS = ['suit_fabric', 'paint_orange', 'paint_white', 'rubber', 'dark_metal', 'visor',
        'light_cyan', 'light_amber', 'paint_robot', 'light_red']
PREVIEW = {'suit_fabric': (.6, .25, .08), 'paint_orange': (.7, .28, .06), 'paint_white': (.75, .76, .72),
           'rubber': (.03, .03, .03), 'dark_metal': (.08, .09, .1), 'visor': (.01, .02, .03),
           'light_cyan': (.3, .9, 1), 'light_amber': (1, .6, .2), 'paint_robot': (.1, .12, .13), 'light_red': (1, .1, .05)}
for n in MATS:
    m = bpy.data.materials.new(n)
    m.diffuse_color = (*PREVIEW[n], 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*PREVIEW[n], 1)
MI = {n: i for i, n in enumerate(MATS)}

# ------------------------------------------------------------------ skeleton
BONES = [  # name, head, tail, parent, deform
    ('root', (0, 0, 0), (0, .25, 0), None, True),
    ('pelvis', (0, 0, .98), (0, 0, 1.10), 'root', True),
    ('spine1', (0, 0, 1.10), (0, 0, 1.26), 'pelvis', True),
    ('spine2', (0, 0, 1.26), (0, 0, 1.46), 'spine1', True),
    ('neck', (0, 0, 1.46), (0, 0, 1.56), 'spine2', True),
    ('head', (0, 0, 1.56), (0, 0, 1.80), 'neck', True),
    ('weapon', (.13, .10, 1.30), (.13, .40, 1.30), 'spine2', True),
    ('mag', (.13, .37, 1.24), (.13, .37, 1.12), 'weapon', True),
    ('ik_hand_R', (.13, .30, 1.19), (.13, .36, 1.12), 'weapon', False),
    ('ik_hand_L', (.12, .55, 1.24), (.12, .60, 1.17), 'weapon', False),
    ('pole_R', (.60, -.25, .95), (.60, -.15, .95), 'spine2', False),
    ('pole_L', (-.55, .10, .90), (-.55, .20, .90), 'spine2', False),
]
for s, side in ((1, 'R'), (-1, 'L')):
    BONES += [
        (f'clavicle_{side}', (s * .05, 0, 1.42), (s * .19, 0, 1.44), 'spine2', True),
        (f'upperarm_{side}', (s * .21, 0, 1.42), (s * .25, 0, 1.11), f'clavicle_{side}', True),
        (f'forearm_{side}', (s * .25, 0, 1.11), (s * .27, .02, .84), f'upperarm_{side}', True),
        (f'hand_{side}', (s * .27, .02, .84), (s * .28, .03, .75), f'forearm_{side}', True),
        (f'thigh_{side}', (s * .11, 0, .96), (s * .12, 0, .54), 'pelvis', True),
        (f'shin_{side}', (s * .12, 0, .54), (s * .12, -.01, .11), f'thigh_{side}', True),
        (f'foot_{side}', (s * .12, -.01, .11), (s * .12, .15, .03), f'shin_{side}', True),
        (f'ik_foot_{side}', (s * .12, -.01, .11), (s * .12, .15, .03), 'root', False),
        (f'pole_knee_{side}', (s * .14, .70, .55), (s * .14, .80, .55), 'pelvis', False),
    ]

arm_data = bpy.data.armatures.new('Rig')
rig = bpy.data.objects.new('Rig', arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, parent, deform in BONES:
    b = arm_data.edit_bones.new(name)
    b.head, b.tail, b.roll = h, t, 0
    b.use_deform = deform
for name, h, t, parent, deform in BONES:
    if parent:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
DEFORM = [b[0] for b in BONES if b[4]]

# ------------------------------------------------------------------ mesh helpers
class Part:
    def __init__(self, bm, mat, bone=None, blend=None):
        self.bm, self.mat, self.bone, self.blend = bm, mat, bone, blend


def bm_box(sx, sy, sz, bevel=.02, seg=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(sx, sy, sz) * .49), offset_type='OFFSET',
                        segments=seg, profile=.5, affect='EDGES', clamp_overlap=True)
    return bm


def bm_ell(rx, ry, rz, u=24, v=14, half=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    if half:
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -.05], context='VERTS')
    for vv in bm.verts:
        vv.co = Vector((vv.co.x * rx, vv.co.y * ry, vv.co.z * rz))
    return bm


def bm_tube(a, b, r1, r2, seg=18, round_ends=.5, sy=1.0):
    """Tapered cylinder from point a to b with rounded rims (bevelled caps)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=d.length)
    if round_ends > 0:
        rim = [e for e in bm.edges if abs(abs(e.verts[0].co.z) - d.length / 2) < 1e-5 and abs(abs(e.verts[1].co.z) - d.length / 2) < 1e-5
               and e.verts[0].co.xy.length > min(r1, r2) * .5]
        bmesh.ops.bevel(bm, geom=rim, offset=min(r1, r2) * round_ends, offset_type='OFFSET', segments=3, profile=.5,
                        affect='EDGES', clamp_overlap=True)
    for v in bm.verts:
        v.co.y *= sy
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=bm.verts)
    return bm


def bm_torus(R, r, seg=24, rseg=8, sy=1.0):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = i / seg * math.tau
        ring = []
        for j in range(rseg):
            b = j / rseg * math.tau
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a) * sy
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = rings[i][j], rings[i][(j + 1) % rseg]
            c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[(i + 1) % seg][j]
            bm.faces.new((a, b, c, d))
    return bm


def place(bm, loc=(0, 0, 0), rot=(0, 0, 0)):
    m = Matrix.Translation(loc) @ Euler([D(x) for x in rot], 'XYZ').to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def smoothstep(e0, e1, x):
    t = max(0, min(1, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def joint_blend(bone_a, bone_b, center, axis, width):
    """Weights blend from bone_a to bone_b across a joint along an axis (armature space)."""
    c, ax = Vector(center), Vector(axis).normalized()
    def fn(co):
        t = smoothstep(-width, width, (co - c).dot(ax))
        return {bone_a: 1 - t, bone_b: t}
    return fn


def build_mesh(name, parts, uv_scale=1.6):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    dl = bm.verts.layers.deform.verify()
    gidx = {n: i for i, n in enumerate(DEFORM)}
    for p in parts:
        p.bm.normal_update()
        vmap = {}
        for v in p.bm.verts:
            nv = bm.verts.new(v.co)
            w = p.blend(v.co) if p.blend else {p.bone: 1.0}
            for bn, wt in w.items():
                if wt > 1e-3:
                    nv[dl][gidx[bn]] = wt
            vmap[v] = nv
        for f in p.bm.faces:
            try:
                nf = bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = MI[p.mat]
            nf.smooth = True
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for loop in nf.loops:
                co = loop.vert.co
                uvs = {0: (co.y, co.z), 1: (co.x, co.z), 2: (co.x, co.y)}[ax]
                loop[uv].uv = (uvs[0] * uv_scale, uvs[1] * uv_scale)
        p.bm.free()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.set_sharp_from_angle(angle=D(38))
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for n in MATS:
        me.materials.append(bpy.data.materials[n])
    for n in DEFORM:
        ob.vertex_groups.new(name=n)
    ob.parent = rig
    mod = ob.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig
    return ob


# ------------------------------------------------------------------ operator meshes
def operator_parts():
    P = []
    add = lambda bm, mat, bone=None, blend=None: P.append(Part(bm, mat, bone, blend))
    # pelvis / belt
    add(place(bm_box(.40, .27, .20, .07), (0, 0, .97)), 'suit_fabric', 'pelvis')
    add(place(bm_box(.43, .30, .06, .02), (0, 0, 1.06)), 'rubber', 'pelvis')
    add(place(bm_box(.12, .03, .075, .012), (0, .155, 1.06)), 'dark_metal', 'pelvis')
    add(place(bm_box(.15, .05, .13, .03), (0, .125, .94), (-8, 0, 0)), 'paint_orange', 'pelvis')
    for s in (1, -1):
        add(place(bm_box(.07, .13, .12, .02), (s * .225, .02, .975)), 'dark_metal', 'pelvis')
    for s, side in ((1, 'R'), (-1, 'L')):
        th, sh, ft = f'thigh_{side}', f'shin_{side}', f'foot_{side}'
        add(bm_tube((s * .11, 0, .97), (s * .12, 0, .57), .118, .092), 'suit_fabric', blend=joint_blend('pelvis', th, (0, 0, .90), (0, 0, -1), .06))
        add(place(bm_box(.135, .05, .22, .02), (s * .12, .085, .77), (-3, 0, 0)), 'paint_orange', th)
        add(place(bm_box(.045, .12, .13, .015), (s * .225, 0, .80)), 'dark_metal', th)
        for k in range(3):
            add(place(bm_torus(.094, .022, 20, 6), (s * .12, 0, .585 - k * .03)), 'rubber',
                blend=joint_blend(th, sh, (s * .12, 0, .54), (0, 0, -1), .04))
        add(place(bm_box(.12, .05, .12, .035), (s * .12, .078, .52), (-10, 0, 0)), 'paint_white', sh)
        add(bm_tube((s * .12, 0, .52), (s * .12, -.01, .17), .09, .079), 'suit_fabric', sh)
        add(place(bm_box(.12, .05, .25, .02), (s * .12, .07, .35), (4, 0, 0)), 'paint_orange', sh)
        add(bm_tube((s * .12, -.01, .21), (s * .12, -.01, .14), .098, .1, round_ends=.3), 'rubber', blend=joint_blend(sh, ft, (s * .12, 0, .16), (0, 0, -1), .03))
        add(place(bm_box(.145, .27, .12, .04), (s * .12, .045, .08)), 'dark_metal', ft)
        add(place(bm_box(.155, .30, .035, .012), (s * .12, .05, .018)), 'rubber', ft)
        add(place(bm_box(.13, .07, .07, .03), (s * .12, .165, .075)), 'rubber', ft)
    # abdomen bellows, chest armour, life support
    add(place(bm_ell(.19, .15, .13), (0, 0, 1.17)), 'suit_fabric', blend=joint_blend('pelvis', 'spine1', (0, 0, 1.12), (0, 0, 1), .06))
    for k in range(2):
        add(place(bm_torus(.17, .026, 24, 6, sy=.8), (0, 0, 1.11 + k * .04)), 'rubber', blend=joint_blend('pelvis', 'spine1', (0, 0, 1.12), (0, 0, 1), .05))
    add(place(bm_box(.47, .31, .29, .085), (0, .02, 1.35)), 'paint_orange', blend=joint_blend('spine1', 'spine2', (0, 0, 1.26), (0, 0, 1), .05))
    add(place(bm_box(.30, .045, .19, .03), (0, .17, 1.37), (-6, 0, 0)), 'paint_white', 'spine2')
    for s in (1, -1):
        add(place(bm_box(.045, .02, .27, .008), (s * .125, .18, 1.33)), 'dark_metal', 'spine2')
    add(place(bm_box(.055, .02, .03, .006), (.15, .19, 1.45)), 'light_cyan', 'spine2')
    add(place(bm_box(.04, .02, .025, .006), (-.15, .19, 1.45)), 'light_amber', 'spine2')
    add(place(bm_torus(.13, .042, 24, 8), (0, 0, 1.49)), 'rubber', 'spine2')
    add(place(bm_box(.44, .045, .50, .015), (0, -.165, 1.30)), 'dark_metal', 'spine2')
    add(place(bm_box(.40, .19, .45, .05), (0, -.26, 1.30)), 'paint_white', 'spine2')
    for s in (1, -1):
        add(bm_tube((s * .12, -.38, 1.11), (s * .12, -.38, 1.49), .062, .062, round_ends=.8), 'dark_metal', 'spine2')
    add(place(bm_box(.11, .012, .025, .004), (0, -.36, 1.46)), 'light_cyan', 'spine2')
    add(place(bm_box(.05, .012, .025, .004), (0, -.36, 1.42)), 'light_amber', 'spine2')
    add(place(bm_box(.22, .02, .11, .01), (0, -.357, 1.20)), 'rubber', 'spine2')
    add(bm_tube((0, 0, 1.47), (0, 0, 1.58), .085, .08, round_ends=0), 'rubber', blend=joint_blend('spine2', 'neck', (0, 0, 1.50), (0, 0, 1), .03))
    # arms
    for s, side in ((1, 'R'), (-1, 'L')):
        ua, fa, hd = f'upperarm_{side}', f'forearm_{side}', f'hand_{side}'
        add(place(bm_ell(.13, .15, .11, 20, 12, half=True), (s * .25, 0, 1.40), (0, s * 12, 0)), 'paint_orange', ua)
        add(bm_tube((s * .22, 0, 1.40), (s * .25, 0, 1.13), .078, .066), 'suit_fabric', blend=joint_blend(f'clavicle_{side}', ua, (s * .21, 0, 1.43), (s * .3, 0, -1), .04))
        for k in range(2):
            add(place(bm_torus(.068, .018, 18, 6), (s * .25, 0, 1.125 - k * .025)), 'rubber',
                blend=joint_blend(ua, fa, (s * .25, 0, 1.11), (0, 0, -1), .03))
        add(bm_tube((s * .25, 0, 1.09), (s * .27, .02, .87), .068, .058), 'suit_fabric', fa)
        add(place(bm_box(.105, .115, .16, .03), (s * .262, .012, .975)), 'paint_orange', fa)
        add(bm_tube((s * .268, .02, .885), (s * .27, .02, .855), .066, .066, round_ends=.3), 'rubber', fa)
        add(place(bm_box(.085, .105, .115, .035), (s * .277, .028, .79)), 'rubber', hd)
    add(place(bm_box(.03, .065, .045, .006), (-.30, .02, .975)), 'light_cyan', 'forearm_L')
    # helmet
    add(place(bm_ell(.168, .178, .172, 32, 20), (0, 0, 1.665)), 'paint_white', 'head')
    add(place(bm_box(.045, .30, .045, .02), (0, -.02, 1.83)), 'dark_metal', 'head')
    add(place(bm_ell(.142, .095, .105, 28, 16), (0, .105, 1.665)), 'visor', 'head')
    add(place(bm_torus(.118, .016, 28, 6, sy=.7), (0, .105, 1.665), (90, 0, 0)), 'dark_metal', 'head')
    for s in (1, -1):
        add(bm_tube((s * .15, 0, 1.665), (s * .19, 0, 1.665), .052, .046, round_ends=.4), 'dark_metal', 'head')
    add(place(bm_box(.05, .07, .045, .01), (.155, .06, 1.765)), 'dark_metal', 'head')
    add(place(bm_box(.036, .012, .028, .004), (.155, .097, 1.765)), 'light_cyan', 'head')
    add(bm_tube((-.13, -.07, 1.76), (-.13, -.07, 1.96), .006, .004, seg=6, round_ends=0), 'dark_metal', 'head')
    return P


def weapon_parts(kind):
    """Weapon modelled in weapon-bone space (origin = stock butt, +Y = barrel)."""
    o = Vector((.13, .10, 1.30))
    P = []
    def add(bm, mat, bone='weapon'):
        bmesh.ops.transform(bm, matrix=Matrix.Translation(o), verts=bm.verts)
        P.append(Part(bm, mat, bone))
    if kind == 'rifle':
        add(place(bm_box(.045, .20, .085, .02), (0, .10, -.015)), 'dark_metal')
        add(place(bm_box(.062, .30, .10, .018), (0, .32, 0)), 'dark_metal')
        add(place(bm_box(.036, .17, .035, .006), (0, .33, .066)), 'dark_metal')
        add(place(bm_box(.03, .035, .03, .006), (0, .30, .095)), 'light_amber')
        add(place(bm_box(.068, .22, .082, .02), (0, .56, -.005)), 'rubber')
        add(place(bm_box(.07, .05, .016, .004), (0, .49, .037)), 'paint_orange')
        add(bm_tube((0, .66, .005), (0, .86, .005), .017, .017, seg=10, round_ends=0), 'dark_metal')
        add(bm_tube((0, .84, .005), (0, .91, .005), .026, .026, seg=10, round_ends=.3), 'dark_metal')
        add(place(bm_box(.04, .05, .11, .012), (0, .20, -.09), (18, 0, 0)), 'rubber')
        add(place(bm_box(.036, .07, .15, .012), (0, .37, -.115), (-10, 0, 0)), 'dark_metal', 'mag')
    else:
        add(place(bm_box(.05, .22, .10, .022), (0, .10, -.015)), 'rubber')
        add(place(bm_box(.072, .26, .11, .02), (0, .32, 0)), 'dark_metal')
        add(bm_tube((0, .44, .02), (0, .84, .02), .025, .025, seg=12, round_ends=0), 'dark_metal')
        add(bm_tube((0, .44, -.035), (0, .76, -.035), .018, .018, seg=10, round_ends=0), 'dark_metal')
        add(place(bm_box(.068, .15, .065, .02), (0, .58, -.035)), 'rubber')
        add(place(bm_box(.04, .05, .11, .012), (0, .20, -.09), (18, 0, 0)), 'rubber')
        for k in range(4):
            add(bm_tube((.04, .27 + k * .035, .0), (.055, .27 + k * .035, .0), .012, .012, seg=8, round_ends=0), 'paint_orange')
        add(place(bm_box(.074, .05, .016, .004), (0, .36, .057)), 'paint_orange')
    return P


def robot_parts():
    P = []
    add = lambda bm, mat, bone=None, blend=None: P.append(Part(bm, mat, bone, blend))
    ch = lambda sx, sy, sz, b=.025: bm_box(sx, sy, sz, b, 1)  # chamfered hard-surface panels
    add(place(ch(.36, .24, .16), (0, 0, .98)), 'paint_robot', 'pelvis')
    add(place(ch(.14, .12, .16, .01), (0, .02, .95)), 'dark_metal', 'pelvis')
    add(place(ch(.08, .02, .02, .005), (0, .13, 1.0)), 'light_red', 'pelvis')
    for s, side in ((1, 'R'), (-1, 'L')):
        th, sh, ft = f'thigh_{side}', f'shin_{side}', f'foot_{side}'
        add(place(bm_ell(.08, .08, .08, 16, 10), (s * .12, 0, .95)), 'dark_metal', blend=joint_blend('pelvis', th, (0, 0, .95), (0, 0, -1), .04))
        add(bm_tube((s * .11, 0, .93), (s * .12, 0, .56), .05, .045, seg=12), 'dark_metal', th)
        add(place(ch(.15, .14, .30), (s * .125, .025, .76), (-4, 0, 0)), 'paint_robot', th)
        add(place(bm_ell(.07, .07, .07, 16, 10), (s * .12, 0, .54)), 'dark_metal', blend=joint_blend(th, sh, (0, 0, .54), (0, 0, -1), .03))
        add(place(ch(.09, .07, .11), (s * .12, .075, .53), (-15, 0, 0)), 'paint_robot', sh)
        add(bm_tube((s * .12, 0, .52), (s * .12, -.01, .14), .042, .038, seg=12), 'dark_metal', sh)
        add(place(ch(.13, .12, .27), (s * .12, .02, .33), (5, 0, 0)), 'paint_robot', sh)
        add(place(ch(.16, .28, .09), (s * .12, .05, .05)), 'paint_robot', ft)
        for k in (-1, 0, 1):
            add(place(ch(.035, .08, .05, .01), (s * .12 + k * .05, .21, .03)), 'dark_metal', ft)
    add(bm_tube((0, 0, 1.06), (0, 0, 1.28), .06, .06, seg=12), 'dark_metal', blend=joint_blend('pelvis', 'spine1', (0, 0, 1.12), (0, 0, 1), .04))
    for k in range(3):
        add(place(ch(.28 - k * .02, .17, .025, .006), (0, -.01, 1.13 + k * .045)), 'paint_robot', 'spine1')
    add(place(ch(.50, .32, .30, .04), (0, 0, 1.36)), 'paint_robot', blend=joint_blend('spine1', 'spine2', (0, 0, 1.25), (0, 0, 1), .03))
    add(place(ch(.30, .04, .14, .01), (0, .16, 1.34)), 'dark_metal', 'spine2')
    for k in range(3):
        add(place(ch(.22, .01, .012, .002), (0, .182, 1.30 + k * .03)), 'light_red' if k == 1 else 'rubber', 'spine2')
    add(place(ch(.34, .16, .34, .03), (0, -.22, 1.32)), 'dark_metal', 'spine2')
    for s in (1, -1):
        add(bm_tube((s * .1, -.31, 1.18), (s * .1, -.31, 1.46), .035, .035, seg=10), 'paint_robot', 'spine2')
    add(bm_tube((0, 0, 1.46), (0, 0, 1.58), .045, .045, seg=10), 'dark_metal', blend=joint_blend('spine2', 'neck', (0, 0, 1.50), (0, 0, 1), .03))
    for s, side in ((1, 'R'), (-1, 'L')):
        ua, fa, hd = f'upperarm_{side}', f'forearm_{side}', f'hand_{side}'
        add(place(ch(.18, .21, .16, .03), (s * .28, 0, 1.42), (0, s * 10, 0)), 'paint_robot', ua)
        add(bm_tube((s * .22, 0, 1.38), (s * .25, 0, 1.13), .045, .04, seg=12), 'dark_metal', ua)
        add(place(bm_ell(.055, .055, .055, 14, 8), (s * .25, 0, 1.11)), 'dark_metal', blend=joint_blend(ua, fa, (s * .25, 0, 1.11), (0, 0, -1), .03))
        add(place(ch(.11, .12, .21), (s * .262, .012, .98)), 'paint_robot', fa)
        add(place(ch(.09, .10, .11, .015), (s * .277, .03, .79)), 'dark_metal', hd)
    add(place(ch(.20, .23, .17, .03), (0, .01, 1.655)), 'paint_robot', 'head')
    add(place(ch(.175, .05, .045, .01), (0, .125, 1.67)), 'light_red', 'head')
    add(place(ch(.21, .05, .03, .01), (0, .115, 1.62)), 'dark_metal', 'head')
    add(bm_tube((.07, -.05, 1.74), (.07, -.05, 1.92), .006, .004, seg=6, round_ends=0), 'dark_metal', 'head')
    return P


# ------------------------------------------------------------------ constraints
pb = rig.pose.bones
for side in 'RL':
    c = pb[f'forearm_{side}'].constraints.new('IK')
    c.name = 'armIK'; c.target = rig; c.subtarget = f'ik_hand_{side}'; c.chain_count = 2
    c.pole_target = rig; c.pole_subtarget = f'pole_{side}'; c.pole_angle = D(-90)
    c2 = pb[f'hand_{side}'].constraints.new('COPY_ROTATION')
    c2.name = 'armIKrot'; c2.target = rig; c2.subtarget = f'ik_hand_{side}'
    c3 = pb[f'shin_{side}'].constraints.new('IK')
    c3.name = 'legIK'; c3.target = rig; c3.subtarget = f'ik_foot_{side}'; c3.chain_count = 2
    c3.pole_target = rig; c3.pole_subtarget = f'pole_knee_{side}'; c3.pole_angle = D(-90)
    c4 = pb[f'foot_{side}'].constraints.new('COPY_ROTATION')
    c4.name = 'footRot'; c4.target = rig; c4.subtarget = f'ik_foot_{side}'
for p in pb:
    p.rotation_mode = 'QUATERNION'


def set_ik(arm=1.0, leg=0.0):
    for side in 'RL':
        pb[f'forearm_{side}'].constraints['armIK'].influence = arm
        pb[f'hand_{side}'].constraints['armIKrot'].influence = arm
        pb[f'shin_{side}'].constraints['legIK'].influence = leg
        pb[f'foot_{side}'].constraints['footRot'].influence = leg


# ------------------------------------------------------------------ animation authoring
def rest_q(name):
    return rig.data.bones[name].matrix_local.to_quaternion()


def pose_bone(name, r=(0, 0, 0), t=(0, 0, 0), s=1.0):
    """Rotation r (deg, XYZ about armature axes through the bone's head) and translation t (armature axes)."""
    R = rest_q(name)
    qa = Euler([D(v) for v in r], 'XYZ').to_quaternion()
    p = pb[name]
    p.rotation_quaternion = R.inverted() @ qa @ R
    p.location = R.inverted() @ Vector(t)
    p.scale = (s, s, s)


def set_world(name, loc, r=(0, 0, 0)):
    """Place a bone at an armature-space location/orientation (orientation relative to its rest)."""
    bpy.context.view_layer.update()
    rest = rig.data.bones[name].matrix_local.to_3x3()
    rot = Euler([D(v) for v in r], 'XYZ').to_matrix() @ rest
    m = rot.to_4x4()
    m.translation = Vector(loc)
    pb[name].matrix = m
    bpy.context.view_layer.update()


def key_all(frame):
    for p in pb:
        p.keyframe_insert('rotation_quaternion', frame=frame)
        p.keyframe_insert('location', frame=frame)
        p.keyframe_insert('scale', frame=frame)


def clear_pose():
    for p in pb:
        p.rotation_quaternion = (1, 0, 0, 0); p.location = (0, 0, 0); p.scale = (1, 1, 1)


ACTIONS = {}  # name -> (frames, arm_ik, leg_ik)


def new_action(name, frames, arm=1.0, leg=0.0):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    ACTIONS[name] = (frames, arm, leg)
    return act


# Aim stance: shoulders bladed, weapon level and forward, head turned to the sights.
AIM_W = (.105, .05, 1.31)
FOOT = {'R': (.15, -.07, .11), 'L': (-.14, .09, .11)}


def upper_aim(breath=0.0, low=0.0, sway=0.0):
    pose_bone('spine1', (2 + breath * 1.2 + low * 10, 0, -10 + sway))
    pose_bone('spine2', (3 + breath * 1.5 + low * 12, 0, -15))
    pose_bone('neck', (-2 - low * 8, 0, 10))
    pose_bone('head', (-3 - low * 10, 0, 13 - sway))
    pose_bone('clavicle_R', (0, 0, 0), (0, 0, -.01 + breath * .004))
    pose_bone('clavicle_L', (0, 0, 0), (0, 0, breath * .004))
    for side in 'RL':
        pose_bone(f'ik_hand_{side}')
        pose_bone(f'pole_{side}')
    pose_bone('mag')
    set_world('weapon', (AIM_W[0] + low * .02, AIM_W[1] - low * .05, AIM_W[2] - breath * .006 - low * .12),
              (-2 - low * 28 - breath * .6, low * 8, sway * .3))


def lower_stance(crouch=0.0, breath=0.0):
    pose_bone('root')
    pose_bone('pelvis', (0, 0, 8 - crouch * 4), (0, -crouch * .06, -crouch * .40 - breath * .006))
    for side in 'RL':
        fx, fy, fz = FOOT[side]
        if crouch and side == 'L':
            fy += .12
        pose_bone(f'ik_foot_{side}', (0, 0, 14 if side == 'R' else -6), (fx - (.12 if side == 'R' else -.12), fy + .01, 0))
        pose_bone(f'pole_knee_{side}')
        for b in ('thigh', 'shin', 'foot'):
            pose_bone(f'{b}_{side}')
    if crouch:  # rear knee goes down towards the deck
        pose_bone('ik_foot_R', (40, 0, 14), (.03, -.14, .05))


def run_legs(p, kind='F'):
    """Hand-keyed run cycle sampled at contact/down/passing/up poses. p in [0,1)."""
    # (thigh, shin, foot) pitch keyposes for the leg that is in contact at p=0
    keys = [(0, (32, -14, 2)), (.125, (18, -38, 2)), (.25, (-6, -22, -8)), (.375, (-28, -36, -28)),
            (.5, (-22, -70, -18)), (.625, (2, -98, -8)), (.75, (30, -86, 0)), (.875, (40, -46, 6)), (1, (32, -14, 2))]
    def at(q):
        q %= 1
        for (a, va), (b, vb) in zip(keys, keys[1:]):
            if a <= q <= b:
                t = (q - a) / (b - a); t = t * t * (3 - 2 * t)
                return [x + (y - x) * t for x, y in zip(va, vb)]
    bob = -.035 * math.cos(p * 4 * math.pi) - .01
    lean = {'F': 10, 'B': -6, 'L': 2, 'R': 2}[kind]
    twist = 7 * math.sin(p * math.tau)
    pose_bone('root')
    if kind in 'FB':
        pose_bone('pelvis', (lean, 3 * math.sin(p * math.tau), twist), (0, 0, bob))
        for side, ph in (('R', 0), ('L', .5)):
            th, sh, ft = at(p + ph)
            pose_bone(f'thigh_{side}', (th, 0, 0)); pose_bone(f'shin_{side}', (sh, 0, 0)); pose_bone(f'foot_{side}', (ft, 0, 0))
    else:  # side shuffle: legs swing about the forward axis, knees lift on the passing pose
        sgn = 1 if kind == 'R' else -1
        pose_bone('pelvis', (lean, -sgn * 5 * math.sin(p * math.tau), sgn * -8), (0, 0, bob))
        for side, ph in (('R', 0), ('L', .5)):
            th, sh, ft = at(p + ph)
            pose_bone(f'thigh_{side}', (th * .35 + 8, sgn * th * .55, 0)); pose_bone(f'shin_{side}', (sh * .8, 0, 0)); pose_bone(f'foot_{side}', (ft * .5, sgn * th * -.3, 0))
    for side in 'RL':
        pose_bone(f'ik_foot_{side}'); pose_bone(f'pole_knee_{side}')


def author():
    # ---- upper body
    new_action('U_Aim', 60)
    for f in range(0, 61, 6):
        clear_pose(); lower_stance(); upper_aim(breath=math.sin(f / 60 * math.tau), sway=math.sin(f / 60 * math.tau * 2) * .6); key_all(f)
    new_action('U_LowReady', 60)
    for f in range(0, 61, 10):
        clear_pose(); lower_stance(crouch=1); upper_aim(breath=math.sin(f / 60 * math.tau), low=1); key_all(f)
    new_action('U_Reload', 44)
    mag_well = (.235, .37, 1.20)
    for f, (tilt, hand, magpos, mscale) in {
        0: (0, None, None, 1), 5: (.6, 'well', None, 1), 9: (1, 'well', None, 1), 15: (1, (-.12, .26, 1.02), (-.12, .26, 1.03), 1),
        19: (1, (-.2, .10, .99), (-.2, .10, 1.0), 0), 22: (1, (-.21, .08, 1.0), (-.21, .08, 1.0), 0), 24: (1, (-.21, .09, 1.0), (-.21, .09, 1.0), 1),
        31: (1, (.0, .30, 1.12), (.0, .30, 1.13), 1), 35: (1, 'well', None, 1), 38: (.6, 'grip', None, 1), 44: (0, None, None, 1)}.items():
        clear_pose(); lower_stance()
        upper_aim()
        bpy.context.view_layer.update()
        wm = pb['weapon'].matrix.copy()
        set_world('weapon', wm.translation + Vector((-.05 * tilt, -.06 * tilt, -.06 * tilt)), (-2 + 22 * tilt, 34 * tilt, 6 * tilt))
        wm = pb['weapon'].matrix.copy()
        well = wm @ Vector((.005, .27, -.085))
        if hand == 'well':
            set_world('ik_hand_L', well, (-20, 0, 0))
        elif hand not in (None, 'grip'):
            set_world('ik_hand_L', hand, (-60, 0, 20))
        if magpos is not None:
            set_world('mag', magpos, (0, 0, 20))
        pb['mag'].scale = (mscale,) * 3
        key_all(f)
    # ---- lower body
    new_action('L_Idle', 60, leg=1.0)
    for f in range(0, 61, 10):
        clear_pose(); lower_stance(breath=math.sin(f / 60 * math.tau)); upper_aim(); key_all(f)
    new_action('L_Crouch_Idle', 60, leg=1.0)
    for f in range(0, 61, 15):
        clear_pose(); lower_stance(crouch=1, breath=math.sin(f / 60 * math.tau)); upper_aim(low=1); key_all(f)
    for kind in 'FBLR':
        name = {'F': 'L_Run_F', 'B': 'L_Run_B', 'L': 'L_Strafe_L', 'R': 'L_Strafe_R'}[kind]
        new_action(name, 20)
        for f in range(0, 21, 2):
            p = f / 20
            clear_pose(); run_legs(1 - p if kind == 'B' else p, kind); upper_aim(); key_all(f)
    new_action('L_Walk_F', 32)
    for f in range(0, 33, 2):
        clear_pose(); run_legs(f / 32, 'F')
        for side in 'RL':  # shorter stride, less knee lift for a patrol walk
            for b, k in (('thigh', .55), ('shin', .5), ('foot', .5)):
                q = pb[f'{b}_{side}'].rotation_quaternion
                pb[f'{b}_{side}'].rotation_quaternion = Quaternion((1, 0, 0, 0)).slerp(q, k)
        pb['pelvis'].location = pb['pelvis'].location * .4
        upper_aim(low=.35); key_all(f)
    new_action('L_Crouch_Walk', 24)
    for f in range(0, 25, 2):
        clear_pose(); run_legs(f / 24, 'F')
        for side in 'RL':
            pose_bone(f'thigh_{side}', (40 + (pb[f'thigh_{side}'].rotation_quaternion.to_euler().x and 0), 0, 0))
        for side, ph in (('R', 0), ('L', .5)):
            s = math.sin((f / 24 + ph) * math.tau)
            pose_bone(f'thigh_{side}', (55 + 28 * s, 0, 0)); pose_bone(f'shin_{side}', (-100 + 22 * max(0, -s) - 20 * max(0, s), 0, 0)); pose_bone(f'foot_{side}', (42 - 25 * s, 0, 0))
        pose_bone('pelvis', (14, 0, 0), (0, -.06, -.36 - .02 * math.cos(f / 24 * 2 * math.tau)))
        upper_aim(low=1); key_all(f)
    # ---- full body
    new_action('F_Roll', 19, leg=lambda f: 1 - smoothstep(1.5, 3, f) + smoothstep(15, 16.5, f))
    # Deliberate trajectory: dip, tuck, pelvis travels a raised arc while the body turns 360 deg, then rises.
    roll = {0: (.98, 0, 0, 0, 0), 2: (.86, -16, 44, -78, 40), 3: (.81, -42, -12, -22, 52), 4: (.74, -70, 70, -95, 70), 6: (.77, -125, 100, -130, 80),
            8: (.78, -180, 108, -138, 88), 10: (.82, -235, 108, -138, 88), 12: (.78, -290, 98, -128, 78), 14: (.74, -335, 88, -118, 55), 15: (.77, -350, 75, -108, 42),
            16: (.80, -360, 52, -92, 25), 19: (.98, -360, 0, 0, 0)}
    for f, (pz, rx, th, sh, sp) in roll.items():
        clear_pose()
        pose_bone('pelvis', (rx, 0, 0), (0, 0, pz - .98))
        pose_bone('spine1', (sp * .5, 0, 0)); pose_bone('spine2', (sp * .5, 0, 0)); pose_bone('neck', (sp * .3, 0, 0)); pose_bone('head', (sp * .2, 0, 0))
        for side in 'RL':
            pose_bone(f'thigh_{side}', (th, 0, 0)); pose_bone(f'shin_{side}', (sh, 0, 0)); pose_bone(f'foot_{side}', (sh * -.3, 0, 0))
        bpy.context.view_layer.update()
        tuck = min(1, sp / 60)
        c = pb['spine2'].matrix
        rest_rel = rig.data.bones['spine2'].matrix_local.inverted() @ rig.data.bones['weapon'].matrix_local
        hug = Matrix.Translation((.16 * tuck, -.06 * tuck, .06 * tuck)) @ Euler((D(-88 * tuck), 0, D(-6 * tuck))).to_matrix().to_4x4()
        aim = Matrix.Translation(Vector(AIM_W)) @ rig.data.bones['weapon'].matrix_local.to_3x3().to_4x4()
        if tuck:
            pb['weapon'].matrix = c @ rest_rel @ hug
        else:
            pb['weapon'].matrix = aim
        key_all(f)
    global AIM_REL
    clear_pose(); lower_stance(); upper_aim(); bpy.context.view_layer.update()
    AIM_REL = pb['spine2'].matrix.inverted() @ pb['weapon'].matrix
    new_action('F_Death', 32)
    death = {0: (0, 0, 0, 0, 0), 5: (-.05, 12, 6, 25, -40), 11: (-.32, 38, 18, 40, -70), 17: (-.62, 70, 20, 30, -40), 21: (-.80, 86, 18, 22, -15),
             25: (-.78, 82, 16, 20, -10), 32: (-.80, 86, 16, 18, -8)}
    for f, (pz, rx, sp, th, sh) in death.items():
        clear_pose()
        pose_bone('pelvis', (rx, 0, rx * .1), (0, -pz * .4, pz))
        pose_bone('spine1', (-sp * .4, 0, 0)); pose_bone('spine2', (-sp * .4, 0, 0)); pose_bone('head', (-sp, 0, sp * .8))
        pose_bone('thigh_R', (th, -8, 0)); pose_bone('thigh_L', (th * .4, 12, 0)); pose_bone('shin_R', (sh, 0, 0)); pose_bone('shin_L', (sh * 1.6, 0, 0))
        clavs = (pose_bone('clavicle_R'), pose_bone('clavicle_L'))
        bpy.context.view_layer.update()
        drop = Euler((D(-30 * min(1, f / 20)), D(25 * min(1, f / 20)), 0)).to_matrix().to_4x4()
        pb['weapon'].matrix = pb['spine2'].matrix @ AIM_REL @ drop
        key_all(f)


# ------------------------------------------------------------------ visual bake
def bake_all():
    baked = []
    for name, (frames, arm, leg) in list(ACTIONS.items()):
        act = bpy.data.actions[name]
        rig.animation_data.action = act
        samples = []
        for f in range(frames + 1):
            set_ik(arm, leg(f) if callable(leg) else leg)
            scene.frame_set(f)
            bpy.context.view_layer.update()
            samples.append({p.name: rig.convert_space(pose_bone=p, matrix=p.matrix, from_space='POSE', to_space='LOCAL') for p in pb})
        out = bpy.data.actions.new(name + '__baked')
        rig.animation_data.action = out
        set_ik(0, 0)
        for f, smp in enumerate(samples):
            for p in pb:
                p.matrix_basis = smp[p.name]
            key_all(f)
        baked.append((name, out))
    for name, out in baked:
        bpy.data.actions.remove(bpy.data.actions[name])
        out.name = name
        out.use_fake_user = True
    for p in pb:
        for c in list(p.constraints):
            p.constraints.remove(c)


def check_roll(meshes):
    act = bpy.data.actions['F_Roll']
    rig.animation_data.action = act
    worst = 9
    for f in range(0, ACTIONS['F_Roll'][0] + 1):
        scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        mz, who = 9, ''
        for mesh_obj in meshes:
            ev = mesh_obj.evaluated_get(dg)
            me = ev.to_mesh()
            z = min((mesh_obj.matrix_world @ v.co).z for v in me.vertices)
            if z < mz: mz, who = z, mesh_obj.name
            ev.to_mesh_clear()
        me = None
        worst = min(worst, mz)
        print(f'  roll f{f:02d} minZ {mz:.3f} ({who})')
    return worst


def export(path, objs, animations):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=animations,
                              export_animation_mode='ACTIONS', export_force_sampling=True, export_def_bones=True,
                              export_image_format='NONE', export_skins=True, export_yup=True, export_apply=False,
                              export_optimize_animation_size=True, export_leaf_bone=False, export_extras=False)
    print('exported', path, os.path.getsize(path) // 1024, 'KB')


# ------------------------------------------------------------------ run
author()
bake_all()
op_body = build_mesh('Operator', operator_parts())
rifle = build_mesh('Rifle', weapon_parts('rifle'))
shotgun = build_mesh('Shotgun', weapon_parts('shotgun'))
low = check_roll([op_body, rifle, shotgun])
print(f'ROLL_MIN_Z {low:.3f}')
if low < -0.005:
    print('ROLL CLEARANCE FAILED'); sys.exit(2)
rig.animation_data.action = bpy.data.actions['U_Aim']
scene.frame_set(0)
for o in (op_body, rifle, shotgun):
    print(o.name, 'verts', len(o.data.vertices), 'tris', sum(len(p.vertices) - 2 for p in o.data.polygons))
export(os.path.join(OUT, 'operator.glb'), [op_body, rifle, shotgun], True)
for o in (op_body, shotgun):
    bpy.data.objects.remove(o)
robot = build_mesh('Robot', robot_parts())
print('Robot verts', len(robot.data.vertices))
rifle.name = 'RobotRifle'
rig.animation_data.action = None
clear_pose()
export(os.path.join(OUT, 'robot.glb'), [robot, rifle], False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'characters.blend'))
print('DONE')
