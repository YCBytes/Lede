#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

ANY_FAIL=0
for t in test-*.sh; do
  echo ""
  echo "=== $t ==="
  if bash "$t"; then
    :
  else
    ANY_FAIL=1
  fi
done

echo ""
if [ "$ANY_FAIL" = 0 ]; then
  echo "ALL SUITES PASSED"
else
  echo "ONE OR MORE SUITES FAILED"
  exit 1
fi
