#!/usr/bin/env python3
"""Q003: frame cost of each packet. Runs windows on several commits in turn, with the order rotating every round, so
drift on a busy Mac lands on all of them alike. Every window is watched by guard.sh and any window another Godot or the
code lane touched is rejected and owed again.

usage: packet_cost.py <out-dir> <deadline HH:MM> <rounds> <seconds> <job> [<job> ...]
  job = <label>=<commit>:<scene>[:<Q003_FX mode>]
Writes <out-dir>/windows.tsv (one line per window, kept as it goes) and summary.json (median of the clean windows, and the
spread, per label, scene and mode). Env QA_LOAD_MAX: load to start a window under (default 8).
"""
import datetime, json, os, shutil, statistics, subprocess, sys, tempfile, threading, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUARD = str(ROOT / "tools/qa/guard.sh")
GODOT = os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
LOAD_MAX = float(os.environ.get("QA_LOAD_MAX", "8"))


def say(*a):
    print(time.strftime("[%H:%M:%S]"), *a, flush=True)


def busy(exempt):
    r = subprocess.run([GUARD, exempt], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


class Watch(threading.Thread):
    """Notes the first thing that touches the window, and the worst load seen during it."""
    def __init__(self, exempt):
        super().__init__(daemon=True)
        self.exempt, self.why, self.peak, self.stop_at = exempt, "", 0.0, threading.Event()

    def run(self):
        while not self.stop_at.wait(2.0):
            self.why = self.why or busy(self.exempt)
            self.peak = max(self.peak, os.getloadavg()[0])


def main():
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    h, m = sys.argv[2].split(":")
    now = datetime.datetime.now()
    deadline = now.replace(hour=int(h), minute=int(m), second=0).timestamp()
    rounds, seconds = int(sys.argv[3]), sys.argv[4]
    jobs = []
    for j in sys.argv[5:]:
        label, rest = j.split("=", 1)
        parts = rest.split(":")
        jobs.append({"label": label, "commit": parts[0], "scene": parts[1], "mode": parts[2] if len(parts) > 2 else ""})
    work = Path(tempfile.mkdtemp(prefix="grave-rats-cost."))
    tsv = (out / "windows.tsv").open("a")
    try:
        clones = {}
        for commit in dict.fromkeys(j["commit"] for j in jobs):
            c = work / commit
            subprocess.run(["git", "clone", "-q", "--shared", str(ROOT), str(c)], check=True)
            subprocess.run(["git", "-C", str(c), "checkout", "-q", commit], check=True)
            (c / "tools/qa").mkdir(parents=True, exist_ok=True)
            for f in (ROOT / "tools/qa").glob("q003_fx_*"):
                shutil.copy(f, c / "tools/qa")
            say("importing", commit)
            subprocess.run([GODOT, "--headless", "--path", str(c), "--import"], capture_output=True, timeout=900)
            # As the health check does on this display: a titled window falls short of 1080.
            (c / "override.cfg").write_text("[display]\n\nwindow/size/borderless=true\n")
            clones[commit] = c

        def capture(job, dest, secs):
            env = dict(os.environ, CAPTURE_ONLY="none", CAPTURE_SIZE="1920x1080", GODOT=GODOT, Q003_FX=job["mode"])
            with open(str(dest) + ".log", "w") as log:
                return subprocess.run([str(clones[job["commit"]] / "tools/capture.sh"), job["scene"], str(dest), str(secs)],
                                      env=env, stdout=log, stderr=subprocess.STDOUT, timeout=int(float(secs)) + 180).returncode

        def wait_quiet():
            while busy(str(work)) or os.getloadavg()[0] >= LOAD_MAX:
                if time.time() >= deadline:
                    return False
                time.sleep(10)
            return time.time() < deadline

        for job in jobs:
            if not wait_quiet():
                say("deadline while warming"); return
            say("warming", job["label"], job["scene"], job["mode"])
            capture(job, work / "warm", 3)

        done = {}
        n = 0
        while True:
            todo = [j for j in jobs if done.get(id(j), 0) < rounds]
            if not todo:
                say("all windows clean"); break
            # Rotate which commit goes first, deck by deck.
            shift = n % len(todo)
            for job in todo[shift:] + todo[:shift]:
                if done.get(id(job), 0) >= rounds:
                    continue
                if not wait_quiet():
                    say("deadline reached"); return
                n += 1
                dest = out / f"{job['label']}_{Path(job['scene']).stem}{('_' + job['mode']) if job['mode'] else ''}_{n}"
                before = os.getloadavg()[0]
                w = Watch(str(work)); w.start()
                try:
                    rc = capture(job, dest, seconds)
                except subprocess.TimeoutExpired:
                    rc = "timeout"
                w.stop_at.set(); w.join()
                state = "dirty" if w.why else "clean"
                try:
                    d = json.loads((dest / "frametime.json").read_text())
                except (OSError, ValueError):
                    d, state = {}, "missing"
                # A stand that failed to parse still writes a frametime.json, of an empty scene.
                if state == "clean" and job["mode"] and not (dest / "q003_fx.json").exists():
                    state = "stand-failed"
                if state == "clean" and d.get("resolution") != "1920x1080":
                    state = "wrong-size"
                if state == "clean":
                    done[id(job)] = done.get(id(job), 0) + 1
                extra = {}
                try:
                    extra = json.loads((dest / "q003_fx.json").read_text())
                except (OSError, ValueError):
                    pass
                row = [job["label"], job["commit"], Path(job["scene"]).stem, job["mode"], n, state, d.get("resolution", ""), d.get("screen_scale", ""),
                       d.get("frames", ""), round(d.get("frame_ms_avg", 0), 3), d.get("frame_ms_p95", ""), d.get("frame_ms_p99", ""), d.get("frame_ms_max", ""),
                       round(before, 2), round(w.peak, 2), rc, json.dumps({k: extra[k] for k in ("rounds", "surface", "live_particles", "decals", "casings", "running") if k in extra}), w.why]
                tsv.write("\t".join(str(x) for x in row) + "\n"); tsv.flush()
                say(job["label"], Path(job["scene"]).stem, job["mode"], state, d.get("frame_ms_avg"), d.get("frame_ms_p95"), "load", round(before, 2), w.why)
                # The pictures weigh a lot and the numbers are what's kept.
                for png in dest.glob("*.png"):
                    png.unlink()
    finally:
        tsv.close()
        shutil.rmtree(work, ignore_errors=True)
        summarize(out)


def summarize(out):
    groups = {}
    for line in (out / "windows.tsv").read_text().splitlines():
        f = line.split("\t")
        if f[5] != "clean":
            continue
        groups.setdefault((f[0], f[2], f[3]), []).append((float(f[9]), float(f[10]), f[11], float(f[13]), float(f[14])))
    res = {}
    for (label, scene, mode), rows in groups.items():
        a = [r[0] for r in rows]; p = [r[1] for r in rows]
        res.setdefault(f"{scene}{'/' + mode if mode else ''}", {})[label] = {
            "windows": len(rows), "avg_median": round(statistics.median(a), 3), "avg_min": min(a), "avg_max": max(a),
            "p95_median": round(statistics.median(p), 3), "p95_min": min(p), "p95_max": max(p)}
    (out / "summary.json").write_text(json.dumps(res, indent=1) + "\n")


if __name__ == "__main__":
    main()
