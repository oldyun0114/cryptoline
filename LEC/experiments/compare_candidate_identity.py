#!/usr/bin/env python3
import csv

files = [
    "LEC/experiments/results/trials_filtered_short/sha256_aarch64_armv4_trials10_filtered.csv",
    "LEC/experiments/results/trials_filtered_short/sha256_aarch64_armv4_trials100_filtered.csv",
    "LEC/experiments/results/trials_filtered_short/sha256_aarch64_armv4_trials1000_filtered.csv",
]

sets = []

for f in files:
    rows = list(csv.DictReader(open(f)))
    s = {(r["var_file1"], r["var_file2"], r["type"]) for r in rows}
    sets.append(s)
    print(f)
    print("  candidate pairs:", len(s))

for i in range(len(files)):
    for j in range(i + 1, len(files)):
        a = sets[i]
        b = sets[j]
        print()
        print(files[i], "vs", files[j])
        print("  common:", len(a & b))
        print("  only first:", len(a - b))
        print("  only second:", len(b - a))

print()
print("common to all:", len(sets[0] & sets[1] & sets[2]))
