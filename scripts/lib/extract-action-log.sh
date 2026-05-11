#!/usr/bin/env bash
# Extract a condensed log of assistant turns from a session JSONL.
#
# Usage:
#   extract-action-log.sh [--start-line N] <jsonl-path>
#
# Output: one line per assistant turn after the start line, renumbered from A1.
#   [A1] <action 1>; <action 2>; ...
#   [A2] ...
#
# Captured tool_uses (others ignored):
#   Bash: "Bash `<command, truncated to 80 chars>`"
#   Write: "Write <file_path>"
#   Edit: "Edit <file_path>"
#   Task: "Task -> <subagent_type>"
#
# Assistant turns with no captured actions emit "[An] (no actions)".

set -e

START_LINE=0
if [ "$1" = "--start-line" ]; then
  START_LINE="$2"
  shift 2
fi

JSONL="$1"
if [ -z "$JSONL" ] || [ ! -f "$JSONL" ]; then
  echo "extract-action-log.sh: file not found: $JSONL" >&2
  exit 1
fi

# For each assistant turn after the start line, emit its action summary.
# Then renumber sequentially via awk.
jq -r --argjson start "$START_LINE" '
  select(input_line_number > $start)
  | select(.type == "assistant")
  | ([
      .message.content[]?
      | select(.type == "tool_use")
      | (
          if   .name == "Bash"  then "Bash `" + ((.input.command   // "") | .[0:80]) + "`"
          elif .name == "Write" then "Write " + (.input.file_path  // "")
          elif .name == "Edit"  then "Edit "  + (.input.file_path  // "")
          elif .name == "Task"  then "Task -> " + (.input.subagent_type // "")
          else empty
          end
        )
    ] | join("; ")) as $acts
  | if ($acts | length) > 0 then $acts else "(no actions)" end
' "$JSONL" | awk '{ printf "[A%d] %s\n", NR, $0 }'
