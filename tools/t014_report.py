#!/usr/bin/env python3
"""T014 bot report: reads the JSON files tools/t014_bots.gd wrote and prints them as one.
python3 tools/t014_report.py a.json b.json ... > docs/screens/T014/bots.txt
"""
import json
import statistics as st
import sys

rows = {}
for path in sys.argv[1:]:
    for bot, sessions in json.load(open(path)).items():
        rows.setdefault(bot, []).extend(sessions)

for bot, sessions in rows.items():
    sessions.sort(key=lambda s: s["seed"])
    shifts = [x for s in sessions for x in s["shifts"]]
    alive = [x for x in shifts if x["outcome"] == "extracted"]
    cycles = [c for s in sessions for c in s["cycles"]]
    met = [c for c in cycles if c["met"]]
    deaths = sum(int(s["deaths"]) for s in sessions)
    print("== %s: %d sessions, %d shifts" % (bot, len(sessions), len(shifts)))
    print("quotas met %d of %d (%.0f%%); mean surplus when met %.0f" % (len(met), len(cycles), 100 * len(met) / max(len(cycles), 1), st.mean(c["surplus"] for c in met) if met else 0))
    for i in range(max((len(s["cycles"]) for s in sessions), default=0)):
        here = [s["cycles"][i] for s in sessions if len(s["cycles"]) > i]
        print("  quota %d (%d CR): met %d of %d; mean surplus %.0f; mean shortfall on a miss %.0f" % (
            i + 1, here[0]["quota"], sum(c["met"] for c in here), len(here),
            st.mean(c["surplus"] for c in here if c["met"]) if any(c["met"] for c in here) else 0,
            st.mean(c["shortfall"] for c in here if not c["met"]) if any(not c["met"] for c in here) else 0))
    print("sessions reaching the cap (not fired): %d of %d; quotas met per session, mean %.1f" % (sum(not s["fired"] for s in sessions), len(sessions), st.mean(int(s["cycles_met"]) for s in sessions)))
    print("deaths %d of %d shifts (%.0f%%)" % (deaths, len(shifts), 100 * deaths / max(len(shifts), 1)))
    causes = {}
    for x in shifts:
        if x["cause"]:
            causes[x["cause"]] = causes.get(x["cause"], 0) + 1
    print("deaths by", causes)
    print("net per shift, deaths and all: %.0f" % st.mean(x["net"] for x in shifts))
    print("prize taken in %d of %d shifts" % (sum(bool(x["prize"]) for x in shifts), len(shifts)))
    for key in ["gross", "deductions", "net", "rounds", "cycles", "time_s", "items"]:
        vals = [float(x[key]) for x in alive]
        if vals:
            print("  survivors' %-10s mean %7.0f  median %7.0f  min %7.0f  max %7.0f" % (key, st.mean(vals), st.median(vals), min(vals), max(vals)))
    lines = {}
    for x in alive:
        for l in x.get("lines", []):
            lines[l["id"]] = lines.get(l["id"], 0) + l["amount_cr"]
    print("  mean charge per surviving shift:", {k: round(v / max(len(alive), 1)) for k, v in lines.items()})
    bills = [x["death_bill"] for x in shifts if x["death_bill"]]
    if bills:
        print("  death bill mean %.0f, max %d" % (st.mean(bills), max(bills)))
    print("  negative payslips: %d of %d" % (sum(x["net"] < 0 for x in alive), len(alive)))
    print()
