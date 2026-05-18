#!/usr/bin/env bash
set -uo pipefail

mkdir -p LEC/experiments/results

TOOL="./_build/default/cv_cec.exe"

KECCAK_FILE1="examples/openssl/keccak/KeccakP-1600-reference_KeccakP1600_Permute_24rounds.cl"
KECCAK_FILE2="examples/openssl/keccak/cc/KeccakF1600.cl"

SHA256_FILE1="examples/openssl/sha256/sha256_block_data_order-aarch64.cl"
SHA256_FILE2="examples/openssl/sha256/armv4/sha256_block_data_order.cl"

run_case() {
  local name="$1"
  local trials="$2"
  local file1="$3"
  local file2="$4"

  local csv="LEC/experiments/results/${name}_cvcec_trials${trials}.csv"
  local log="LEC/experiments/results/${name}_cvcec_trials${trials}.log"

  echo "============================================================"
  echo "Running ${name}, trials=${trials}"
  echo "File 1: ${file1}"
  echo "File 2: ${file2}"
  echo "CSV: ${csv}"
  echo "LOG: ${log}"
  echo "Start time: $(date)"
  echo "============================================================"

  /usr/bin/time -p "${TOOL}" \
    -lec-discover \
    -lec-trials "${trials}" \
    -lec-out "${csv}" \
    "${file1}" \
    "${file2}" \
    2>&1 | tee "${log}"

  local status=${PIPESTATUS[0]}

  echo "============================================================"
  echo "Finished ${name}, trials=${trials}, status=${status}"
  echo "End time: $(date)"
  echo "============================================================"
  echo ""

  return ${status}
}

echo "Large-trial LEC random simulation experiments"
echo "Started at: $(date)"
echo ""

run_case "keccak_ref_cc" 1000  "${KECCAK_FILE1}" "${KECCAK_FILE2}"
run_case "keccak_ref_cc" 10000 "${KECCAK_FILE1}" "${KECCAK_FILE2}"

run_case "sha256_aarch64_armv4" 1000  "${SHA256_FILE1}" "${SHA256_FILE2}"
run_case "sha256_aarch64_armv4" 10000 "${SHA256_FILE1}" "${SHA256_FILE2}"

echo "All large-trial experiments finished at: $(date)"
