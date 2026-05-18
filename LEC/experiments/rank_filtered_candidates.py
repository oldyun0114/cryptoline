#!/usr/bin/env python3
import argparse
import csv
import re
from difflib import SequenceMatcher

def width_of_type(t):
    if t == "bit":
        return 1
    m = re.search(r"(\\d+)", t or "")
    return int(m.group(1)) if m else 0

def memory_like(x):
    x = (x or "").lower()
    return x.startswith("l0x") or "mem" in x or "stack" in x

def name_similarity(a, b):
    return SequenceMatcher(None, a or "", b or "").ratio()

def score_pair(row, left_count, right_count):
    typ = row.get("type", "")
    v1 = row.get("var_file1", "")
    v2 = row.get("var_file2", "")
    score = 100.0

    score += min(width_of_type(typ), 256) / 8.0

    if left_count == 1 and right_count == 1:
        score += 50.0
    else:
        score -= 10.0 * (left_count + right_count - 2)

    if row.get("same_name", "").lower() == "true":
        score += 20.0

    score += 20.0 * name_similarity(v1, v2)

    if memory_like(v1):
        score -= 8.0
    if memory_like(v2):
        score -= 8.0

    return score

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv_file")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    with open(args.csv_file, newline="") as f:
        rows = list(csv.DictReader(f))

    groups = {}
    for r in rows:
        key = (r.get("type", ""), r.get("hash", ""))
        g = groups.setdefault(key, {"rows": [], "left": set(), "right": set()})
        g["rows"].append(r)
        g["left"].add(r.get("var_file1", ""))
        g["right"].add(r.get("var_file2", ""))

    out = args.out
    if out is None:
        base = args.csv_file[:-4] if args.csv_file.endswith(".csv") else args.csv_file
        out = base + "_groups_ranked.csv"

    ranked = []
    for i, ((typ, h), g) in enumerate(groups.items()):
        lc = len(g["left"])
        rc = len(g["right"])
        best = max(g["rows"], key=lambda r: score_pair(r, lc, rc))
        score = score_pair(best, lc, rc)

        ranked.append({
            "group_id": i,
            "type": typ,
            "hash": h,
            "left_count": lc,
            "right_count": rc,
            "pair_count": lc * rc,
            "one_to_one": str(lc == 1 and rc == 1).lower(),
            "score": "%.2f" % score,
            "best_file1": best.get("var_file1", ""),
            "best_file2": best.get("var_file2", ""),
            "left_vars": ";".join(sorted(g["left"])),
            "right_vars": ";".join(sorted(g["right"])),
        })

    ranked.sort(key=lambda r: float(r["score"]), reverse=True)

    with open(out, "w", newline="") as f:
        cols = [
            "group_id", "type", "hash", "left_count", "right_count",
            "pair_count", "one_to_one", "score", "best_file1",
            "best_file2", "left_vars", "right_vars"
        ]
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(ranked)

    one = sum(1 for r in ranked if r["one_to_one"] == "true")
    print("input:", args.csv_file)
    print("groups:", len(ranked))
    print("one_to_one groups:", one)
    print("ambiguous groups:", len(ranked) - one)
    print("written:", out)

if __name__ == "__main__":
    main()
