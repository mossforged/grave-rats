#!/usr/bin/env python3
"""T022's sheet: docs/screens/T022/sheet.png from the game-camera stills. Run after
tools/capture.sh scenes/dev/t022_stand.tscn docs/screens/T022 2. A crop round the body in each."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path("docs/screens/T022")
AT = json.loads((OUT / "t022_positions.json").read_text())
ROWS = [
    ("Walk: eight directions, aim up the screen", [f"t022_walk_{d}" for d in ("fwd", "fwd_right", "right", "back_right", "back", "back_left", "left", "fwd_left")]),
    ("Run", [f"t022_run_{d}" for d in ("fwd", "fwd_right", "right", "back_right", "back", "back_left", "left", "fwd_left")]),
    ("Sprint, crouch walk", ["t022_sprint_fwd", "t022_sprint_left", "t022_sprint_right", "t022_crouch_idle", "t022_crouch_fwd", "t022_crouch_back", "t022_crouch_left", "t022_crouch_right"]),
    ("Fire stand/walk/crouch, reload stand/walk/crouch, hit", ["t022_fire_stand", "t022_fire_walk", "t022_fire_crouch", "t022_reload_stand", "t022_reload_walk", "t022_reload_crouch", "t022_hit_front", "t022_hit_back"]),
    ("Pick up, press, turn, death falling and down, carrying heavy", ["t022_pick_up", "t022_interact", "t022_turn", "t022_death_falling", "t022_death_down", "t022_carry_idle", "t022_carry_walk"]),
]
CROP = 170
TILE = 220
sheet = Image.new("RGB", (TILE * 8 + 7 * 4, (TILE + 26) * len(ROWS)), "#101214")
d = ImageDraw.Draw(sheet)
for r, (title, names) in enumerate(ROWS):
    y = r * (TILE + 26)
    d.text((6, y + 6), title, fill="#d8e2e6")
    for c, name in enumerate(names):
        x0, y0 = AT[name]
        img = Image.open(OUT / f"{name}.png").convert("RGB").crop((int(x0 - CROP), int(y0 - CROP), int(x0 + CROP), int(y0 + CROP))).resize((TILE, TILE))
        x = c * (TILE + 4)
        sheet.paste(img, (x, y + 26))
        d.text((x + 4, y + 30), name.replace("t022_", ""), fill="#ffe08a")
sheet.save(OUT / "sheet.png")
print("wrote", OUT / "sheet.png")
