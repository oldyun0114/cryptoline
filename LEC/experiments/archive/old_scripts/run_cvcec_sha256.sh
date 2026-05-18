#!/usr/bin/env bash
set -euo pipefail

mkdir -p LEC/experiments/results

FILE1="examples/openssl/sha256/sha256_block_data_order-aarch64.cl"
FILE2="examples/openssl/sha256/armv4/sha256_block_data_order.cl"
TOOL="./_build/default/cv_cec.exe"

for N in 1 10; do
  echo "Running SHA-256 aarch64 vs armv4 with trials=${N}"
  /usr/bin/time -p "$TOOL" \
    -lec-discover \
    -lec-trials "$N" \
    -lec-out "LEC/experiments/results/sha256_aarch64_armv4_cvcec_trials${N}.csv" \
    "$FILE1" \
    "$FILE2" \
    2>&1 | tee "LEC/experiments/results/sha256_aarch64_armv4_cvcec_trials${N}.log"
done
