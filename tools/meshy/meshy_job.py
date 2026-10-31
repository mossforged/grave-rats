#!/usr/bin/env python3
"""Run one Meshy job: create the task, poll, download, log. Standard library only.

    python3 tools/meshy/meshy_job.py tools/meshy/jobs/stalker.json            # dry run (default)
    python3 tools/meshy/meshy_job.py tools/meshy/jobs/stalker.json --spend    # real run

Spending rule: a real run spends Meshy credits. Run with --spend only after John has OK'd that job
and its estimate. The key is read from the env var MESHY_API_KEY, or from the file named by
MESHY_KEY_FILE. It is never printed, logged or written anywhere. Keep the key out of this repo.

The job file (JSON): {"name", "kind": "multi-image-to-3d"|"image-to-3d", "images": [paths, front
first], "out_dir", "estimate_credits", "params": {Meshy body params}}. The images are sent as data
URIs. The output goes to out_dir: <name>.glb, thumbnails, textures, and meshy-log.json (appended).
"""
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://api.meshy.ai/openapi/v1"
POLL_S = 12
TIMEOUT_S = 30 * 60


def key():
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if not k and os.environ.get("MESHY_KEY_FILE"):
        with open(os.path.expanduser(os.environ["MESHY_KEY_FILE"])) as f:
            k = f.read().strip()
    if not k:
        sys.exit("No key: set MESHY_API_KEY or MESHY_KEY_FILE (never commit the key).")
    return k


def call(method, path, body=None, k=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {k}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")[:400]
        hint = {401: "key rejected", 402: "no credits or plan without API access: stop and tell John",
                422: "pose or input problem", 429: "rate limited"}.get(e.code, "")
        sys.exit(f"HTTP {e.code} {hint}: {msg}")


def data_uri(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()


def fetch(url, dest):
    with urllib.request.urlopen(url, timeout=120) as r, open(dest, "wb") as f:
        f.write(r.read())
    return os.path.getsize(dest)


def main():
    job_path = sys.argv[1]
    spend = "--spend" in sys.argv
    job = json.load(open(job_path))
    base = os.path.dirname(os.path.abspath(job_path))
    root = os.path.abspath(os.path.join(base, "..", "..", ".."))  # repo root from tools/meshy/jobs
    images = [os.path.join(root, p) for p in job["images"]]
    for p in images:
        if not os.path.exists(p):
            sys.exit(f"missing input: {p}")
        if os.path.getsize(p) > 20 * 1024 * 1024:
            sys.exit(f"over 20 MB: {p}")
    kind = job["kind"]
    body = dict(job.get("params", {}))
    if kind == "multi-image-to-3d":
        if not 1 <= len(images) <= 4:
            sys.exit("multi-image takes 1 to 4 images, front first")
        body["image_urls"] = [data_uri(p) for p in images]
    else:
        body["image_url"] = data_uri(images[0])
    out_dir = os.path.join(root, job["out_dir"])
    print(f"job {job['name']}: {kind}, {len(images)} image(s), front = {os.path.basename(images[0])}")
    print("params:", json.dumps(job.get("params", {})))
    print(f"estimate: {job.get('estimate_credits', '?')} credits; output -> {job['out_dir']}")
    if not spend:
        print("dry run only: nothing sent. Re-run with --spend after John's OK.")
        return
    k = key()
    os.makedirs(out_dir, exist_ok=True)
    task_id = call("POST", f"/{kind}", body, k)["result"]
    print("task", task_id, "created")
    t0 = time.time()
    while True:
        t = call("GET", f"/{kind}/{task_id}", None, k)
        st = t.get("status")
        print(f"  {st} {t.get('progress', 0)}%", flush=True)
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        if time.time() - t0 > TIMEOUT_S:
            sys.exit(f"timed out; task {task_id} still {st}. Do not re-create it: poll it later.")
        time.sleep(POLL_S)
    log = {"name": job["name"], "kind": kind, "task_id": task_id, "status": st,
           "consumed_credits": t.get("consumed_credits"), "params": job.get("params", {}),
           "inputs": job["images"], "finished_at": t.get("finished_at"), "files": {}}
    if st == "SUCCEEDED":
        for fmt, url in (t.get("model_urls") or {}).items():
            if url and fmt in ("glb", "fbx"):
                dest = os.path.join(out_dir, f"{job['name']}.{fmt}")
                log["files"][fmt] = [os.path.relpath(dest, root), fetch(url, dest)]
        for name, url in (t.get("texture_urls") or [{}])[0].items() if isinstance(t.get("texture_urls"), list) \
                else (t.get("texture_urls") or {}).items():
            if url:
                dest = os.path.join(out_dir, f"{job['name']}_{name}.png")
                log["files"][name] = [os.path.relpath(dest, root), fetch(url, dest)]
        if t.get("thumbnail_url"):
            dest = os.path.join(out_dir, f"{job['name']}_thumb.png")
            log["files"]["thumbnail"] = [os.path.relpath(dest, root), fetch(t["thumbnail_url"], dest)]
    else:
        log["error"] = t.get("task_error")
    lp = os.path.join(out_dir, "meshy-log.json")
    hist = json.load(open(lp)) if os.path.exists(lp) else []
    hist.append(log)
    json.dump(hist, open(lp, "w"), indent=1)
    print(f"{st}: {job['name']} task {task_id}, {log['consumed_credits']} credits, "
          f"{len(log['files'])} files -> {job['out_dir']}")


if __name__ == "__main__":
    main()
