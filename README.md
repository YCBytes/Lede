# Lede

> See what you could have said in your first prompt.

Lede is a Claude Code plugin. When you type `/assess`, it analyzes the chunk of session ending at that moment and shows you a diff between your original first prompt and a stronger starting point for similar future work.

Each addition is labeled:

- **foldable** — could have been said upfront (tech preferences, scope exclusions, style preferences, corrections).
- **emergent** — only knowable by trying (reactions to output, problems found by use).

The reconstructed prompt is framed as a starting point for *similar future work*, not a retroactive claim that it would have produced the same result.

## Install

```bash
claude plugin install <path-or-repo>
```

## Usage

In any Claude Code session:

```
/assess
```

Optional overrides:

```
/assess last 20
/assess from "build a todo app"
```

The full report is saved to `~/.claude/lede/<session>-<timestamp>.md`.

## How the boundary is chosen

By default, Lede analyzes the messages back to the start of your current intent arc, auto-detected by looking for goal pivots and time gaps. The boundary is shown in every report. If you disagree, override with `last <N>` or `from "<phrase>"`.

## Cross-session feedback

When the same `[foldable | <category>]` shows up in 2+ of your last 3 reports, Lede surfaces it as a **Recurring blind spot** at the top of the next report. This is the part that turns one-shot insights into habit change.

## Privacy

The transcript and a small project-state snapshot are sent to Claude (via the analyst subagent) for analysis. Nothing is uploaded to any third-party service. Avoid running `/assess` on sessions containing secrets.

## Limitations

- Boundary detection can misjudge if you change directories mid-session. Use `from "<phrase>"` to anchor manually.
- MVP is Claude-Code-only; Cursor / Codex support is a v2 fork.
- Hard cap: 80 KB combined transcript+action-log per analysis.

## Architecture

- `commands/assess.md` — slash command (orchestrator prompt)
- `agents/lede-analyst.md` — analysis subagent (Sonnet)
- `scripts/lede.sh` — bash orchestrator that assembles the input bundle
- `scripts/lib/*` — single-purpose extractors

See `docs/superpowers/specs/2026-05-09-lede-design.md` for full design.

## Development

```bash
bash tests/run-all.sh
```

Runs all extractor unit tests against the fixtures in `tests/fixtures/`.
