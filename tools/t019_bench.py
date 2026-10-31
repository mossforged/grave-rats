#!/usr/bin/env python3
"""T019: what the corridor dressing costs on both decks. Alternating windowed runs with KIT_CORRIDORS off
and on, so drift on a busy Mac lands on both alike. Raw runs: docs/screens/T019/frame_times.json.
usage: python3 tools/t019_bench.py [rounds] [seconds]
"""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = ["scenes/shift/shift_deck.tscn", "scenes/pirates/pirate_deck.tscn"]
rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 3
seconds = sys.argv[2] if len(sys.argv) > 2 else "15"
runs = []
for r in range(rounds):
    for scene in SCENES:
        # Each round swaps which goes first.
        for state in (["off", "on"] if r % 2 == 0 else ["on", "off"]):
            with tempfile.TemporaryDirectory() as out:
                env = dict(os.environ, KIT_CORRIDORS=state, CAPTURE_ONLY="none")
                subprocess.run([str(ROOT / "tools/capture.sh"), scene, out, seconds], env=env, cwd=ROOT, check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                ft = json.loads((Path(out) / "frametime.json").read_text())
            runs.append({"round": r, "scene": Path(scene).stem, "corridors": state, "avg": ft["frame_ms_avg"], "p95": ft["frame_ms_p95"], "resolution": ft["resolution"]})
            print(runs[-1], flush=True)
summary = {}
for scene in SCENES:
    name = Path(scene).stem
    summary[name] = {}
    for state in ["off", "on"]:
        rows = [x for x in runs if x["scene"] == name and x["corridors"] == state]
        summary[name][state] = {"avg": sum(x["avg"] for x in rows) / len(rows), "p95": sum(x["p95"] for x in rows) / len(rows),
                                "avg_min": min(x["avg"] for x in rows), "avg_max": max(x["avg"] for x in rows)}
out = ROOT / "docs/screens/T019/frame_times.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"summary": summary, "runs": runs, "load_end": os.getloadavg()}, indent=1) + "\n")
for name, states in summary.items():
    print(name)
    for state, v in states.items():
        print("  %-3s %.2f / %.2f  (avg %.2f..%.2f)" % (state, v["avg"], v["p95"], v["avg_min"], v["avg_max"]))
