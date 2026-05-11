#!/usr/bin/env python3
import csv
import glob
import os
import re

OUTDIR = "LEC/experiments/results/trials_filtered_short"
SUMMARY = os.path.join(OUTDIR, "summary_filtered_short.csv")

def grep_value(path, pattern):
    rgx = re.compile(pattern)
    last = ""
    with open(path, errors="ignore") as f:
        for line in f:
            m = rgx.search(line)
            if m:
                last = m.group(1)
    return last

rows = []

for log in sorted(glob.glob(os.path.join(OUTDIR, "*.log"))):
    base = os.path.basename(log).replace(".log", "")
    m = re.match(r"(.+)_trials(\d+)$", base)
    if not m:
        continue

    case = m.group(1)
    trials = int(m.group(2))

    rows.append({
        "case": case,
        "trials": trials,
        "raw_candidate_pairs": grep_value(log, r"Candidate equal variable pairs:\s+(\d+)"),
        "filtered_candidate_pairs": grep_value(log, r"Filtered candidate equal variable pairs:\s+(\d+)"),
        "raw_signature_groups": grep_value(log, r"Signature groups:\s+(\d+)"),
        "filtered_signature_groups": grep_value(log, r"Filtered signature groups:\s+(\d+)"),
        "any_const_pairs": grep_value(log, r"Candidate pairs involving any constant-like variable:\s+(\d+)"),
        "both_const_pairs": grep_value(log, r"Candidate pairs where both sides are constant-like:\s+(\d+)"),
        "input_pairs": grep_value(log, r"Candidate pairs involving input variables:\s+(\d+)"),
        "same_name_pairs": grep_value(log, r"Candidate pairs with same variable name:\s+(\d+)"),
        "random_input_changed": grep_value(log, r"Random input changed across trials:\s+(true|false)"),
        "real_time": grep_value(log, r"^real\s+([0-9.]+)"),
        "exit_status": grep_value(log, r"EXIT_STATUS=(\d+)"),
    })

rows.sort(key=lambda r: (r["case"], r["trials"]))

with open(SUMMARY, "w", newline="") as f:
    fieldnames = [
        "case",
        "trials",
        "raw_candidate_pairs",
        "filtered_candidate_pairs",
        "raw_signature_groups",
        "filtered_signature_groups",
        "any_const_pairs",
        "both_const_pairs",
        "input_pairs",
        "same_name_pairs",
        "random_input_changed",
        "real_time",
        "exit_status",
    ]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {SUMMARY}")
print()
with open(SUMMARY) as f:
    print(f.read())
