#!/usr/bin/env bash
set -u

for OUTDIR in \
  "LEC/experiments/results/nistz256_plain_vs_x86" \
  "LEC/experiments/results/nistz256_x86_variants" \
  "LEC/experiments/results/nistz256_extra"
do
  [[ -d "$OUTDIR" ]] || continue

  SUMMARY="$OUTDIR/summary.csv"
  echo "case,exit_status,candidate_pairs,filtered_candidate_pairs,random_input_changed,error_hint" > "$SUMMARY"

  for log in "$OUTDIR"/*_trials10.log; do
    [[ -f "$log" ]] || continue

    base=$(basename "$log" _trials10.log)

    status=$(grep "EXIT_STATUS=" "$log" | tail -1 | sed 's/EXIT_STATUS=//')
    cand=$(grep "Candidate equal variable pairs:" "$log" | tail -1 | awk '{print $NF}')
    filtered=$(grep "Filtered candidate equal variable pairs:" "$log" | tail -1 | awk '{print $NF}')
    changed=$(grep "Random input changed across trials:" "$log" | tail -1 | awk '{print $NF}')

    if grep -q "Input number mismatch" "$log"; then
      hint="Input number mismatch"
    elif grep -q "Input type mismatch" "$log"; then
      hint="Input type mismatch"
    elif grep -q "Exception" "$log"; then
      hint="Exception"
    elif grep -q "Fatal" "$log"; then
      hint="Fatal"
    elif grep -q "Error" "$log"; then
      hint="Error"
    else
      hint=""
    fi

    echo "$base,$status,$cand,$filtered,$changed,$hint" >> "$SUMMARY"
  done

  echo "============================================================"
  echo "$SUMMARY"
  column -s, -t "$SUMMARY"
done
