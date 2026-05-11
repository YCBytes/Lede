#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
. lib/assert.sh

SCRIPT="../scripts/lib/extract-transcript.sh"

echo "Test: todo-app, --start-line 0 extracts all 6 user messages renumbered from U1"
output=$(bash "$SCRIPT" --start-line 0 fixtures/todo-app.jsonl)
line_count=$(echo "$output" | grep -c '^\[U' || true)
assert_eq "extracts 6 user messages" "6" "$line_count"
assert_contains "starts at U1" "[U1] Build a todo app" "$output"
assert_contains "ends at U6 'no auth needed'" "[U6]" "$output"
assert_contains "U6 content" "no auth needed" "$output"
assert_not_contains "drops tool_result echoes" "tool_use_id" "$output"
assert_not_contains "drops /assess invocations" "/assess" "$output"

echo ""
echo "Test: short fixture, --start-line 0 — only the non-/assess messages remain"
output=$(bash "$SCRIPT" --start-line 0 fixtures/short.jsonl)
line_count=$(echo "$output" | grep -c '^\[U' || true)
assert_eq "1 user message kept (hi)" "1" "$line_count"
assert_contains "kept 'hi'" "[U1] hi" "$output"
assert_not_contains "dropped /assess" "/assess" "$output"

echo ""
echo "Test: --start-line N filters earlier user messages and renumbers from U1"
# In todo-app.jsonl, line 3 is the second user message ('use tailwind'). Filter past line 1
# (which is the first user message). Expect 5 messages renumbered starting at U1.
output=$(bash "$SCRIPT" --start-line 1 fixtures/todo-app.jsonl)
line_count=$(echo "$output" | grep -c '^\[U' || true)
assert_eq "5 user messages after dropping the first" "5" "$line_count"
assert_contains "starts at 'use tailwind' as U1" "[U1] use tailwind" "$output"
assert_not_contains "dropped 'Build a todo app'" "Build a todo app" "$output"

echo ""
echo "Test: missing JSONL exits non-zero"
set +e
bash "$SCRIPT" --start-line 0 /nonexistent.jsonl >/dev/null 2>&1
rc=$?
set -e
assert_eq "missing file exits 1" "1" "$rc"

summary
