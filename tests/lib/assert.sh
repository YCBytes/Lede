#!/usr/bin/env bash
# Tiny assertion helpers for shell tests.
# Source this in test scripts: . "$(dirname "$0")/lib/assert.sh"

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc"
    echo "    needle:   $(printf '%q' "$needle")"
    echo "    haystack: $(printf '%q' "${haystack:0:200}")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc (forbidden substring present)"
    echo "    needle: $(printf '%q' "$needle")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_exit() {
  local desc="$1" expected_code="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local actual_code=$?
  set -e
  if [ "$expected_code" = "$actual_code" ]; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc (expected exit $expected_code, got $actual_code)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

summary() {
  echo ""
  echo "Total: $((PASS_COUNT + FAIL_COUNT)) | Passed: $PASS_COUNT | Failed: $FAIL_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
}
