#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
. lib/assert.sh

SCRIPT="../scripts/lib/extract-project-state.sh"

echo "Test: sample-project snapshot includes deps, configs, source files"
output=$(bash "$SCRIPT" fixtures/sample-project)

assert_contains "stack line present" "stack:" "$output"
assert_contains "deps from package.json" "react" "$output"
assert_contains "tailwindcss listed" "tailwindcss" "$output"
assert_contains "tailwind config detected" "tailwind.config.js" "$output"
assert_contains "source file listed" "src/App.jsx" "$output"

echo ""
echo "Test: empty directory produces a partial-state notice"
tmp=$(mktemp -d)
output=$(bash "$SCRIPT" "$tmp")
assert_contains "notes empty/no-manifest case" "no manifest" "$output"
rm -rf "$tmp"

echo ""
echo "Test: output stays under 2 KB for sample-project"
output=$(bash "$SCRIPT" fixtures/sample-project)
size=${#output}
if [ "$size" -le 2048 ]; then
  echo "  PASS: size $size bytes <= 2048"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: size $size bytes > 2048"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

summary
