#!/usr/bin/env bash
set -euo pipefail

mkdir -p LEC/experiments/results

FILE1="examples/openssl/keccak/KeccakP-1600-reference_KeccakP1600_Permute_24rounds.cl"
FILE2="examples/openssl/keccak/cc/KeccakF1600.cl"
TOOL="./_build/default/cv_cec.exe"

for N in 1 10 100; do
  echo "Running Keccak reference vs cc with trials=${N}"
  /usr/bin/time -p "$TOOL" \
    -lec-discover \
    -lec-trials "$N" \
    -lec-out "LEC/experiments/results/keccak_ref_cc_cvcec_trials${N}.csv" \
    "$FILE1" \
    "$FILE2" \
    2>&1 | tee "LEC/experiments/results/keccak_ref_cc_cvcec_trials${N}.log"
done
