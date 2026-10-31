#!/usr/bin/env python3
"""T017: peak and RMS by segment of the recorded sequence, with and without the master limiter.
    t017_levels.py limited.wav open.wav hot.wav segments.json out.json
"""
import json
import sys
import wave

import numpy as np


def load(path):
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())
        channels = w.getnchannels()
    return np.frombuffer(raw, "<i2").reshape(-1, channels).astype(np.float64) / 32768.0, rate


def db(x):
    return round(float(20.0 * np.log10(max(x, 1e-6))), 1)


def measure(x):
    return {"peak_dbfs": db(np.max(np.abs(x))), "rms_dbfs": db(np.sqrt(np.mean(x ** 2))),
            "full_scale_samples": int(np.sum(np.abs(x) >= 0.999))}


def main():
    limited, rate = load(sys.argv[1])
    opened, _ = load(sys.argv[2])
    hot, _ = load(sys.argv[3])
    rows = []
    for s in json.load(open(sys.argv[4])):
        a, b = int(s["from"] * rate), int(s["to"] * rate)
        rows.append({"segment": s["name"], "from_s": s["from"], "to_s": s["to"], "with_limiter": measure(limited[a:b]),
                "without_limiter": measure(opened[a:b]), "limiter_12db_hot": measure(hot[a:b])})
    out = {"sample_rate": rate, "seconds": round(len(limited) / rate, 2), "segments": rows,
            "whole_with_limiter": measure(limited), "whole_without_limiter": measure(opened), "whole_limiter_12db_hot": measure(hot)}
    json.dump(out, open(sys.argv[5], "w"), indent=2)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
