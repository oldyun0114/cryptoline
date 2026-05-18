#!/usr/bin/env python3
import csv
import glob
import os

files = sorted(glob.glob("LEC/experiments/formal_validation/*validation*.csv"))
out = "LEC/experiments/results_summary/formal_validation_summary.csv"
os.makedirs(os.path.dirname(out), exist_ok=True)

rows = []
for f in files:
    with open(f, newline="") as fp:
        data = list(csv.DictReader(fp))
    if not data:
        continue

    ok = sum(1 for r in data if r.get("ok") == "true")
    total = len(data)
    timeout = sum(1 for r in data if r.get("returncode") == "124")
    failed = total - ok - timeout

    seconds = []
    for r in data:
        try:
            seconds.append(float(r.get("seconds", "0")))
        except ValueError:
            pass

    rows.append({
        "file": os.path.basename(f),
        "total": total,
        "ok": ok,
        "timeout": timeout,
        "failed": failed,
        "avg_seconds": "%.2f" % (sum(seconds) / len(seconds) if seconds else 0),
        "max_seconds": "%.2f" % (max(seconds) if seconds else 0),
    })

with open(out, "w", newline="") as fp:
    cols = ["file", "total", "ok", "timeout", "failed", "avg_seconds", "max_seconds"]
    w = csv.DictWriter(fp, fieldnames=cols)
    w.writeheader()
    w.writerows(rows)

print("written:", out)
with open(out) as fp:
    print(fp.read())
