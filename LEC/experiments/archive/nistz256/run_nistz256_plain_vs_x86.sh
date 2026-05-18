#!/usr/bin/env bash
set -u

TOOL="./_build/default/cv_cec.exe"
OUTDIR="LEC/experiments/results/nistz256_plain_vs_x86"
mkdir -p "$OUTDIR"

run_pair () {
  local name="$1"
  local f1="$2"
  local f2="$3"

  echo "============================================================"
  echo "CASE: $name"
  echo "FILE1: $f1"
  echo "FILE2: $f2"
  echo "============================================================"

  if [[ ! -f "$f1" ]]; then
    echo "[SKIP] missing file1: $f1" | tee "$OUTDIR/${name}_trials10.log"
    return
  fi

  if [[ ! -f "$f2" ]]; then
    echo "[SKIP] missing file2: $f2" | tee "$OUTDIR/${name}_trials10.log"
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

run_pair "plain_vs_x86_add" \
  "examples/openssl/ecp_nistz256/ecp_nistz256_add.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_add.cl"

run_pair "plain_vs_x86_sub" \
  "examples/openssl/ecp_nistz256/ecp_nistz256_sub.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_sub.cl"

run_pair "plain_vs_x86_mul_mont" \
  "examples/openssl/ecp_nistz256/ecp_nistz256_mul_mont.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_mul_mont.cl"

run_pair "plain_vs_x86_sqr_mont" \
  "examples/openssl/ecp_nistz256/ecp_nistz256_sqr_mont.cl" \
  "examples/openssl/ecp_nistz256/x86_64/ecp_nistz256_sqr_mont.cl"
