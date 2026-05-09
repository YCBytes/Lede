#!/usr/bin/env bash
# Master orchestrator: assembles the Lede input bundle for the analyst subagent.
#
# Usage:
#   lede.sh --jsonl <path> --project <dir> [--override-last <N>] [--override-from <phrase>] [--reports-dir <dir>]
#
# Default --reports-dir: ~/.claude/lede
#
# Output:
#   On success: text bundle starting with "=== LEDE INPUT BUNDLE ===".
#   Abort path: single line starting with "LEDE_ABORT:" followed by a user-facing
#               message. Exit code is still 0 — the slash command handles the prefix.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib"

REPORTS_DIR="${HOME}/.claude/lede"
OVERRIDE_LAST=""
OVERRIDE_FROM=""
JSONL=""
PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --jsonl)         JSONL="$2"; shift 2 ;;
    --project)       PROJECT="$2"; shift 2 ;;
    --override-last) OVERRIDE_LAST="$2"; shift 2 ;;
    --override-from) OVERRIDE_FROM="$2"; shift 2 ;;
    --reports-dir)   REPORTS_DIR="$2"; shift 2 ;;
    *)               echo "lede.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

abort() {
  echo "LEDE_ABORT: $1"
  exit 0
}

if [ -z "$JSONL" ] || [ ! -f "$JSONL" ]; then
  abort "Couldn't find this session's log at '$JSONL'. Make sure you're running /assess inside Claude Code."
fi
[ -z "$PROJECT" ] && PROJECT="$(pwd)"

# Step 1: compute start_line based on override or default policy.
# start_line is the JSONL line number AFTER which content is included (i.e., extractors
# filter for input_line_number > start_line).
start_line=0

# Helper jq filter — selects real user-typed messages, excluding:
#   - tool_result echoes (.message.content is array, not string)
#   - Claude Code command meta-injections (start with "<command-" or "<local-command-")
#   - direct /assess typing (test fixtures use "/assess" as a literal first-line message)
#
# This is shared by all three branches below for consistency.
USER_FILTER='
  .type == "user"
  and ((.message.content | type) == "string")
  and ((.message.content | startswith("<command-")) | not)
  and ((.message.content | startswith("<local-command-")) | not)
  and ((.message.content | test("^/assess($|[[:space:]])")) | not)
'

if [ -n "$OVERRIDE_FROM" ]; then
  # Case-insensitive substring match against user-typed message content.
  start_line=$(jq -r --arg phrase "$OVERRIDE_FROM" "
    select($USER_FILTER)
    | select(.message.content | ascii_downcase | contains(\$phrase | ascii_downcase))
    | input_line_number
  " "$JSONL" | head -1)
  if [ -z "$start_line" ]; then
    # Build a "recent messages" hint from the last 5 user messages so the user can pick a real anchor.
    recent=$(jq -r "
      select($USER_FILTER)
      | .message.content
    " "$JSONL" | tail -5 | sed 's/^/  - /')
    abort "Phrase '$OVERRIDE_FROM' not found in this session. Recent messages:
$recent"
  fi
  # We want > start_line, but the matching line itself should be included, so set to (line - 1).
  start_line=$((start_line - 1))

elif [ -n "$OVERRIDE_LAST" ]; then
  # Find the JSONL line of the Nth-from-last user-typed message (excluding /assess).
  start_line=$(jq -r "
    select($USER_FILTER)
    | input_line_number
  " "$JSONL" | tail -"$OVERRIDE_LAST" | head -1)
  if [ -z "$start_line" ]; then
    start_line=0
  else
    start_line=$((start_line - 1))
  fi

else
  # Default: after the most recent PRIOR /assess invocation, if any.
  #
  # Definition of "prior": a /assess invocation that has REAL user typing
  # after it (i.e., the user kept working past it). The /assess that triggered
  # *this* script run, plus any /assess at the tail of the session followed
  # only by more slash-command invocations (e.g., /reload-plugins, /exit) and
  # hook output, are NOT prior — they're terminal noise we want to ignore.
  #
  # Rule: take the latest /assess line whose line number is < the line number
  # of the latest REAL user message (real = passes USER_FILTER, which already
  # excludes command meta-injections and /assess invocations themselves).
  #
  # Match BOTH the literal "/assess" form (test fixtures use this) AND the
  # wrapped "<command-name>/.../assess</command-name>" form Claude Code emits
  # for real plugin-namespaced slash-command invocations (e.g., /lede:assess).
  ASSESS_LINES=$(jq -r '
    select(.type == "user")
    | select((.message.content | type) == "string")
    | select(
        (.message.content | test("^/assess($|[[:space:]])"))
        or
        (.message.content | test("<command-name>[^<]*assess[^<]*</command-name>"))
      )
    | input_line_number
  ' "$JSONL")
  LAST_REAL_USER_LINE=$(jq -r "
    select($USER_FILTER)
    | input_line_number
  " "$JSONL" | tail -1)
  if [ -n "$LAST_REAL_USER_LINE" ] && [ -n "$ASSESS_LINES" ]; then
    start_line=$(echo "$ASSESS_LINES" | awk -v lru="$LAST_REAL_USER_LINE" '$1 < lru' | tail -1)
  fi
  start_line="${start_line:-0}"
fi

# Step 2: extract transcript and action log using the computed boundary.
transcript=$(bash "$LIB/extract-transcript.sh" --start-line "$start_line" "$JSONL")
action_log=$(bash "$LIB/extract-action-log.sh" --start-line "$start_line" "$JSONL")

# Step 3: minimum-length guard (3 user messages).
u_count=$(echo "$transcript" | grep -c '^\[U' || true)
if [ "$u_count" -lt 3 ]; then
  abort "Not enough session yet (only $u_count user message(s) in arc). /assess works best after 5+ user messages of refinement."
fi

# Step 4: project state.
project_state=$(bash "$LIB/extract-project-state.sh" "$PROJECT" 2>/dev/null || echo "(project state unavailable)")

# Step 5: recurring blind spots (silent on no pattern).
blind_spots=$(bash "$LIB/recurring-blind-spots.sh" "$REPORTS_DIR" 2>/dev/null || echo "")

# Step 6: enforce the 80 KB cap on transcript + action log combined.
combined="$transcript
$action_log"
combined_size=${#combined}
TRUNCATED_NOTE=""
MAX_BYTES=81920
if [ "$combined_size" -gt $MAX_BYTES ]; then
  excess=$((combined_size - MAX_BYTES))
  transcript_size=${#transcript}
  if [ "$excess" -lt "$transcript_size" ]; then
    transcript="${transcript:$excess}"
  else
    transcript="(transcript fully truncated due to size)"
  fi
  TRUNCATED_NOTE="(NOTE: combined transcript exceeded 80 KB; oldest messages truncated)"
fi

# Step 7: emit bundle.
cat <<EOF
=== LEDE INPUT BUNDLE ===
$TRUNCATED_NOTE

=== USER MESSAGES ===
$transcript

=== ACTION LOG ===
$action_log

=== PROJECT STATE AT /assess ===
$project_state

=== RECURRING BLIND SPOTS (if any) ===
$blind_spots
EOF
