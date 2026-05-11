---
description: Analyze your last intent arc and show a stronger starting point for similar future work.
argument-hint: [from "<phrase>" | last <N>]
allowed-tools: Bash, Task, Write
---

# /assess

Run the Lede orchestrator and dispatch the result to the lede-analyst subagent.

## Step 1 — Locate session JSONL

The session JSONL lives somewhere under `~/.claude/projects/<cwd-slug>/$CLAUDE_SESSION_ID.jsonl`. Claude Code's slug transformation isn't a stable contract (it converts `/`, spaces, and possibly other characters to `-`), so locate the file by session ID via `find` rather than reconstructing the slug:

```bash
JSONL="$(find "$HOME/.claude/projects" -maxdepth 2 -name "${CLAUDE_SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)"
echo "$JSONL"
```

Save the resolved JSONL path; use it in Step 2. If `JSONL` is empty, the orchestrator's own missing-file abort will fire in Step 3 with a clear message.

## Step 2 — Parse arguments and run the orchestrator

The user's arguments arrive as `$ARGUMENTS`. Parse:
- `last <N>` → `--override-last <N>`
- `from "<phrase>"` (or `from <phrase>`) → `--override-from "<phrase>"`
- empty → no override flags

Run the orchestrator and capture stdout:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/lede.sh" \
  --jsonl "$JSONL" \
  --project "$(pwd)" \
  $OVERRIDE_FLAGS
```

(Where `$OVERRIDE_FLAGS` is whatever you parsed above, possibly empty.)

## Step 3 — Handle abort path

If the captured output begins with `LEDE_ABORT:`, print everything after that prefix to the user verbatim and STOP. Do NOT dispatch to the subagent.

## Step 4 — Dispatch to lede-analyst

Otherwise, dispatch the captured bundle to the `lede-analyst` subagent via the Task tool:

- `subagent_type`: `lede-analyst`
- `description`: `Lede session analysis`
- `prompt`: the entire captured bundle, verbatim

Capture the subagent's response.

## Step 5 — Save and display

Save the subagent's response verbatim to `~/.claude/lede/<session>-<timestamp>.md`:

```bash
mkdir -p "$HOME/.claude/lede"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_PATH="$HOME/.claude/lede/${CLAUDE_SESSION_ID}-${TIMESTAMP}.md"
```

Use the Write tool to write the subagent's response to `$OUT_PATH`.

Then print the subagent's response verbatim to the user, followed by one trailing line:

```
Saved to ~/.claude/lede/<filename>
```

## Constraints

- Do NOT modify the subagent's response. Save and print verbatim.
- If saving fails (disk full, perms), print the inline diff anyway and append `(warning: report could not be saved: <reason>)`.
- Do NOT continue working on the user's original task after `/assess`. The slash command's job ends after the report is shown.
