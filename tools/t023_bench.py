#!/usr/bin/env python3
"""T023: frame time, survey against the current ship, at the spawn and in each ship's biggest lit room.
Three alternating rounds of 15 s, player still, light on, dummy audio. Writes docs/screens/T023/frame_times.json.
Env GODOT as for tools/capture.sh."""
import json
import os
import subprocess
import tempfile
from pathlib import Path

STANDS = [("spawn", "deck", ""), ("spawn", "deck_survey", ""),
          ("big_room", "deck", "medbay,0.5,0.6"), ("big_room", "deck_survey", "bio_lab,0.5,0.6"),
          ("corridor", "deck", "junction,0.5,0.5"), ("corridor", "deck_survey", "east_spine,0.5,0.5")]
rows = []
for round_no in range(3):
    for stand, ship, at in STANDS:
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, T023_SHIP=ship, T023_AT=at, CAPTURE_ONLY="none")
            subprocess.run(["tools/capture.sh", "scenes/dev/t023_stand.tscn", tmp, "15"], env=env, check=True, capture_output=True)
            ft = json.loads((Path(tmp) / "frametime.json").read_text())
        rows.append({"round": round_no, "stand": stand, "ship": ship, "avg_ms": ft["frame_ms_avg"], "p95_ms": ft["frame_ms_p95"], "p99_ms": ft["frame_ms_p99"],
                     "resolution": ft.get("resolution")})
        print(rows[-1], flush=True)
Path("docs/screens/T023/frame_times.json").write_text(json.dumps(rows, indent=1) + "\n")
for stand in dict.fromkeys(s for s, _, _ in STANDS):
    for ship in ("deck", "deck_survey"):
        r = [x for x in rows if x["stand"] == stand and x["ship"] == ship]
        print(stand, ship, "avg %.2f p95 %.2f" % (sum(x["avg_ms"] for x in r) / len(r), sum(x["p95_ms"] for x in r) / len(r)))
