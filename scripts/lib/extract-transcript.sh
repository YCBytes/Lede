#!/usr/bin/env bash
# Extract user-typed messages from a Claude Code session JSONL.
#
# Usage:
#   extract-transcript.sh --start-line N <jsonl-path>
#
# Emits user messages whose JSONL line number > N, excluding:
#   - tool_result echoes (where .message.content is an array)
#   - /assess invocations
#
# Output (renumbered from U1):
#   [U1] <message text>
#   [U2] <message text>
#   ...
#
# Multi-line message content has internal newlines replaced with " | ".
# The boundary line N is computed by the caller (lede.sh). This script does no
# auto-detection of its own — it just filters by line.

set -e

START_LINE=""
if [ "$1" = "--start-line" ]; then
  START_LINE="$2"
  shift 2
fi

if [ -z "$START_LINE" ]; then
  echo "extract-transcript.sh: --start-line N is required" >&2
  exit 1
fi

JSONL="$1"
if [ -z "$JSONL" ] || [ ! -f "$JSONL" ]; then
  echo "extract-transcript.sh: file not found: $JSONL" >&2
  exit 1
fi

# Pull user-typed messages (string content) past START_LINE, excluding /assess,
# replace internal newlines, renumber from U1.
jq -r --argjson start "$START_LINE" '
  select(input_line_number > $start)
  | select(.type == "user")
  | select((.message.content | type) == "string")
  | select(.message.content | test("^/assess($|[[:space:]])") | not)
  | (.message.content | gsub("\n"; " | "))
' "$JSONL" | awk '{ printf "[U%d] %s\n", NR, $0 }'
