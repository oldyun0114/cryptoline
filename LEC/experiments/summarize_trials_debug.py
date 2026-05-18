#!/usr/bin/env python3
import csv
import glob
import os
import re

OUTDIR = "LEC/experiments/results/trials_stable_debug"
SUMMARY = os.path.join(OUTDIR, "summary_by_trials.csv")

def grep_value(path, pattern):
    if not os.path.exists(path):
        return ""
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
    csv_path = os.path.join(OUTDIR, f"{case}_trials{trials}.csv")

    p1_vars = grep_value(log, r"Program 1 variables with signatures:\s+(\d+)")
    p2_vars = grep_value(log, r"Program 2 variables with signatures:\s+(\d+)")
    pairs = grep_value(log, r"Candidate equal variable pairs:\s+(\d+)")
    filtered_pairs = grep_value(log, r"Filtered candidate equal variable pairs:\s+(\d+)")
    filtered_groups = grep_value(log, r"Filtered signature groups:\s+(\d+)")
    groups = grep_value(log, r"Signature groups:\s+(\d+)")
    any_const = grep_value(log, r"Candidate pairs involving any constant-like variable:\s+(\d+)")
    both_const = grep_value(log, r"Candidate pairs where both sides are constant-like:\s+(\d+)")
    both_non_const = grep_value(log, r"Candidate pairs where both sides are non-constant:\s+(\d+)")
    any_input = grep_value(log, r"Candidate pairs involving input variables:\s+(\d+)")
    same_name = grep_value(log, r"Candidate pairs with same variable name:\s+(\d+)")
    input_changed = grep_value(log, r"Random input changed across trials:\s+(true|false)")
    real_time = grep_value(log, r"^real\s+([0-9.]+)")
    exit_status = grep_value(log, r"EXIT_STATUS=(\d+)")

    rows.append({
        "case": case,
        "trials": trials,
        "program1_variables": p1_vars,
        "program2_variables": p2_vars,
        "candidate_pairs": pairs,
        "filtered_candidate_pairs": filtered_pairs,
        "signature_groups": groups,
        "filtered_signature_groups": filtered_groups,
        "any_const_pairs": any_const,
        "both_const_pairs": both_const,
        "both_non_const_pairs": both_non_const,
        "input_pairs": any_input,
        "same_name_pairs": same_name,
        "random_input_changed": input_changed,
        "real_time": real_time,
        "exit_status": exit_status,
        "csv": csv_path if os.path.exists(csv_path) else "",
    })

rows.sort(key=lambda r: (r["case"], r["trials"]))

with open(SUMMARY, "w", newline="") as f:
    fieldnames = [
        "case",
        "trials",
        "program1_variables",
        "program2_variables",
        "candidate_pairs",
        "filtered_candidate_pairs",
        "signature_groups",
        "filtered_signature_groups",
        "any_const_pairs",
        "both_const_pairs",
        "both_non_const_pairs",
        "input_pairs",
        "same_name_pairs",
        "random_input_changed",
        "real_time",
        "exit_status",
        "csv",
    ]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {SUMMARY}")
print()
with open(SUMMARY) as f:
    print(f.read())
