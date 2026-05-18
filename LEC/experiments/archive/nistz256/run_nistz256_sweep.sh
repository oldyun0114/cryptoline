#!/usr/bin/env bash
set -u

TOOL="./_build/default/cv_cec.exe"
OUTDIR="LEC/experiments/results/nistz256_sweep"
mkdir -p "$OUTDIR"

run_pair () {
  local name="$1"
  local f1="$2"
  local f2="$3"

  echo "============================================================"
  echo "NIST case: $name"
  echo "file1: $f1"
  echo "file2: $f2"
  echo "============================================================"

  if [[ ! -f "$f1" ]]; then
    echo "[SKIP] missing file1: $f1" | tee "$OUTDIR/${name}.log"
    return
  fi

  if [[ ! -f "$f2" ]]; then
    echo "[SKIP] missing file2: $f2" | tee "$OUTDIR/${name}.log"
    return
  fi

  /usr/bin/time -p \
    timeout 10m \
    "$TOOL" \
      -lec-discover \
      -lec-trials 10 \
      -lec-out "$OUTDIR/${name}_trials10.csv" \
      "$f1" \
      "$f2" \
    2>&1 | tee "$OUTDIR/${name}_trials10.log"

  status=${PIPESTATUS[0]}
  echo "EXIT_STATUS=$status" | tee -a "$OUTDIR/${name}_trials10.log"
}

run_pair "nistz256_add_armv8_x86" \
  "examples/openssl/ecp_nistz256/armv8/ecp_nistz256_add_armv8.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_add.cl"

run_pair "nistz256_sub_armv8_x86" \
  "examples/openssl/ecp_nistz256/armv8/ecp_nistz256_sub_armv8.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_sub.cl"

run_pair "nistz256_mul_mont_armv8_x86" \
  "examples/openssl/ecp_nistz256/armv8/ecp_nistz256_mul_mont_armv8.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_mul_mont.cl"

run_pair "nistz256_sqr_mont_armv8_x86" \
  "examples/openssl/ecp_nistz256/armv8/ecp_nistz256_sqr_mont_armv8.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_sqr_mont.cl"
