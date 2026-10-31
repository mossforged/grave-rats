#!/usr/bin/env python3
"""Q001: turns a health_check.sh run into docs/qa/health-<date>.md and .json, comparing with baseline.json.
usage: health_report.py <raw-dir> <qa-dir> [--write-baseline | --add-baseline]
--write-baseline replaces every number in baseline.json. --add-baseline only adds scenes and bot sets it has no
entry for and leaves the rest untouched (Q002).
Exit: 0 nothing red, 1 something red."""
import glob, json, os, re, sys

DEFAULT_THRESHOLDS = {
    "frame_avg_ms": 0.5,
    "frame_p95_ms": 1.0,
    "bot_metric_pct": 25.0,
    "flicker_pct": 25.0,
    "red_multiplier": 2.0,
    "_note": "Over a threshold is amber; over threshold x red_multiplier is red. Any flaky test is amber. "
             "Any import error, always-failing test, load error, or missing number is red.",
}
# Context only, from T011's packet; missing them raises no flag.
TARGETS = {"pirate_deck": {"avg": 7.5, "p95": 9.5}}
RANK = {"green": 0, "amber": 1, "red": 2}
SCENES = ("pirate_deck", "stalker_deck", "shift_deck")
# Q002: the T012, T014 and T015 tools. Each writes a JSON file, read by bot_json_sets.
JSON_BOT_SETS = ("t012", "t015_shift", "t014", "t015")
BOT_SETS = ("t006", "t007", "foot_slide", "foot_slide_realtime") + JSON_BOT_SETS
WANT_RES = "1920x1080"


def read(path):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def worst(*levels):
    return max(levels, key=lambda s: RANK[s], default="green")


def engine_errors(text):
    """ERROR and SCRIPT ERROR lines, counted by message."""
    out = {}
    for m in re.finditer(r"^(?:USER |SCRIPT )?ERROR: (.*)$", re.sub(r"\x1b\[[0-9;]*m", "", text), re.M):
        out[m.group(1)[:120]] = out.get(m.group(1)[:120], 0) + 1
    return out


def read_meta(raw):
    meta = {}
    for line in read(os.path.join(raw, "meta.txt")).splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            meta[k] = v.strip()
    return meta


def read_tests(raw, meta):
    runs, failed_in = [], {}
    for i in (1, 2, 3):
        text = read(os.path.join(raw, f"tests_{i}.log"))
        m = re.search(r"^TESTS: (\d+) passed, (\d+) failed, (\d+) load errors", text, re.M)
        names = re.findall(r"^FAIL  (\S+)", text, re.M)
        load = re.findall(r"^LOAD ERROR\s+(.*)$", text, re.M)
        for n in names:
            failed_in.setdefault(n, []).append(i)
        runs.append({
            "run": i, "rc": meta.get(f"tests_{i}_rc"), "finished": bool(m),
            "passed": int(m.group(1)) if m else None, "failed": int(m.group(2)) if m else None,
            "load_errors": int(m.group(3)) if m else None, "load_error_files": load, "failed_tests": names,
        })
    flaky = {n: r for n, r in failed_in.items() if len(r) < 3}
    always = sorted(n for n, r in failed_in.items() if len(r) == 3)
    return {"runs": runs, "flaky": flaky, "always_failing": always}


def read_frames(raw):
    windows = []
    for line in read(os.path.join(raw, "frame", "windows.txt")).splitlines():
        m = re.match(r"(\S+) (\d+) rc=(\d+) before=(.*) after=(.*)", line)
        if not m:
            continue
        name, w = m.group(1), m.group(2)
        row = {"scene": name, "window": int(w), "rc": int(m.group(3)),
               "load_before": m.group(4), "load_after": m.group(5)}
        try:
            with open(os.path.join(raw, "frame", f"{name}_{w}", "frametime.json")) as f:
                d = json.load(f)
            row.update({k: d.get(k) for k in ("frame_ms_avg", "frame_ms_p95", "frame_ms_p99", "frame_ms_max",
                                              "frames", "resolution", "msaa_3d", "adapter", "rendering_driver")})
        except (OSError, ValueError):
            row["missing"] = True
        windows.append(row)
    summary = {}
    for s in SCENES:
        good = [w for w in windows if w["scene"] == s and not w.get("missing")]
        if good:
            summary[s] = {
                "avg": round(sum(w["frame_ms_avg"] for w in good) / len(good), 3),
                "p95": round(sum(w["frame_ms_p95"] for w in good) / len(good), 3),
                "resolution": good[0]["resolution"],
            }
    return {"windows": windows, "summary": summary}


def read_bots(text):
    """{'scenario | key': {'mean': x or None, 'runs': n, 'of': N}}"""
    out, title = {}, ""
    for line in text.splitlines():
        if not line.startswith("OUT"):
            continue
        m = re.match(r"OUT\s+(\S+)\s+mean\s+(-?[\d.]+).*\((\d+) of (\d+) runs\)", line)
        n = re.match(r"OUT\s+(\S+)\s+never in (\d+) runs", line)
        if m:
            out[f"{title} | {m.group(1)}"] = {"mean": float(m.group(2)), "runs": int(m.group(3)), "of": int(m.group(4))}
        elif n:
            out[f"{title} | {n.group(1)}"] = {"mean": None, "runs": 0, "of": int(n.group(2))}
        else:
            title = line[3:].strip()
    return out


def read_footslide(raw, logs):
    rows = {}
    pat = re.compile(r"^(.+?)\s+body ([\d.]+) m/s\s+planted foot slides ([\d.]+) m/s \((\d+)% of the body speed\), planted (\d+)%", re.M)
    for log in logs:
        for m in pat.finditer(read(os.path.join(raw, f"{log}.log"))):
            rows.setdefault(m.group(1).strip(), []).append((float(m.group(2)), float(m.group(3)), float(m.group(5))))
    out = {}
    for case, vals in rows.items():
        n = len(vals)
        out[f"{case} | body_m_s"] = round(sum(v[0] for v in vals) / n, 3)
        out[f"{case} | slide_m_s"] = round(sum(v[1] for v in vals) / n, 3)
        out[f"{case} | planted_pct"] = round(sum(v[2] for v in vals) / n, 2)
    return out


def read_flicker(raw):
    out = {}
    for m in re.finditer(r"/(\S+?): moved ([\d.]+)% .*twinkle ([\d.]+)% \(max ([\d.]+)%\)", read(os.path.join(raw, "flicker_diff.log"))):
        out[m.group(1)] = {"moved_pct": float(m.group(2)), "twinkle_pct": float(m.group(3)), "twinkle_max_pct": float(m.group(4))}
    return out


def read_json_files(raw, name):
    """{key: rows} from <raw>/<name>.json and <name>.part*.json; a tool split across processes writes several files with the same keys."""
    out = {}
    for path in sorted(glob.glob(os.path.join(raw, f"{name}.json")) + glob.glob(os.path.join(raw, f"{name}.part*.json"))):
        try:
            with open(path) as f:
                for key, rows in json.load(f).items():
                    out.setdefault(key, []).extend(rows)
        except (OSError, ValueError):
            pass
    return out


def mean(vals):
    vals = list(vals)
    return round(sum(vals) / len(vals), 2) if vals else None


def shift_metrics(by_bot):
    """T012's bots, whole shifts: the numbers T012 and T015 report. Causes of death are context (see shift_causes)."""
    out = {}
    for bot, rows in by_bot.items():
        out[f"{bot} | survived"] = sum(r["outcome"] == "extracted" for r in rows)
        for key in ("banked", "deposited", "items", "lost", "tier", "time_s", "prize"):
            out[f"{bot} | {key} (mean)"] = mean(float(r[key]) for r in rows)
    return out


def shift_causes(rows):
    out = {}
    for r in rows:
        if r.get("cause") is not None:
            out[r["cause"]] = out.get(r["cause"], 0) + 1
    return dict(sorted(out.items()))


def session_metrics(by_bot):
    """T014's bots, whole sessions: the numbers tools/t014_report.py prints."""
    out = {}
    for bot, sessions in by_bot.items():
        shifts = [x for s in sessions for x in s["shifts"]]
        alive = [x for x in shifts if x["outcome"] == "extracted"]
        cycles = [c for s in sessions for c in s["cycles"]]
        first = [s["cycles"][0] for s in sessions if s["cycles"]]
        deaths = sum(int(s["deaths"]) for s in sessions)
        out[f"{bot} | sessions"] = len(sessions)
        out[f"{bot} | fired"] = sum(bool(s["fired"]) for s in sessions)
        out[f"{bot} | quota_1_met"] = sum(bool(c["met"]) for c in first)
        out[f"{bot} | quotas_met"] = sum(bool(c["met"]) for c in cycles)
        out[f"{bot} | quotas_due"] = len(cycles)
        out[f"{bot} | quotas_met_per_session (mean)"] = mean(int(s["cycles_met"]) for s in sessions)
        out[f"{bot} | shifts"] = len(shifts)
        out[f"{bot} | deaths"] = deaths
        out[f"{bot} | death_pct"] = round(100.0 * deaths / max(len(shifts), 1), 1)
        out[f"{bot} | net_per_shift_deaths_at_0 (mean)"] = mean(float(x["net"]) for x in shifts)
        out[f"{bot} | survivors_gross (mean)"] = mean(float(x["gross"]) for x in alive)
        out[f"{bot} | survivors_deductions (mean)"] = mean(float(x["deductions"]) for x in alive)
        out[f"{bot} | negative_payslips"] = sum(float(x["net"]) < 0 for x in alive)
    return out


def session_causes(sessions):
    return shift_causes([x for s in sessions for x in s["shifts"]])


def window_metrics(by_case):
    """T015's 90 s windows: the mean of each number the tool counts."""
    out = {}
    for case, rows in by_case.items():
        for key in (rows[0] if rows else {}):
            out[f"{case} | {key} (mean)"] = mean(float(r[key]) for r in rows)
    return out


def pct_level(base, cur, limit, mult):
    """(pct change or None, level)"""
    if base is None and cur is None:
        return None, "green"
    if base is None or cur is None:
        return None, "amber"
    if base == 0:
        return None, "green" if cur == 0 else "amber"
    pct = (cur - base) / abs(base) * 100.0
    size = abs(pct)
    return round(pct, 1), "red" if size > limit * mult else "amber" if size > limit else "green"


def abs_level(delta, limit, mult):
    # Only slower counts; the packet's thresholds are all "+".
    return "red" if delta > limit * mult else "amber" if delta > limit else "green"


def compare_numbers(cur, base, limit, mult):
    """Flat {id: number or None} against the same; returns rows, level. Missing number now is red."""
    rows, level = [], "green"
    for key in sorted(set(cur) | set(base)):
        if key not in cur:
            rows.append({"id": key, "base": base[key], "now": None, "pct": None, "level": "red", "note": "gone from this run"})
            level = "red"
            continue
        if key not in base:
            rows.append({"id": key, "base": None, "now": cur[key], "pct": None, "level": "green", "note": "new"})
            continue
        pct, lv = pct_level(base[key], cur[key], limit, mult)
        rows.append({"id": key, "base": base[key], "now": cur[key], "pct": pct, "level": lv})
        level = worst(level, lv)
    return rows, level


def flat_bots(bots):
    flat = {}
    for key, v in bots.items():
        flat[f"{key} (mean)"] = v["mean"]
        flat[f"{key} (runs seen)"] = v["runs"]
    return flat


def main():
    raw, qa = sys.argv[1], sys.argv[2]
    write_baseline = "--write-baseline" in sys.argv[3:]
    add_baseline = "--add-baseline" in sys.argv[3:]
    meta = read_meta(raw)
    date = meta.get("date", "unknown")
    base_path = os.path.join(qa, "baseline.json")
    baseline = None
    if os.path.exists(base_path):
        with open(base_path) as f:
            baseline = json.load(f)
    th = dict(DEFAULT_THRESHOLDS)
    if baseline:
        th.update(baseline.get("thresholds", {}))
    mult = float(th["red_multiplier"])

    # Fresh clone
    import_text = read(os.path.join(raw, "import.log"))
    import_errors = engine_errors(import_text)
    tests = read_tests(raw, meta)
    clone_notes, clone_level = [], "green"
    if meta.get("import_rc") != "0":
        clone_level = "red"; clone_notes.append(f"import exit code {meta.get('import_rc')}")
    if import_errors:
        clone_level = "red"; clone_notes.append(f"{sum(import_errors.values())} import errors")
    if int(meta.get("imported_count", "0") or 0) == 0:
        clone_level = "red"; clone_notes.append("nothing landed in .godot/imported")
    if meta.get("clone_fallback"):
        clone_level = worst(clone_level, "amber"); clone_notes.append(meta["clone_fallback"])
    for r in tests["runs"]:
        if not r["finished"]:
            clone_level = "red"; clone_notes.append(f"test run {r['run']} never finished")
        elif r["load_errors"]:
            clone_level = "red"; clone_notes.append(f"test run {r['run']}: {r['load_errors']} load errors")
    if tests["always_failing"]:
        clone_level = "red"; clone_notes.append(f"{len(tests['always_failing'])} tests fail every run")
    if tests["flaky"]:
        clone_level = worst(clone_level, "amber"); clone_notes.append(f"{len(tests['flaky'])} flaky tests")

    # Frame time
    frames = read_frames(raw)
    frame_notes, frame_level, frame_rows = [], "green", []
    for s in SCENES:
        cur = frames["summary"].get(s)
        if not cur:
            frame_level = "red"; frame_notes.append(f"{s}: no frame-time numbers")
            continue
        if cur["resolution"] != WANT_RES:
            frame_level = worst(frame_level, "amber"); frame_notes.append(f"{s} measured at {cur['resolution']}, not {WANT_RES}")
        b = (baseline or {}).get("frame_time", {}).get(s)
        if b:
            da, dp = cur["avg"] - b["avg"], cur["p95"] - b["p95"]
            la, lp = abs_level(da, th["frame_avg_ms"], mult), abs_level(dp, th["frame_p95_ms"], mult)
            frame_rows.append({"scene": s, "base_avg": b["avg"], "avg": cur["avg"], "d_avg": round(da, 2), "level_avg": la,
                               "base_p95": b["p95"], "p95": cur["p95"], "d_p95": round(dp, 2), "level_p95": lp})
            frame_level = worst(frame_level, la, lp)
    for c in frame_rows:
        if c["level_avg"] != "green":
            frame_notes.append(f"{c['scene']} average {c['d_avg']:+.2f} ms")
        if c["level_p95"] != "green":
            frame_notes.append(f"{c['scene']} p95 {c['d_p95']:+.2f} ms")
    if len([w for w in frames["windows"] if w.get("missing")]):
        frame_level = "red"; frame_notes.append("a capture window wrote no frametime.json")
    if meta.get("under_load"):
        frame_level = worst(frame_level, "amber"); frame_notes.append(f"measured under load: code lane busy during {meta['under_load']}")

    # Bots
    t006, t007 = read_bots(read(os.path.join(raw, "t006.log"))), read_bots(read(os.path.join(raw, "t007.log")))
    foot = read_footslide(raw, ["footslide_fixed"])
    foot_rt = read_footslide(raw, ["footslide_1", "footslide_2", "footslide_3"])
    t012_rows, t015s_rows = read_json_files(raw, "t012"), read_json_files(raw, "t015_shift")
    t014_rows, t015_rows = read_json_files(raw, "t014"), read_json_files(raw, "t015")
    bot_now = {"t006": flat_bots(t006), "t007": flat_bots(t007), "foot_slide": foot, "foot_slide_realtime": foot_rt,
               "t012": shift_metrics(t012_rows), "t015_shift": shift_metrics(t015s_rows),
               "t014": session_metrics(t014_rows), "t015": window_metrics(t015_rows)}
    causes = {"t012": {b: shift_causes(r) for b, r in t012_rows.items()},
              "t015_shift": {b: shift_causes(r) for b, r in t015s_rows.items()},
              "t014": {b: session_causes(r) for b, r in t014_rows.items()}}
    bot_rows, bot_level, bot_notes = {}, "green", []
    for name in BOT_SETS:
        if not bot_now[name]:
            bot_level = "red"; bot_notes.append(f"{name}: no numbers (see its log)")
        rows, lv = compare_numbers(bot_now[name], (baseline or {}).get("bots", {}).get(name, {}), th["bot_metric_pct"], mult)
        bot_rows[name] = rows
        if baseline:
            bot_level = worst(bot_level, lv)
    for rc in ("t006_rc", "t007_rc", "footslide_fixed_rc", "footslide_1_rc", "footslide_2_rc", "footslide_3_rc",
               "t012_rc", "t015_shift_rc", "t015_rc") + tuple(k for k in meta if re.fullmatch(r"t014_\d+_rc", k)):
        if meta.get(rc) != "0":
            bot_level = "red"; bot_notes.append(f"{rc} = {meta.get(rc)}")
    if not any(re.fullmatch(r"t014_\d+_rc", k) for k in meta):
        bot_level = "red"; bot_notes.append("t014: never ran")
    logged = {}
    for log in ("tests_1", "t006", "t007", "footslide_1", "t012", "t015_shift", "t014_0", "t015", "flicker",
                "frame/pirate_deck_1", "frame/stalker_deck_1", "frame/shift_deck_1"):
        errors = engine_errors(read(os.path.join(raw, f"{log}.log")))
        if errors:
            logged[log] = errors

    # Flicker
    flicker = read_flicker(raw)
    flick_notes, flick_level = [], "green"
    if not flicker:
        flick_level = "red"; flick_notes.append("no twinkle numbers (see flicker.log, flicker_diff.log)")
    flick_now = {k: v["twinkle_pct"] for k, v in flicker.items()}
    flick_rows, lv = compare_numbers(flick_now, (baseline or {}).get("flicker", {}), th["flicker_pct"], mult)
    if baseline:
        flick_level = worst(flick_level, lv)

    areas = {
        "fresh_clone": {"level": clone_level, "notes": clone_notes},
        "frame_time": {"level": frame_level, "notes": frame_notes},
        "bots": {"level": bot_level, "notes": bot_notes},
        "flicker": {"level": flick_level, "notes": flick_notes},
    }
    flagged = lambda rows: [r for r in rows if r["level"] != "green"]
    for name in BOT_SETS:
        n = len(flagged(bot_rows[name]))
        if n:
            bot_notes.append(f"{name}: {n} of {len(bot_rows[name])} metrics moved")
    if flagged(flick_rows):
        flick_notes.append(f"{len(flagged(flick_rows))} of {len(flick_rows)} twinkle numbers moved")
    overall = worst(*[a["level"] for a in areas.values()])

    report = {
        "date": date, "overall": overall, "meta": meta, "areas": areas,
        "baseline": {"present": bool(baseline), "commit": (baseline or {}).get("commit"), "date": (baseline or {}).get("date"), "thresholds": th},
        "tests": tests, "import_errors": import_errors,
        "frame_time": {**frames, "compare": frame_rows, "targets": TARGETS},
        "bots": {"t006": t006, "t007": t007, "foot_slide": foot, "foot_slide_realtime": foot_rt,
                 **{name: bot_now[name] for name in JSON_BOT_SETS}, "causes": causes, "compare": bot_rows},
        "engine_errors": logged,
        "flicker": {"now": flicker, "compare": flick_rows},
    }

    if write_baseline or not baseline:
        kept = {k: v for k, v in th.items()}
        with open(base_path, "w") as f:
            json.dump({"date": date, "commit": meta.get("commit"), "thresholds": kept, "targets": TARGETS,
                       "frame_time": frames["summary"], "bots": bot_now, "flicker": flick_now, "load": [
                           {k: w.get(k) for k in ("scene", "window", "load_before", "load_after")} for w in frames["windows"]]},
                      f, indent=2)
            f.write("\n")
        report["baseline"]["written_this_run"] = True
    elif add_baseline:
        added = []
        for s in SCENES:
            if s in frames["summary"] and s not in baseline.setdefault("frame_time", {}):
                baseline["frame_time"][s] = frames["summary"][s]
                added.append(f"frame_time.{s}")
        for name in BOT_SETS:
            if bot_now[name] and name not in baseline.setdefault("bots", {}):
                baseline["bots"][name] = bot_now[name]
                added.append(f"bots.{name}")
        if added:
            baseline.setdefault("added", []).append({"date": date, "commit": meta.get("commit"), "entries": added})
            baseline.setdefault("load", []).extend(
                {k: w.get(k) for k in ("scene", "window", "load_before", "load_after")}
                for w in frames["windows"] if f"frame_time.{w['scene']}" in added)
            with open(base_path, "w") as f:
                json.dump(baseline, f, indent=2)
                f.write("\n")
        report["baseline"]["added_this_run"] = added

    os.makedirs(qa, exist_ok=True)
    with open(os.path.join(qa, f"health-{date}.json"), "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
    with open(os.path.join(qa, f"health-{date}.md"), "w") as f:
        f.write(render(report, th))
    return 1 if overall == "red" else 0


def render(r, th):
    m = r["meta"]
    a = r["areas"]
    out = [f"# Health check {r['date']}: {r['overall'].upper()}", ""]
    out += [f"Commit `{m.get('commit', '?')}` from {m.get('clone_source', '?')}. Godot {m.get('godot', '?')}, {m.get('chip', '?')}, macOS {m.get('macos', '?')}. "
            f"Took {int(m.get('seconds_total', 0)) // 60} min. Waited {m.get('waited_s', '0')} s for the code lane."]
    b = r["baseline"]
    if b.get("written_this_run"):
        out += ["", "**Baseline written from this run, so its comparisons are against itself or an older baseline; see the tables.**"]
    elif not b["present"]:
        out += ["", "**No baseline: nothing compared.**"]
    else:
        out += ["", f"Compared with baseline `{b['commit']}` ({b['date']})."]
        if b.get("added_this_run"):
            out += ["", f"First numbers, added to the baseline by this run, so nothing to compare yet: {', '.join(b['added_this_run'])}. Every other baseline number was left alone."]
    out += ["", "## Summary", "", "| Area | Level | Notes |", "| --- | --- | --- |"]
    for key, title in (("fresh_clone", "Fresh clone and tests"), ("frame_time", "Frame time"), ("bots", "Bots and foot slide"), ("flicker", "Flicker")):
        out.append(f"| {title} | **{a[key]['level']}** | {'; '.join(a[key]['notes']) or 'nothing flagged'} |")

    out += ["", "Levels: over a threshold is amber, over twice it is red; a flaky test is amber; an import error, a test failing every run, or a missing number is red. "
            f"Thresholds (in `docs/qa/baseline.json`): frame time average +{th['frame_avg_ms']} ms, p95 +{th['frame_p95_ms']} ms; bot metric ±{th['bot_metric_pct']}%; twinkle ±{th['flicker_pct']}%."]

    out += ["", "## Fresh clone and tests", "", f"Import: exit {m.get('import_rc')}, {sum(r['import_errors'].values())} errors, "
            f"{m.get('import_files')} `.import` files, {m.get('imported_count')} files in `.godot/imported`. Clone {m.get('seconds_clone')} s, import {m.get('seconds_import')} s, three test runs {m.get('seconds_tests')} s.", ""]
    for msg, n in r["import_errors"].items():
        out.append(f"- import error x{n}: `{msg}`")
    out += ["| Run | Passed | Failed | Load errors | Exit |", "| --- | --- | --- | --- | --- |"]
    for t in r["tests"]["runs"]:
        out.append(f"| {t['run']} | {t['passed']} | {t['failed']} | {t['load_errors']} | {t['rc']} |")
    if r["tests"]["flaky"]:
        out += ["", "Flaky (failed in some runs):"] + [f"- `{n}`: runs {v}" for n, v in r["tests"]["flaky"].items()]
    if r["tests"]["always_failing"]:
        out += ["", "Failed in every run:"] + [f"- `{n}`" for n in r["tests"]["always_failing"]]
    out += ["", "Repro: clone main, `godot --headless --path . --import`, then `godot --headless --path . -s tests/run_tests.gd` (logs: `docs/qa/logs-" + r["date"] + "/tests_*.log`)."]

    ft = r["frame_time"]
    out += ["", "## Frame time", "", "Windowed on the real GPU, vsync off, project default quality on main; the game's capture readout (`src/debug/capture.gd`). During a capture each deck plays its `_demo_step` loop: the operator walks, aims and fires among live enemies, so the windows are a scripted fight, not an idle room. `shift_deck` runs with no session, three stalkers hunting and CUSTODIAN awake. The enemies aren't seeded, so no two windows are the same frames. Stills are whatever frame the window ended on; a red one is the hit flash.", ""]
    out += ["| Scene | Window | Resolution | MSAA | Frames | Avg ms | p95 ms | p99 ms | Load before (1/5/15 min) | Load after |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for w in ft["windows"]:
        if w.get("missing"):
            out.append(f"| {w['scene']} | {w['window']} | no data (exit {w['rc']}) | | | | | | {w['load_before']} | {w['load_after']} |")
        else:
            out.append(f"| {w['scene']} | {w['window']} | {w['resolution']} | {w['msaa_3d']} | {w['frames']} | {w['frame_ms_avg']:.2f} | {w['frame_ms_p95']:.2f} | {w['frame_ms_p99']:.2f} | {w['load_before']} | {w['load_after']} |")
    if ft["compare"]:
        out += ["", "Mean of the windows against the baseline:", "", "| Scene | Avg base → now (Δ) | | p95 base → now (Δ) | |", "| --- | --- | --- | --- | --- |"]
        for c in ft["compare"]:
            out.append(f"| {c['scene']} | {c['base_avg']:.2f} → {c['avg']:.2f} ({c['d_avg']:+.2f}) | {c['level_avg']} | {c['base_p95']:.2f} → {c['p95']:.2f} ({c['d_p95']:+.2f}) | {c['level_p95']} |")
    for s, t in ft["targets"].items():
        now = ft["summary"].get(s)
        if now:
            verdict = "met" if now["avg"] < t["avg"] and now["p95"] < t["p95"] else "missed"
            out += ["", f"T011's target for {s} (context, not a flag): under {t['avg']} / {t['p95']} ms. This run {now['avg']:.2f} / {now['p95']:.2f}: {verdict}."]
    out += ["", f"Stills: `docs/screens/qa-{r['date']}/`. Busiest processes after the windows: `docs/qa/logs-{r['date']}/top_cpu.txt`.",
            "", "Repro: `CAPTURE_ONLY=none tools/capture.sh scenes/pirates/pirate_deck.tscn /tmp/q 30` (same for `scenes/enemies/stalker_deck.tscn`, `scenes/shift/shift_deck.tscn`)."]

    bots = r["bots"]
    out += ["", "## Bots and foot slide", "", f"`tools/qa/t006_seeded.gd` and `t007_seeded.gd` ({m.get('seconds_bots')} s with foot slide; the T012 to T015 bots another {m.get('seconds_session_bots')} s, run together). Fixed seeds, so a change here means the game changed, not the dice. Foot slide runs `tools/t003_footslide.gd` twice over: once at `--fixed-fps 60` (repeatable) and three times in real time, averaged (the tool's documented usage, noisier, comparable with the T003-T009 tables). The two modes read very differently; compare like with like."]
    for name, title in (("t006", "T006 stalker bots"), ("t007", "T007 pirate bots")):
        out += ["", f"### {title}", ""] + bot_table(bots[name], bots["compare"][name])
    for name, title in (("foot_slide", "Foot slide, fixed step"), ("foot_slide_realtime", "Foot slide, real time (mean of 3)"),
                        ("t012", "T012 shift bots, tell-blind"), ("t015_shift", "T015 shift bots, read the cutter ring"),
                        ("t014", "T014 session bots"), ("t015", "T015 tell bots, 90 s windows")):
        out += ["", f"### {title}", "", "| Case | Metric | Baseline | Now | Change | Level |", "| --- | --- | --- | --- | --- | --- |"]
        for c in bots["compare"][name]:
            case, metric = c["id"].split(" | ")
            out.append(f"| {case} | {metric} | {fmt(c['base'])} | {fmt(c['now'])} | {fmt_pct(c['pct'])} | {c['level']} |")
        for bot, counts in bots["causes"].get(name, {}).items():
            out += ["", f"{bot}, deaths by cause: {json.dumps(counts)}."]
    out += ["", "Repro: `godot --headless --path . --fixed-fps 60 -s tools/qa/t006_seeded.gd` (or `t007_seeded.gd`), `godot --headless --path . [--fixed-fps 60] -s tools/t003_footslide.gd`. The T012 to T015 commands are in `tools/qa/health_check.sh`."]

    fl = r["flicker"]
    out += ["", "## Flicker", "", "`tools/t008_flicker.gd`, 60 frames at 60 fps; `turn_beam_on` is the turning-slowly number (10°/s). Twinkle: % of screen.", "",
            "| Case | Moved % | Twinkle % | Max % | Baseline twinkle % | Change | Level |", "| --- | --- | --- | --- | --- | --- | --- |"]
    by = {c["id"]: c for c in fl["compare"]}
    for tag, v in sorted(fl["now"].items()):
        c = by.get(tag, {"base": None, "pct": None, "level": "green"})
        out.append(f"| {tag} | {v['moved_pct']:.3f} | {v['twinkle_pct']:.4f} | {v['twinkle_max_pct']:.4f} | {fmt(c['base'], 4)} | {fmt_pct(c['pct'])} | {c['level']} |")
    out += ["", f"Repro: `godot --path . --fixed-fps 60 -s tools/t008_flicker.gd -- --out=/tmp/f`, then `python3 tools/t008_flicker_diff.py /tmp/f`."]
    out += ["", "## Engine errors logged (counted, not flagged)", ""]
    if r["engine_errors"]:
        out += ["| Log | Count | Message |", "| --- | --- | --- |"]
        for log, errors in r["engine_errors"].items():
            for msg, n in errors.items():
                out.append(f"| {log} | {n} | `{msg}` |")
    else:
        out.append("None.")
    return "\n".join(out) + "\n"


def bot_table(now, compare):
    by = {c["id"]: c for c in compare}
    rows = ["| Scenario | Metric | Baseline | Now | Change | Runs seen | Level |", "| --- | --- | --- | --- | --- | --- | --- |"]
    last = None
    for key, v in now.items():
        scenario, metric = key.split(" | ")
        mean, runs = by.get(f"{key} (mean)", {}), by.get(f"{key} (runs seen)", {})
        lv = worst(mean.get("level", "green"), runs.get("level", "green"))
        shown = scenario if scenario != last else ""
        last = scenario
        rows.append(f"| {shown} | {metric} | {fmt(mean.get('base'))} | {fmt(v['mean'])} | {fmt_pct(mean.get('pct'))} | {v['runs']}/{v['of']} (was {fmt(runs.get('base'), 0)}) | {lv} |")
    for key, c in by.items():
        if c.get("note") == "gone from this run":
            rows.append(f"| {key} | | {fmt(c['base'])} | gone | | | red |")
    return rows


def fmt(v, digits=2):
    return "–" if v is None else f"{v:.{digits}f}"


def fmt_pct(p):
    return "–" if p is None else f"{p:+.1f}%"


if __name__ == "__main__":
    sys.exit(main())
