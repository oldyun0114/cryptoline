#!/usr/bin/env python3
import csv
import os
import sys

if len(sys.argv) < 3:
    print("Usage: python3 compare_filtered_sets.py case file10.csv file100.csv file1000.csv")
    sys.exit(1)

case = sys.argv[1]
paths = sys.argv[2:]

def load_pairs(path):
    pairs = set()
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Important:
            # Do NOT compare hash across different trial counts.
            # The hash encodes the whole signature sequence, so it naturally changes
            # when the number of trials changes.
            pairs.add((
                row.get("var_file1", ""),
                row.get("var_file2", ""),
                row.get("type", ""),
            ))
    return pairs

loaded = []
for p in paths:
    pairs = load_pairs(p)
    loaded.append((p, pairs))

print("============================================================")
print(f"CASE: {case}")
print("============================================================")

for p, pairs in loaded:
    print(f"{os.path.basename(p)}")
    print(f"  filtered candidate identities = {len(pairs)}")

print()
print("Consecutive comparison, ignoring signature hash:")

stable_all = True

for (p1, pairs1), (p2, pairs2) in zip(loaded, loaded[1:]):
    removed = pairs1 - pairs2
    added = pairs2 - pairs1

    print(f"{os.path.basename(p1)} -> {os.path.basename(p2)}")
    print(f"  removed candidate identities = {len(removed)}")
    print(f"  added candidate identities   = {len(added)}")

    if removed or added:
        stable_all = False
        print("  RESULT: changed")
    else:
        print("  RESULT: exactly stable")

    print()

print("FINAL:")
if stable_all:
    print("  Candidate identities are stable across these trials.")
else:
    print("  Candidate identities change across these trials.")
