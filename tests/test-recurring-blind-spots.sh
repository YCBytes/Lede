#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
. lib/assert.sh

SCRIPT="../scripts/lib/recurring-blind-spots.sh"

echo "Test: tech preference appears in 3 of 3, should be flagged"
output=$(bash "$SCRIPT" fixtures/reports)
assert_contains "RECURRING BLIND SPOTS header" "RECURRING BLIND SPOTS" "$output"
assert_contains "tech preference flagged" "tech preference" "$output"
assert_contains "shows count 3 of 3" "3 of 3" "$output"

echo ""
echo "Test: scope exclusion appears in only 1, should not be flagged"
assert_not_contains "scope exclusion not flagged" "scope exclusion" "$output"

echo ""
echo "Test: empty directory yields empty output"
tmp=$(mktemp -d)
output=$(bash "$SCRIPT" "$tmp")
assert_eq "empty directory yields empty output" "" "$output"
rm -rf "$tmp"

echo ""
echo "Test: missing directory yields empty output (no crash)"
output=$(bash "$SCRIPT" /nonexistent-path-12345 2>/dev/null || echo "")
assert_eq "missing dir yields empty output" "" "$output"

summary
