#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
. lib/assert.sh

SCRIPT="../scripts/lib/extract-action-log.sh"

echo "Test: todo-app extracts 5 assistant turns, only [A] lines"
output=$(bash "$SCRIPT" fixtures/todo-app.jsonl)
a_count=$(echo "$output" | grep -c '^\[A' || true)
assert_eq "5 assistant turns" "5" "$a_count"
assert_not_contains "no [U] lines (only [A])" "[U" "$output"

assert_contains "A1 starts with [A1]" "[A1]" "$output"
assert_contains "A1 includes Write App.jsx" "Write src/App.jsx" "$output"
assert_contains "A1 includes npm install react" "npm install react" "$output"
assert_contains "A2 includes tailwindcss install" "npm install tailwindcss" "$output"
assert_contains "A2 includes Edit App.jsx" "Edit src/App.jsx" "$output"
assert_not_contains "drops thinking blocks" "thinking" "$output"
assert_not_contains "drops text blocks" "Switching to Tailwind" "$output"

echo ""
echo "Test: --start-line 0 (or omitted) gives all assistant turns"
output_default=$(bash "$SCRIPT" fixtures/todo-app.jsonl)
output_zero=$(bash "$SCRIPT" --start-line 0 fixtures/todo-app.jsonl)
assert_eq "default == --start-line 0" "$output_default" "$output_zero"

echo ""
echo "Test: --start-line N filters earlier turns and renumbers from A1"
# todo-app fixture: line 2 is the first assistant turn. Filter past it.
output=$(bash "$SCRIPT" --start-line 2 fixtures/todo-app.jsonl)
a_count=$(echo "$output" | grep -c '^\[A' || true)
assert_eq "4 assistant turns after dropping the first" "4" "$a_count"
assert_contains "renumbered to A1" "[A1]" "$output"
assert_not_contains "no original A2-A5 numbering remains as A5" "[A5]" "$output"

summary
