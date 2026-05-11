#!/usr/bin/env python3
import csv
import glob
import os
from collections import defaultdict

OUTDIR = "LEC/experiments/results/trials_filtered_short"
SUMMARY = os.path.join(OUTDIR, "group_quality_summary.csv")

def analyze_filtered_csv(path):
    groups = defaultdict(lambda: {"left": set(), "right": set(), "type": ""})

    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = (row["type"], row["hash"])
            groups[key]["type"] = row["type"]
            groups[key]["left"].add(row["var_file1"])
            groups[key]["right"].add(row["var_file2"])

    total_pairs = 0
    one_to_one_groups = 0
    one_to_one_pairs = 0
    ambiguous_groups = 0
    ambiguous_pairs = 0
    max_group_pairs = 0
    max_group_left = 0
    max_group_right = 0

    group_rows = []

    for (typ, h), g in groups.items():
        l = len(g["left"])
        r = len(g["right"])
        pairs = l * r
        total_pairs += pairs

        if l == 1 and r == 1:
            one_to_one_groups += 1
            one_to_one_pairs += 1
            kind = "one_to_one"
        else:
            ambiguous_groups += 1
            ambiguous_pairs += pairs
            kind = "ambiguous"

        max_group_pairs = max(max_group_pairs, pairs)
        max_group_left = max(max_group_left, l)
        max_group_right = max(max_group_right, r)

        group_rows.append({
            "kind": kind,
            "type": typ,
            "hash": h,
            "pair_count": pairs,
            "left_count": l,
            "right_count": r,
            "left_vars": " ".join(sorted(g["left"])),
            "right_vars": " ".join(sorted(g["right"])),
        })

    group_rows.sort(key=lambda x: (-x["pair_count"], x["kind"], x["type"], x["hash"]))

    grouped_out = path.replace(".csv", "_quality_groups.csv")
    with open(grouped_out, "w", newline="") as f:
        fieldnames = [
            "kind",
            "type",
            "hash",
            "pair_count",
            "left_count",
            "right_count",
            "left_vars",
            "right_vars",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(group_rows)

    return {
        "case_file": os.path.basename(path),
        "filtered_pairs": total_pairs,
        "signature_groups": len(groups),
        "one_to_one_groups": one_to_one_groups,
        "one_to_one_pairs": one_to_one_pairs,
        "ambiguous_groups": ambiguous_groups,
        "ambiguous_pairs": ambiguous_pairs,
        "max_group_pairs": max_group_pairs,
        "max_group_left": max_group_left,
        "max_group_right": max_group_right,
        "grouped_output": grouped_out,
    }

rows = []

for path in sorted(glob.glob(os.path.join(OUTDIR, "*_trials1000_filtered.csv"))):
    rows.append(analyze_filtered_csv(path))

with open(SUMMARY, "w", newline="") as f:
    fieldnames = [
        "case_file",
        "filtered_pairs",
        "signature_groups",
        "one_to_one_groups",
        "one_to_one_pairs",
        "ambiguous_groups",
        "ambiguous_pairs",
        "max_group_pairs",
        "max_group_left",
        "max_group_right",
        "grouped_output",
    ]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {SUMMARY}")
print()
with open(SUMMARY) as f:
    print(f.read())
