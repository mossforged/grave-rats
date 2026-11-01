#!/usr/bin/env python3
"""Q003: moves docs/qa/baseline.json to merged main (a4a5f73), number by number with the reason, by hand-checked sets.
Frame numbers come from frame_recheck's clean windows, not from the health check's windows. Everything not named stays.
usage: q003_baseline.py"""
import csv, json, statistics as st
L = "docs/qa/logs-2026-10-31-q003/"
b = json.load(open("docs/qa/baseline.json"))
h = json.load(open("docs/qa/health-2026-10-31-q003.json"))
now = {}
for c_set, rows in h["bots"]["compare"].items():
    now[c_set] = rows
prev_frame = json.loads(json.dumps(b["frame_time"]))
rows = [r for r in csv.reader(open(L + "frame_recheck/windows.tsv"), delimiter="\t") if r[2] == "clean"]
for scene in ("pirate_deck", "stalker_deck", "shift_deck"):
    w = [r for r in rows if r[0] == scene]
    b["frame_time"][scene] = {"avg": round(st.mean(float(r[6]) for r in w), 3), "p95": round(st.mean(float(r[7]) for r in w), 3),
                              "resolution": "1920x1080", "screen_scale": 1.0, "windows": len(w)}
def set_from_report(name):
    for c in now[name]:
        if c.get("now") is None:
            continue
        if c["id"] in b["bots"][name]:
            b["bots"][name][c["id"]] = c["now"]
for name in ("foot_slide", "foot_slide_realtime", "t012", "t015_shift", "t014"):
    set_from_report(name)
for tag, v in h["flicker"]["now"].items():
    b["flicker"][tag] = round(v["twinkle_pct"], 4)
b.setdefault("updates", []).append({
    "date": "2026-10-31", "packet": "Q003", "commit": h["meta"]["commit"],
    "previous_frame_time": prev_frame,
    "notes": {
        "frame_time": "Explained: T020 (effects, and pirates and the player firing through its timeline), measured against T018 in docs/qa/health-2026-10-31-q003.md. Clean windows at load 4 to 5, borderless, scale 1.0, remote desktop host running. pirate_deck now misses T011's target; the lead decides. Replaces the provisional shift_deck number.",
        "foot_slide": "Explained: T022's clips. T021 equals the old table to the digit; T022 equals main. Sprint forward got worse (0.65 to 1.29 m/s); T022 reported that.",
        "foot_slide_realtime": "Explained by T022 by the fixed-step result; the real-time runs weren't repeated on T021. Noisy.",
        "t012, t015_shift, t014": "T023's bot door fix; see the report for what the door-bug rerun showed. Bot change, not a game change.",
        "flicker": "Explained: T020 raised still-camera twinkle from 0.0003% (effects move in frame); T021's wall-top z-fight fix lowered turning and pirate twinkle by about 35%. Checked commit by commit.",
        "t006, t007, t015": "Left alone: no number moved past rounding.",
    }})
json.dump(b, open("docs/qa/baseline.json", "w"), indent=2)
open("docs/qa/baseline.json", "a").write("\n")
print(json.dumps(b["frame_time"], indent=0))
