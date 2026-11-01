#!/usr/bin/env python3
"""T023: writes data/deck_survey.json, the biological survey vessel, in final world metres.

Geometry comes from assets/source/A014-derelict-2/A014-02.layout.json (read, never written). What the plan
leaves open (which catalogue prop, dressing, signs, patrols) is authored here in world metres and turned into
the fractions the game's readers use, because it's far easier to check against a plan that way.

Scale policy: spaces carry `rect_m`, final world metres. DeckLayout applies no room_scale to them, so the
plan's dimensions are never divided by 0.85 and never scaled twice.

After a hand edit of data/deck_survey.json this tool is out of date: re-run it only from a matching source.
Run: python3 tools/t023_make_deck.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN = json.loads((ROOT / "assets/source/A014-derelict-2/A014-02.layout.json").read_text())
BASE = json.loads((ROOT / "data/deck.json").read_text())

IDS = {"BRIDGE": "bridge", "BIO LAB": "bio_lab", "MESS": "mess", "QUARTERS": "quarters", "WEST SPINE": "west_spine",
       "EAST SPINE": "east_spine", "ENGINEERING": "engineering", "AIRLOCK / HOLD": "airlock"}
KIND = {"WEST SPINE": "corridor", "EAST SPINE": "corridor"}
RECT = {IDS[r["name"]]: (r["x"], r["y"], r["width"], r["depth"]) for r in PLAN["rooms"]}


def fr(space, x, z):
    """World metres as fractions of a space. May fall outside 0-1 (a drone's route leaves its first space)."""
    r = RECT[space]
    return [round((x - r[0]) / r[2], 6), round((z - r[1]) / r[3], 6)]


def along(space, wall, m):
    """Fraction along a wall, from a world x (north, south) or z (east, west)."""
    r = RECT[space]
    return round((m - r[0]) / r[2] if wall in ("north", "south") else (m - r[1]) / r[3], 6)


def spaces():
    return [{"name": IDS[r["name"]], "kind": KIND.get(r["name"], "room"), "rect_m": [r["x"], r["y"], r["width"], r["depth"]]}
            for r in PLAN["rooms"]]


# Each plan door: its corridor-side space and wall; slide direction doesn't matter to the plan.
DOOR_ON = {"D1": ("west_spine", "west"), "D2": ("west_spine", "east"), "D3": ("east_spine", "west"), "D4": ("west_spine", "east"),
           "D5": ("east_spine", "west"), "D6": ("west_spine", "east"), "D7": ("east_spine", "west"), "D8": ("west_spine", "east"),
           "D9": ("east_spine", "west"), "D10": ("east_spine", "east")}


def doors():
    out = []
    for d in PLAN["doors"]:
        space, wall = DOOR_ON[d["id"]]
        cz = d["y"] + d["depth"] / 2
        out.append({"id": d["id"], "space": space, "side": wall, "at": along(space, wall, cz), "state": "closed", "slide": 1})
    return out


# The plan's cover, in plan order: [(type, x, z, size x, y, z)] per entry. Centres are the plan rect's centre,
# except where a group shares a rect or a prop is drawn in toward its wall (within half a grid cell): a slot
# wider than the player but narrower than a stalker's path traps bots and shelters players. T023 bots got wedged.
GLOW = {"emit_blue": "emit_cyan", "glass": "tank_glow"}
# A big lit surface at the kit's full energy blooms through the sight mask and gives a dark room away.
DIM = {"emit_blue": "emit_blue_dim", "emit_cool": "emit_cool_dim"}
DIM_PROPS = {"reactor_core", "nav_table", "helm_console", "comms_rack", "transformer", "power_cell_rack", "sample_freezer", "control_desk"}
COVER = [
    [("helm_console", 13.0, 1.5, 2.38, 1.04, 0.72)],
    [("nav_table", 18.0, 1.5, 1.6, 0.93, 1.0)],
    [("comms_rack", 21.1, 0.9, 0.86, 2.0, 0.8), ("comms_rack", 21.1, 1.9, 0.86, 2.0, 0.8)],
    [("specimen_tank", 11.75, 7.75, 0.9, 2.15, 0.9)],
    [("specimen_tank", 14.75, 7.75, 0.9, 2.15, 0.9)],
    [("specimen_tank", 17.75, 7.75, 0.9, 2.15, 0.9)],
    [("sample_freezer", 21.24, 13.55, 0.75, 1.95, 0.8), ("sample_freezer", 21.24, 14.45, 0.75, 1.95, 0.8)],
    [("autopsy_table", 14.5, 14.5, 2.01, 0.98, 1.18)],
    [("mess_table", 13.5, 17.5, 2.0, 0.8, 1.6)],
    [("mess_table", 18.5, 20.5, 2.0, 0.8, 1.6)],
    [("food_dispenser", 21.17, 20.92, 0.58, 2.0, 1.0)],
    [("bunk_bed", 11.55, 26.75, 1.02, 1.9, 1.99), ("bunk_bed", 13.05, 26.75, 1.02, 1.9, 1.99)],
    [("bunk_bed", 16.75, 26.75, 1.02, 1.9, 1.99), ("bunk_bed", 17.8, 26.75, 1.02, 1.9, 1.99)],
    [("tarp_pile", 20.75, 23.5, 1.54, 1.01, 1.06)],
    [("transformer", 30.44, 10.82, 1.12, 2.0, 0.64), ("reactor_core", 32.0, 11.5, 2.0, 2.4, 2.0), ("transformer", 33.56, 10.82, 1.12, 2.0, 0.64)],
    [("control_desk", 30.5, 18.5, 1.8, 1.09, 0.7)],
    [("power_cell_rack", 35.25, 16.9, 0.5, 1.8, 1.2), ("power_cell_rack", 35.25, 18.1, 0.5, 1.8, 1.2)],
    [("crate_pile_tipped", 1.3, 23.0, 1.61, 0.75, 1.19)],
    [("container_section", 1.5, 26.75, 2.53, 2.4, 1.27)],
]


TROLLEY = (22.87, 8.0)


def space_of(x, z):
    for name, (rx, rz, w, d) in RECT.items():
        if rx <= x <= rx + w and rz <= z <= rz + d:
            return name
    raise ValueError((x, z))


def props():
    out = []
    assert len(COVER) == len(PLAN["cover"])
    for i, (group, plan) in enumerate(zip(COVER, PLAN["cover"])):
        for t, x, z, sx, sy, sz in group:
            s = space_of(x, z)
            p = {"type": t, "space": s, "at": fr(s, x, z), "size_m": [sx, sy, sz],
                 "cover": "low" if plan["kind"] == "L" else "tall", "plan_cover": i}
            if t == "specimen_tank":
                p["wear"] = GLOW
            elif t in DIM_PROPS:
                p["wear"] = DIM
            out.append(p)
    # The story beat: a meal trolley stopped at the bio lab's seal (door D5), on the spine side. It's a solid
    # prop with no cover class, not dressing: the walking lane hugs this wall, so you step round it.
    s = space_of(*TROLLEY)
    out.append({"type": "tray_trolley", "space": s, "at": fr(s, *TROLLEY), "size_m": [0.7, 1.25, 1.37], "cover": "none"})
    return out


def clutter(t, x, z, turn=0.0):
    s = space_of(x, z)
    e = {"type": t, "space": s, "at": fr(s, x, z)}
    if t in ("holo_projector", "captain_chair", "centrifuge"):
        e["wear"] = DIM
    if turn:
        e["turn_deg"] = turn
    return e


def on_wall(t, space, wall, m):
    e = {"type": t, "space": space, "wall": wall, "at": along(space, wall, m)}
    if t in ("wall_screen_bank", "viewport_frame", "wall_terminal"):
        e["wear"] = DIM
    return e


DRESSING = [
    # Bridge: the chair faces the plot. Screens and the viewport on the wall you see.
    clutter("captain_chair", 15.5, 5.1, 180.0),
    clutter("holo_projector", 18.5, 5.2),
    on_wall("wall_screen_bank", "bridge", "north", 13.0),
    on_wall("viewport_frame", "bridge", "north", 15.7),
    on_wall("wall_terminal", "bridge", "west", 1.4),
    # Bio lab: the sealed end. The trolley is outside, at the seal.
    clutter("centrifuge", 16.6, 14.5),
    clutter("biohazard_bin", 12.2, 15.3),
    clutter("body_bag", 18.0, 15.6, 90.0),
    on_wall("scrub_sink", "bio_lab", "west", 8.0),
    # Mess.
    clutter("waste_bin", 11.2, 21.4),
    # Quarters.
    clutter("footlocker", 15.0, 27.5),
    clutter("desk_chair", 17.2, 23.15),
    on_wall("personal_shelf", "quarters", "north", 18.2),
    # Engineering.
    clutter("toolbox_cart", 27.2, 18.8),
    clutter("catwalk_section", 28.0, 12.0),
    on_wall("fuse_panel", "engineering", "east", 15.0),
    on_wall("junction_box", "engineering", "east", 12.4),
    on_wall("pipe_valve", "engineering", "south", 33.0),
    # Hold.
    clutter("pallet", 4.4, 22.6),
    on_wall("emergency_locker", "airlock", "north", 3.6),
]


def corridor(walls, grim_wall, grim_z, floor, high_on_near=False):
    near, far = walls  # near has the doors
    space = "west_spine" if near == "east" else "east_spine"
    return {
        "pillars": ["nw", "ne", "sw", "se"],
        "ribs": {"type": "wall_rib", "every_m": 2.7, "start_m": {far: 1.2, near: 2.55}},
        "landmarks": [
            {"type": "wall_panel_breached", "wall": grim_wall, "at": along(space, grim_wall, grim_z)},
            {"type": "hanging_cables", "wall": grim_wall, "at": along(space, grim_wall, grim_z + 0.75), "over": True},
        ],
        "runs": [{"type": "pipe_run_high", "wall": near if high_on_near else far}, {"type": "pipe_run_low", "wall": far if high_on_near else near}],
        "singles": [
            {"type": "fire_hose_reel", "wall": far, "at": 0.44},
            {"type": "handrail", "wall": far, "at": 0.8},
            {"type": "maintenance_hatch", "wall": far, "at": 0.12},
            {"type": "wall_sign_arrow", "wall": near, "at": 0.28},
        ],
        "floor": floor,
    }


def corridor_dressing():
    c = {k: BASE["corridor_dressing"][k] for k in BASE["corridor_dressing"] if k != "corridors"}
    c["corridors"] = {
        "west_spine": corridor(("east", "west"), "west", 6.9,
                               [{"type": "debris_pile", "at": fr("west_spine", 7.0, 7.3), "scale_x": 0.9, "turn_deg": 90.0},
                                {"type": "floor_grate", "at": fr("west_spine", 7.5, 27.2)}]),
        "east_spine": corridor(("west", "east"), "east", 2.0,
                               [{"type": "debris_pile", "at": fr("east_spine", 25.5, 2.4), "scale_x": 0.9, "turn_deg": 90.0},
                                {"type": "floor_grate", "at": fr("east_spine", 25.0, 27.2)}], True),
    }
    return c


def motes(space):
    r = RECT[space]
    return {"recipe": "dust_motes", "space": space, "at": [0.5, 0.5], "box_m": [max(r[2] - 1.0, 1.0), 1.2, max(r[3] - 1.0, 1.0)]}


def effect(recipe, x, z, y=0.0, facing=None):
    s = space_of(x, z)
    e = {"recipe": recipe, "space": s, "at": fr(s, x, z), "y_m": y}
    if facing:
        e["facing"] = facing
    return e


def effects():
    out = [
        effect("sparking_console", 12.4, 1.55, 1.08),
        effect("steam_jet", 28.2, 19.9, 1.7, [0.0, -0.1, -1.0]),
        effect("steam_jet", 36.4, 14.1, 1.5, [-1.0, -0.1, 0.0]),
        effect("acid_pool", 19.5, 9.8, 0.02),
    ]
    return out + [motes(s) for s in RECT]


COLOR_LOOK = {"red": "red", "cyan": "cyan", "orange": "amber", "white": "cool"}
ROOM_CORRIDOR = {"west_spine": ("cool_low", "wall_light_strip"), "east_spine": ("amber_low", "emergency_lamp")}


def fixtures():
    """Each plan light at its plan position. The strip goes on the nearest wall; the lab's stand over the tanks."""
    out = {}
    for l in PLAN["lights"]:
        x, z = l["x"], l["y"]
        s = space_of(x, z)
        r = RECT[s]
        d = {"west": x - r[0], "east": r[0] + r[2] - x, "north": z - r[1], "south": r[1] + r[3] - z}
        wall = min(d, key=d.get)
        e = {"look": COLOR_LOOK[l["color"]], "wall": wall, "at": along(s, wall, x if wall in ("north", "south") else z), "light_xz": [x, z]}
        if s == "bio_lab":
            e["bare"] = True
        if s in ROOM_CORRIDOR:
            e["look"], e["prop"] = ROOM_CORRIDOR[s]
        out.setdefault(s, []).append(e)
    return out


def sign(image, space, wall, m, y, w, layer=0, tilt=0.0):
    e = {"image": image, "space": space, "wall": wall, "at": along(space, wall, m), "y_m": y, "width_m": w}
    if layer:
        e["layer"] = layer
    if tilt:
        e["tilt_deg"] = tilt
    return e


SIGNS_WALLS = [
    # Bridge, north wall west to east.
    sign("plate_bridge", "bridge", "north", 11.3, 2.1, 1.25),
    sign("bridge_commendation", "bridge", "north", 18.6, 1.4, 0.9),
    sign("bridge_captain_chair", "bridge", "north", 19.75, 1.4, 1.2),
    # Bio lab.
    sign("plate_bio_lab", "bio_lab", "north", 20.2, 2.25, 2.2),
    sign("lab_biohazard", "bio_lab", "north", 20.2, 1.55, 2.7),
    sign("lab_ethics", "bio_lab", "north", 16.25, 1.4, 1.0),
    sign("rem_bio_tape", "bio_lab", "north", 16.25, 1.3, 1.5, 1, -6.0),
    sign("lab_fume_hood", "bio_lab", "west", 14.0, 1.5, 1.1),
    # Mess.
    sign("plate_mess", "mess", "north", 20.9, 2.0, 1.2),
    sign("mess_birthday", "mess", "north", 15.9, 2.0, 3.2, 0, -1.5),
    sign("mess_menu", "mess", "north", 11.4, 1.5, 0.95),
    sign("mess_nutrition", "mess", "north", 18.8, 1.45, 0.95),
    sign("mess_fridge", "mess", "north", 15.9, 1.1, 0.8),
    # Quarters.
    sign("plate_crew_quarters", "quarters", "north", 11.4, 1.75, 1.0),
    sign("qtr_quiet_hours", "quarters", "north", 13.0, 1.45, 1.25),
    sign("qtr_bunk_rental", "quarters", "north", 14.75, 1.45, 1.35),
    sign("qtr_drawing", "quarters", "north", 16.4, 1.45, 1.0),
    sign("qtr_mug", "quarters", "north", 18.2, 1.75, 0.55),
    # Engineering.
    sign("plate_engineering_03", "engineering", "north", 35.75, 2.0, 1.1),
    sign("eng_event_board", "engineering", "north", 27.75, 1.3, 1.45),
    sign("eng_radiation", "engineering", "east", 18.0, 1.35, 1.0),
    sign("eng_lockout", "engineering", "west", 11.8, 1.35, 0.95),
    # Spines: section plates, a company notice, the way to the lab.
    sign("plate_section_a", "west_spine", "north", 8.25, 1.4, 0.85),
    sign("plate_section_b", "east_spine", "north", 24.25, 1.4, 0.85),
    sign("rem_notice", "west_spine", "north", 9.25, 1.3, 0.8),
    sign("rem_bio_tape", "east_spine", "west", 8.5, 1.45, 1.5, 0, 4.0),
    sign("owner_safety", "east_spine", "north", 25.3, 1.3, 0.9),
    # Hold: the fee is the same on every ship.
    sign("airlock_fee", "airlock", "north", 1.45, 1.7, 1.9),
    sign("rem_terms", "airlock", "north", 5.0, 1.3, 0.72),
    sign("owner_crew", "airlock", "east", 23.2, 1.35, 1.0),
]


def stuck(image, x, z, y, w, facing="south", tilt=0.0):
    s = space_of(x, z)
    e = {"image": image, "space": s, "at": fr(s, x, z), "y_m": y, "width_m": w, "facing": facing}
    if tilt:
        e["tilt_deg"] = tilt
    return e


SIGNS_STUCK = [
    # Top-facing reads best from the steep camera, south faces next.
    stuck("bridge_nav", 18.0, 1.5, 0.945, 1.45, "top"),
    stuck("rem_stamp_assessed", 13.7, 1.5, 1.055, 0.5, "top", 8.0),
    stuck("rem_tag_chair", 15.5, 5.515, 0.95, 0.42),
    stuck("lab_specimen_01", 11.75, 8.215, 1.25, 0.6),
    stuck("lab_specimen_02", 14.75, 8.215, 1.25, 0.6),
    stuck("lab_specimen_03", 17.75, 8.215, 1.25, 0.6),
    stuck("rem_priority_high", 14.5, 14.5, 0.995, 0.75, "top", 0.0),
    stuck("rem_priority_low", 18.5, 20.5, 0.815, 0.7, "top", -6.0),
    stuck("qtr_bunk_tag", 13.05, 26.0, 1.915, 0.5, "top"),
    stuck("rem_stamp_assessed", 16.6, 26.5, 1.915, 0.5, "top", -10.0),
    stuck("rem_tag_reactor", 32.0, 12.515, 0.7, 0.9),
    stuck("eng_reactor_cage", 32.0, 12.515, 1.55, 1.1),
    stuck("eng_power_cells", 30.44, 11.155, 1.2, 0.85),
    stuck("rem_priority_medium", 30.5, 18.5, 1.105, 0.7, "top", 5.0),
]

SIGNS_FLOORS = [
    {"image": "floor_keep_clear", "space": "airlock", "at": fr("airlock", 5.0, 25.0), "width_m": 1.4, "turn_deg": 90.0},
    {"image": "floor_hazard", "space": "west_spine", "at": fr("west_spine", 8.25, 27.2), "width_m": 3.0, "turn_deg": 0.0},
    {"image": "floor_drain", "space": "mess", "at": fr("mess", 16.0, 18.4), "width_m": 0.8, "turn_deg": 0.0},
    {"image": "floor_drain", "space": "bio_lab", "at": fr("bio_lab", 19.5, 11.8), "width_m": 0.85, "turn_deg": 0.0},
    {"image": "floor_keep_clear", "space": "east_spine", "at": fr("east_spine", 24.25, 15.0), "width_m": 1.5, "turn_deg": 90.0},
    {"image": "floor_keep_clear", "space": "engineering", "at": fr("engineering", 28.0, 15.0), "width_m": 1.4, "turn_deg": 90.0},
    {"image": "floor_staging", "space": "airlock", "at": fr("airlock", 3.6, 26.4), "width_m": 1.8, "turn_deg": 0.0},
]

KIND_BY_POS = {(13, 2.5): "data_chips", (17, 2.5): "black_box", (19, 14.5): "fuse", (13, 13): "canister", (16, 20.5): "data_chips",
               (19, 17.5): "relay", (14, 23.5): "fuse", (19, 27): "busbar", (33, 17): "engine_part", (33, 13.5): "relay"}


def salvage():
    out = []
    for s in PLAN["salvage"]:
        sp = space_of(s["x"], s["y"])
        out.append({"kind": KIND_BY_POS[(s["x"], s["y"])], "space": sp, "at": fr(sp, s["x"], s["y"])})
    return out


# Patrols by candidate, in the plan's order. Each stays in the candidate's space.
SPAWN_PATROLS = [
    ("west vent", "west_spine", [(8.25, 14.0), (8.0, 3.0), (8.25, 22.0)]),
    ("west closet", "west_spine", [(8.25, 15.0), (8.0, 25.0), (8.25, 7.0)]),
    ("east vent", "east_spine", [(24.25, 3.0), (24.25, 15.0), (24.0, 26.0)]),
    ("east closet", "east_spine", [(24.25, 16.0), (24.0, 26.5), (24.25, 6.0)]),
    ("engineering vent", "engineering", [(33.0, 14.5), (28.0, 16.5), (33.5, 19.0)]),
    ("lab vent", "bio_lab", [(19.5, 12.0), (12.0, 11.5), (19.0, 13.5)]),
]


def spawn_points():
    out = []
    for c, (name, space, patrol) in zip(PLAN["spawn_candidates"], SPAWN_PATROLS):
        at = fr(space, c["x"], c["y"])
        out.append({"name": name, "kind": "vent" if c["kind"] == "V" else "closet", "space": space, "at": at,
                    "patrol": [at] + [fr(space, x, z) for x, z in patrol]})
    return out


def pack():
    """No closet on this ship, so no bulkhead stalker. Containment first: one in the lab, one with the reward."""
    def stalker(name, space, x, z, yaw, patrol):
        return {"name": name, "space": space, "at": fr(space, x, z), "yaw_deg": yaw, "patrol": [fr(space, *p) for p in [(x, z)] + patrol]}
    return [
        stalker("lab stalker", "bio_lab", 19.5, 12.0, -90.0, [(12.0, 11.0), (18.5, 13.5), (12.0, 13.0)]),
        stalker("engineering stalker", "engineering", 33.5, 15.5, 90.0, [(28.0, 13.0), (28.0, 16.5), (33.5, 19.0)]),
    ]


def custodian():
    (cx, cz) = PLAN["custodian"]["cutter"]
    route = PLAN["custodian"]["drone_patrol"]
    return {
        "terminals": {"at": [
            {"space": "bridge", "at": fr("bridge", 17.7, 0.18)},
            {"space": "bio_lab", "at": fr("bio_lab", 13.25, 6.68)},
            {"space": "engineering", "at": fr("engineering", 35.1, 10.18)},
        ]},
        "cutters": [{"name": "east spine", "space": "east_spine", "at": fr("east_spine", cx, cz), "home_yaw_deg": 180.0, "arc_half_deg": 75.0, "on_wake": True}],
        "drones": [{"name": "patrol", "space": "east_spine", "at": fr("east_spine", *route[0]), "route": [fr("east_spine", *p) for p in route]}],
    }


FLOOR_ROOMS = {
    "bridge": {"grates": [{"at": [0.5, 0.74], "size_m": [4.0, 0.9]}], "drains": []},
    "bio_lab": {"grates": [{"at": [0.72, 0.52], "size_m": [2.6, 0.9]}], "drains": [[0.78, 0.56]]},
    "mess": {"grates": [], "drains": [[0.48, 0.36]]},
    "quarters": {"grates": [{"at": [0.5, 0.3], "size_m": [5.0, 0.7]}], "drains": []},
    "engineering": {"grates": [{"at": [0.55, 0.45], "size_m": [5.0, 1.2]}, {"at": [0.14, 0.5], "size_m": [1.0, 3.0]}], "drains": [[0.7, 0.9]]},
    "west_spine": {"grates": [{"at": [0.5, 0.3], "size_m": [1.2, 5.5]}, {"at": [0.5, 0.72], "size_m": [1.2, 5.5]}], "drains": []},
    "east_spine": {"grates": [{"at": [0.5, 0.25], "size_m": [1.2, 5.5]}, {"at": [0.5, 0.68], "size_m": [1.2, 5.5]}], "drains": [[0.2, 0.9]]},
    "airlock": {"grates": [{"at": [0.72, 0.5], "size_m": [1.2, 3.5]}], "drains": []},
}

WEAR_ROOMS = {
    "bridge": {"hub": [0.5, 0.55], "routes": [[[0.0, 0.67], [0.57, 0.5], [1.0, 0.67]]], "damp": [[0.8, 0.7, 1.4]]},
    "bio_lab": {"hub": [0.5, 0.5], "routes": [[[0.0, 0.47], [1.0, 0.47]]], "damp": [[0.78, 0.35, 2.0], [0.2, 0.9, 1.5]]},
    "mess": {"hub": [0.5, 0.45], "routes": [[[0.0, 0.5], [1.0, 0.5]]], "damp": [[0.6, 0.3, 1.4]]},
    "quarters": {"hub": [0.5, 0.4], "routes": [[[0.0, 0.5], [1.0, 0.5]]], "damp": [[0.3, 0.2, 1.3]]},
    "engineering": {"hub": [0.2, 0.5], "routes": [[[0.0, 0.5], [0.65, 0.6], [0.65, 0.4]]], "damp": [[0.2, 0.9, 1.8], [0.9, 0.4, 1.5]]},
    "west_spine": {"hub": [0.5, 0.5], "routes": [[[0.5, 0.02], [0.5, 0.98]]], "damp": [[0.3, 0.68, 1.4]]},
    "east_spine": {"hub": [0.5, 0.5], "routes": [[[0.5, 0.02], [0.5, 0.98]]], "damp": [[0.7, 0.24, 1.5]]},
    "airlock": {"hub": [0.6, 0.5], "routes": [[[1.0, 0.5], [0.5, 0.5]]], "damp": []},
}

SLOT_TYPES = sorted({row[0] for group in COVER for row in group}
                    | {d["type"] for d in DRESSING} | {"tray_trolley"})


def overrides():
    return {
        "kit": {
            "slots": {t: f"res://assets/game/props/{t}.glb" for t in SLOT_TYPES},
            "wall_mounts": {
                "wall_screen_bank": {"mount_y_m": 1.25},
                "viewport_frame": {"mount_y_m": 0.0},
                "wall_terminal": {"mount_y_m": 1.1},
                "scrub_sink": {"mount_y_m": 0.0},
                "personal_shelf": {"mount_y_m": 1.25},
                "fuse_panel": {"mount_y_m": 1.05},
                "junction_box": {"mount_y_m": 1.1},
                "pipe_valve": {"mount_y_m": 0.95},
                "emergency_locker": {"mount_y_m": 0.55},
            },
            "materials": {
                "emit_cyan": {"color": "000000", "roughness": 0.5, "metallic": 0.0, "uv_m": 1.0, "emission": "3affd2", "energy": 1.8},
                "emit_blue_dim": {"color": "000000", "roughness": 0.5, "metallic": 0.0, "uv_m": 1.0, "emission": "38b8ff", "energy": 1.2},
                "emit_cool_dim": {"color": "000000", "roughness": 0.5, "metallic": 0.0, "uv_m": 1.0, "emission": "cfe4ff", "energy": 1.2},
                "tank_glow": {"color": "0a2a24", "roughness": 0.15, "metallic": 0.0, "specular": 0.7, "uv_m": 1.0, "emission": "2fe6b8", "energy": 0.7},
            },
            "wall_families": {"by_space": {
                "bridge": "reinforced", "bio_lab": "clinical", "mess": "plain", "quarters": "plain", "engineering": "pipe",
                "west_spine": "corridor", "east_spine": "corridor", "airlock": "reinforced",
            }},
            "floors": {"spaces": FLOOR_ROOMS},
            "floor_wear": {"spaces": WEAR_ROOMS},
            "signage": {"walls": SIGNS_WALLS, "floors": SIGNS_FLOORS, "stuck": SIGNS_STUCK},
            "lighting": {"fixtures": {
                "looks": {
                    "red": {"mat": "emit_red", "color": "ff3626", "energy": 4.2, "range_m": 7.0, "attenuation": 1.8, "specular": 0.9},
                    "cyan": {"mat": "emit_cyan", "color": "4cffd6", "energy": 3.2, "range_m": 5.5, "attenuation": 1.8, "specular": 0.9},
                },
                "spaces": fixtures(),
            }},
        },
        "enemies": {
            "ambush": {"none": True},
            "pack": pack(),
            "spawn_points": spawn_points(),
        },
        "custodian": custodian(),
        "salvage": {"placements": salvage()},
        "shift": {
            "airlock": {"space": "airlock", "from": [0.0, 0.0], "to": [1.0, 1.0]},
            "tiers": [
                {"at_oxygen": 0.6, "stalkers": 1, "announce": "O2 60%. MOVEMENT IN THE VENTS. BILLING CONTINUES."},
                {"at_oxygen": 0.3, "stalkers": 1, "lights": ["bio_lab", "mess"], "wake": ["custodian"],
                 "announce": "O2 30%. POWER LOSS: %s. BILLING CONTINUES."},
            ],
            "section_words": {"bio_lab": "BIO LAB", "mess": "MESS"},
        },
        "audio": {
            "footsteps": {"surfaces": {"bridge": "deck", "bio_lab": "deck", "mess": "deck", "quarters": "deck", "engineering": "grate",
                                       "west_spine": "grate", "east_spine": "wet", "airlock": "deck"}},
            "ambience": {"rooms": {"bridge": "amb_medbay", "bio_lab": "amb_medbay", "mess": "amb_junction", "quarters": "amb_junction",
                                   "engineering": "amb_cargo", "west_spine": "amb_junction", "east_spine": "amb_junction", "airlock": "amb_cargo"}},
            "room_tail": {"bridge": "tail_room", "bio_lab": "tail_room", "mess": "tail_room", "quarters": "tail_room", "engineering": "tail_hold",
                          "west_spine": "tail_slap", "east_spine": "tail_slap", "airlock": "tail_hold"},
        },
        "vfx": {
            "surfaces": {
                "by_material": {"emit_cyan": "glass", "tank_glow": "glass", "emit_blue_dim": "glass", "emit_cool_dim": "glass"},
                "by_prop": {"specimen_tank": "glass", "sample_freezer": "clinical", "helm_console": "housing", "nav_table": "steel", "comms_rack": "steel",
                            "autopsy_table": "steel", "mess_table": "clinical", "food_dispenser": "clinical", "bunk_bed": "clinical", "reactor_core": "steel",
                            "transformer": "steel", "control_desk": "housing", "power_cell_rack": "steel", "container_section": "hull", "tray_trolley": "clinical"},
            },
            "room_draft": {"bridge": [0.1, -0.1], "bio_lab": [-0.08, 0.05], "mess": [0.12, 0.0], "quarters": [0.1, 0.05], "engineering": [0.3, -0.12],
                           "west_spine": [0.0, 0.25], "east_spine": [0.0, -0.3], "airlock": [0.2, 0.0]},
        },
        "paperwork": {"space_words": {"bridge": "bridge", "bio_lab": "bio lab", "mess": "mess", "quarters": "crew quarters",
                                      "engineering": "engineering", "west_spine": "west spine", "east_spine": "east spine", "airlock": "airlock"}},
    }


def main():
    deck = {k: BASE[k] for k in ["grid_m", "floor_tile_m", "wall_height_m", "wall_thickness_m", "wall_segment_m", "door_width_m", "door_frame_m",
                                 "room_scale", "room_scale_options", "character_scale", "character_scale_options"]}
    deck["scale_policy"] = "spaces use rect_m, final world metres from A014-02: no room_scale is applied to them"
    deck["spaces"] = spaces()
    deck["doors"] = doors()
    deck["props"] = props()
    deck["effects"] = effects()
    deck["dressing"] = DRESSING
    deck["dressing_max_intrusion_m"] = BASE["dressing_max_intrusion_m"]
    deck["corridor_dressing"] = corridor_dressing()
    deck["spawn"] = {"space": "airlock", "at": fr("airlock", 3.0, 25.0), "aim_deg": 90.0}
    deck["path_check"] = {"from": "airlock", "to": "bridge", "cell_m": 0.1, "margin_m": 0.05}
    deck["stand_in"] = BASE["stand_in"]
    deck["lighting"] = BASE["lighting"]
    deck["colors"] = BASE["colors"]
    deck["data_overrides"] = overrides()
    (ROOT / "data/deck_survey.json").write_text(json.dumps(deck, indent=1) + "\n")
    print("props", len(deck["props"]), "dressing", len(DRESSING), "signs", len(SIGNS_WALLS) + len(SIGNS_FLOORS) + len(SIGNS_STUCK))


if __name__ == "__main__":
    main()
