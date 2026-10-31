"""Poll an existing Meshy task (no new task, no new credits) for up to ~150 s; download when done.

    python3 tools/meshy/meshy_resume.py <kind> <task_id> <name> <out_dir>

Use this after meshy_job.py --spend when the job's own polling got cut off (for example the device
shell kills background processes when a call ends). Run it again until it prints DONE or ERROR.
Never re-create a task to "retry": that spends credits again.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy_job as M  # noqa: E402

kind, task_id, name, out_dir = sys.argv[1:5]
k = M.key()
t0 = time.time()
while True:
    t = M.call("GET", f"/{kind}/{task_id}", None, k)
    st = t.get("status")
    print(f"{st} {t.get('progress', 0)}%", flush=True)
    if st in ("SUCCEEDED", "FAILED", "CANCELED") or time.time() - t0 > 150:
        break
    time.sleep(12)
if st == "SUCCEEDED":
    os.makedirs(out_dir, exist_ok=True)
    files = {}
    for fmt, url in (t.get("model_urls") or {}).items():
        if url and fmt in ("glb", "fbx"):
            files[fmt] = M.fetch(url, os.path.join(out_dir, f"{name}.{fmt}"))
    tex = t.get("texture_urls") or {}
    if isinstance(tex, list):
        tex = tex[0] if tex else {}
    for n, url in tex.items():
        if url:
            files[n] = M.fetch(url, os.path.join(out_dir, f"{name}_{n}.png"))
    if t.get("thumbnail_url"):
        files["thumbnail"] = M.fetch(t["thumbnail_url"], os.path.join(out_dir, f"{name}_thumb.png"))
    log = {"name": name, "kind": kind, "task_id": task_id, "status": st,
           "consumed_credits": t.get("consumed_credits"), "files": files, "finished_at": t.get("finished_at")}
    lp = os.path.join(out_dir, "meshy-log.json")
    hist = json.load(open(lp)) if os.path.exists(lp) else []
    hist.append(log)
    json.dump(hist, open(lp, "w"), indent=1)
    print("DONE", json.dumps({"credits": t.get("consumed_credits"), "files": files}))
elif st in ("FAILED", "CANCELED"):
    print("ERROR", t.get("task_error"))
