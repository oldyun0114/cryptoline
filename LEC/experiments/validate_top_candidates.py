#!/usr/bin/env python3
import argparse
import csv
import os
import shlex
import subprocess
import time

def is_ok(text):
    return "Final result" in text and "[OK]" in text

def safe_name(s):
    out = []
    for c in s:
        if c.isalnum() or c in "._-":
            out.append(c)
        else:
            out.append("_")
    return "".join(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", required=True)
    ap.add_argument("--file1", required=True)
    ap.add_argument("--file2", required=True)
    ap.add_argument("--cvcec", default="./_build/default/cv_cec.exe")
    ap.add_argument("--abc", default=None)
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-ambiguous", action="store_true")
    args = ap.parse_args()

    with open(args.groups, newline="") as f:
        rows = list(csv.DictReader(f))

    if not args.allow_ambiguous:
        rows = [r for r in rows if r.get("one_to_one") == "true"]

    rows = rows[:args.top]

    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    logdir = args.out + ".logs"
    os.makedirs(logdir, exist_ok=True)

    results = []

    for idx, r in enumerate(rows, 1):
        v1 = r["best_file1"]
        v2 = r["best_file2"]
        log = os.path.join(logdir, "%03d_%s_VS_%s.log" % (idx, safe_name(v1), safe_name(v2)))

        cmd = [args.cvcec]
        if args.abc:
            cmd += ["-abc", args.abc]
        cmd += [
            "-ov1", v1,
            "-ov2", v2,
            args.file1,
            args.file2,
        ]

        print("[%d/%d] validating %s <-> %s" % (idx, len(rows), v1, v2))

        t0 = time.time()
        p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        dt = time.time() - t0

        with open(log, "w") as lf:
            lf.write("COMMAND: " + " ".join(shlex.quote(x) for x in cmd) + "\\n\\n")
            lf.write(p.stdout)

        ok = is_ok(p.stdout)

        results.append({
            "rank": idx,
            "group_id": r.get("group_id", ""),
            "var_file1": v1,
            "var_file2": v2,
            "type": r.get("type", ""),
            "score": r.get("score", ""),
            "returncode": p.returncode,
            "ok": str(ok).lower(),
            "seconds": "%.2f" % dt,
            "log": log,
        })

    with open(args.out, "w", newline="") as f:
        cols = [
            "rank", "group_id", "var_file1", "var_file2",
            "type", "score", "returncode", "ok", "seconds", "log"
        ]
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(results)

    print("written:", args.out)
    print("validated OK:", sum(1 for r in results if r["ok"] == "true"), "/", len(results))

if __name__ == "__main__":
    main()
