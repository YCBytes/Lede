#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
. lib/assert.sh

SCRIPT="../scripts/lede.sh"

echo "Test: happy path with todo-app fixture and sample-project state"
output=$(bash "$SCRIPT" --jsonl fixtures/todo-app.jsonl --project fixtures/sample-project)
assert_contains "bundle header" "=== LEDE INPUT BUNDLE ===" "$output"
assert_contains "transcript section" "=== USER MESSAGES ===" "$output"
assert_contains "action log section" "=== ACTION LOG ===" "$output"
assert_contains "project state section" "=== PROJECT STATE AT /assess ===" "$output"
assert_contains "first user message" "Build a todo app" "$output"
assert_contains "react in deps" "react" "$output"
assert_not_contains "no abort" "LEDE_ABORT:" "$output"

# Project state header should appear exactly once (the bundle wraps it; the extractor doesn't add one).
ps_header_count=$(echo "$output" | grep -c "=== PROJECT STATE AT /assess ===" || true)
assert_eq "PROJECT STATE header appears exactly once" "1" "$ps_header_count"

echo ""
echo "Test: short fixture yields LEDE_ABORT for too-few messages"
output=$(bash "$SCRIPT" --jsonl fixtures/short.jsonl --project fixtures/sample-project)
assert_contains "abort header" "LEDE_ABORT:" "$output"
assert_contains "abort reason" "Not enough" "$output"

echo ""
echo "Test: missing JSONL yields LEDE_ABORT"
output=$(bash "$SCRIPT" --jsonl /nonexistent.jsonl --project fixtures/sample-project 2>/dev/null || true)
assert_contains "abort on missing JSONL" "LEDE_ABORT:" "$output"

echo ""
echo "Test: --override-last 4 limits to last 4 user messages, both sections sliced"
output=$(bash "$SCRIPT" --jsonl fixtures/todo-app.jsonl --project fixtures/sample-project --override-last 4)
u_count=$(echo "$output" | grep -c '^\[U' || true)
assert_eq "exactly 4 [U] lines (transcript section only)" "4" "$u_count"
assert_contains "starts at 'mobile-first' as U1" "[U1] make it mobile-first" "$output"
assert_not_contains "dropped 'use tailwind' from transcript" "use tailwind" "$output"

echo ""
echo "Test: --override-from 'mobile' anchors at first matching message and slices action log too"
output=$(bash "$SCRIPT" --jsonl fixtures/todo-app.jsonl --project fixtures/sample-project --override-from "mobile")
assert_contains "starts at 'mobile-first' as U1" "[U1] make it mobile-first" "$output"
assert_not_contains "dropped 'use tailwind' from both sections" "use tailwind" "$output"
assert_not_contains "dropped tailwindcss install" "npm install tailwindcss" "$output"
assert_contains "kept later edit" "Edit src/App.jsx" "$output"

echo ""
echo "Test: --override-from with no match yields LEDE_ABORT and lists recent messages"
output=$(bash "$SCRIPT" --jsonl fixtures/todo-app.jsonl --project fixtures/sample-project --override-from "nonexistent-phrase-xyz" 2>/dev/null || true)
assert_contains "abort on no match" "LEDE_ABORT:" "$output"
assert_contains "lists recent for picking anchor" "Recent messages:" "$output"

echo ""
echo "Test: --override-last that yields fewer than 3 messages aborts"
output=$(bash "$SCRIPT" --jsonl fixtures/todo-app.jsonl --project fixtures/sample-project --override-last 2)
assert_contains "abort on too few after override" "LEDE_ABORT:" "$output"

summary
