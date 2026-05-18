#!/usr/bin/env bash
set -euo pipefail

TOOL="./_build/default/cv_cec.exe"
OUTDIR="LEC/experiments/results/debug"
mkdir -p "$OUTDIR"

run_case () {
  local name="$1"
  local file1="$2"
  local file2="$3"

  echo "============================================================"
  echo "CASE: $name"
  echo "FILE1: $file1"
  echo "FILE2: $file2"
  echo "============================================================"

  for N in 1 10 100; do
    echo ""
    echo "[RUN] $name trials=$N"

    /usr/bin/time -p "$TOOL" \
      -lec-discover \
      -lec-trials "$N" \
      -lec-out "$OUTDIR/${name}_trials${N}.csv" \
      "$file1" \
      "$file2" \
      2>&1 | tee "$OUTDIR/${name}_trials${N}.log"
  done
}

# 1. hash / permutation 類
run_case "keccak_ref_cc" \
  "examples/openssl/keccak/KeccakP-1600-reference_KeccakP1600_Permute_24rounds.cl" \
  "examples/openssl/keccak/cc/KeccakF1600.cl"

# 2. hash 類
run_case "sha256_aarch64_armv4" \
  "examples/openssl/sha256/sha256_block_data_order-aarch64.cl" \
  "examples/openssl/sha256/armv4/sha256_block_data_order.cl"

# 3. NIST P-256 Montgomery multiplication，算術類
run_case "nistz256_mul_mont_armv8_x86" \
  "examples/openssl/ecp_nistz256/armv8/ecp_nistz256_mul_mont_armv8.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_mul_mont.cl"

# 4. X25519 算術類：add/sub/mul/sqr
run_case "x25519_fe64_add_armv8_x86" \
  "examples/openssl/x25519/armv8/x25519_fe64_add.cl" \
  "examples/openssl/x25519/x86_64/x25519_fe64_add.cl"

run_case "x25519_fe64_sub_armv8_x86" \
  "examples/openssl/x25519/armv8/x25519_fe64_sub.cl" \
  "examples/openssl/x25519/x86_64/x25519_fe64_sub.cl"

run_case "x25519_fe64_mul_armv8_x86" \
  "examples/openssl/x25519/armv8/x25519_fe64_mul.cl" \
  "examples/openssl/x25519/x86_64/x25519_fe64_mul.cl"

run_case "x25519_fe64_sqr_armv8_x86" \
  "examples/openssl/x25519/armv8/x25519_fe64_sqr.cl" \
  "examples/openssl/x25519/x86_64/x25519_fe64_sqr.cl"
