#!/usr/bin/env python3
"""T016: what each anti-aliasing mode costs on each deck. Alternating windowed runs, so drift on a busy
Mac lands on every mode alike; a mean of the rounds per mode. Raw runs: docs/screens/T016/frame_times.json.
usage: python3 tools/t016_aa_bench.py [rounds] [seconds]
"""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = ["scenes/pirates/pirate_deck.tscn", "scenes/enemies/stalker_deck.tscn", "scenes/shift/shift_deck.tscn"]
MODES = [m["id"] for m in json.loads((ROOT / "data/display.json").read_text())["aa_modes"]]
rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 3
seconds = sys.argv[2] if len(sys.argv) > 2 else "15"
runs = []
for r in range(rounds):
    for scene in SCENES:
        # Each round starts one mode later, so no mode always follows the same one.
        for i in range(len(MODES)):
            mode = MODES[(i + r) % len(MODES)]
            with tempfile.TemporaryDirectory() as out:
                env = dict(os.environ, DISPLAY_AA=mode, CAPTURE_ONLY="none")
                subprocess.run([str(ROOT / "tools/capture.sh"), scene, out, seconds], env=env, cwd=ROOT, check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                ft = json.loads((Path(out) / "frametime.json").read_text())
            runs.append({"round": r, "scene": Path(scene).stem, "mode": mode, "avg": ft["frame_ms_avg"], "p95": ft["frame_ms_p95"],
                         "msaa_3d": ft["msaa_3d"], "screen_space_aa": ft["screen_space_aa"], "resolution": ft["resolution"]})
            print(runs[-1], flush=True)
load = os.getloadavg()
summary = {}
for scene in SCENES:
    name = Path(scene).stem
    summary[name] = {}
    for mode in MODES:
        rows = [x for x in runs if x["scene"] == name and x["mode"] == mode]
        summary[name][mode] = {"avg": sum(x["avg"] for x in rows) / len(rows), "p95": sum(x["p95"] for x in rows) / len(rows),
                               "avg_min": min(x["avg"] for x in rows), "avg_max": max(x["avg"] for x in rows)}
(ROOT / "docs/screens/T016/frame_times.json").write_text(json.dumps({"summary": summary, "runs": runs, "load_end": load}, indent=1) + "\n")
for name, modes in summary.items():
    print(name)
    for mode, v in modes.items():
        print("  %-11s %.2f / %.2f  (avg %.2f..%.2f)" % (mode, v["avg"], v["p95"], v["avg_min"], v["avg_max"]))
