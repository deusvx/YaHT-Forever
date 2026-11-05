#!/usr/bin/env bash
# Runs every scenario against a fake WoW API. Needs: pip install lupa
# Usage: tests/run_tests.sh   (from the repository root)
set -e
cd "$(dirname "$0")"
pass=0; fail=0
for sc in $(ls scenario[0-9]*.lua | sort -V); do
  cp "$sc" scenario.lua
  for mode in "" x; do   # "" = combat log allowed, x = blocked (WoW Forever)
    out=$(python3 -I harness.py .. $mode 2>&1 || true)
    if echo "$out" | grep -qE "^OK[0-9]*$" && ! echo "$out" | grep -qE "Error|error in"; then
      pass=$((pass+1))
    else
      fail=$((fail+1)); echo "FAIL: $sc ${mode:-cleu}"; echo "$out" | tail -5
    fi
  done
done
rm -f scenario.lua
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
