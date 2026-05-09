# Lede — Calibration Notes

**Date:** 2026-05-09
**Branch:** feature/lede-mvp
**Method:** Bundles generated via `scripts/lede.sh` against fixture JSONLs; analyst behavior simulated by passing the analyst's full system prompt + bundle to a Claude Sonnet subagent. Real Claude Code installation calibration is a separate manual step the user runs after `claude plugin install`.

## Calibration run 1 — todo-app fixture

**Bundle:** 6 user messages (`Build a todo app` → `no auth needed, keep code minimal`), 5 assistant turns capturing Write/Edit/Bash actions. Project state shows React + Tailwind. Recurring blind spot pre-derived from the 3 fixture reports (`tech preference` × 3).

**Analyst output: matches the template exactly.**

- Boundary line correct (`messages [U1]–[U6] (auto-detected)`).
- `**Recurring blind spot:**` line surfaced and rephrased into a single sentence.
- Diff table uses the `→` separator and the original `[U1]` text on the left, reconstructed prose on the right.
- 5 deltas extracted: `use Tailwind`, `mobile-first`, `localStorage`, `dark mode toggle`, `no auth + minimal code`. All classified as `foldable` with correct categories (`tech preference`, `UX preference`, `scope exclusion`).
- Each addition line matches the load-bearing format `- [<label> | <category>] <phrase> — <evidence>`.
- Reusable starting point reads as natural prose, ~2 sentences.
- Footer privacy line present.

**No tweaks needed.**

## Calibration run 2 — multi-topic fixture

**Bundle:** 5 user messages with a sharp pivot — `[U1]–[U2]` are an unrelated Python question, `[U3]` says "ok new task — build a React todo app", `[U4]–[U5]` are React work. `lede.sh` doesn't auto-detect topic shifts, so the bundle includes both topics.

**Analyst output: handled gracefully.**

- The analyst correctly anchored on `[U3]` as the effective first prompt (used `[U3]`'s text in the diff's left column).
- Inserted an advisory: "This session contains an earlier unrelated exchange ([U1]–[U2], Python list comprehension question). The real intent arc begins at [U3]. Consider re-running with `/assess from \"ok new task\"` or `/assess last 3`..."
- Diff and Additions section scoped to the React work only ([U4] tailwind, [U5] localStorage), classified as foldable.

This is the right call. The analyst can't auto-override the bundle boundary, but flagging it preserves accuracy and points the user to the override mechanism. The advisory line is not part of the strict template, but it's a sensible interpretation of the analyst's flexibility, not fabrication.

**Minor observation:** the boundary line still reports `messages [U1]–[U5]` (the full bundle range) even though the analysis effectively starts at `[U3]`. This is a small inconsistency but the advisory note resolves it for the user.

**No tweaks needed.** If multi-topic sessions become a common complaint in real-world use, a future enhancement could have `lede.sh` itself look for clear topic-pivot phrases ("ok new task", "switching gears", "new topic") and auto-set the start_line. For MVP, the override + analyst advisory is sufficient.

## Calibration run 3 — short fixture

**Bundle:** abort path. `short.jsonl` has only `hi` + `/assess`. `lede.sh` finds the `/assess` invocation, treats it as the "most recent prior /assess" boundary, and there are zero user messages after it.

**Output:** `LEDE_ABORT: Not enough session yet (only 0 user message(s) in arc). /assess works best after 5+ user messages of refinement.`

**Working as designed.** The slash command will display this message verbatim and skip subagent dispatch.

**Minor observation:** the wording "Not enough session yet (only 0...)" is technically accurate but a touch clinical. A future polish could distinguish the "no session before /assess" case from the "<3 messages" case. Not a blocker.

## Calibration run 4 — recurring blind spots wired through

Bundle generated with `--reports-dir tests/fixtures/reports`. The bundle's `=== RECURRING BLIND SPOTS (if any) ===` section contains:

```
RECURRING BLIND SPOTS
- 'tech preference' appeared in 3 of 3 recent sessions
```

The simulated analyst surfaced this in the report header as `**Recurring blind spot:** \`tech preference\` has appeared in 3 of 3 recent sessions — consider stating your stack upfront...`. End-to-end wiring works.

## Calibration run 5 — real session

Skipped in this automated calibration pass. To run: install the plugin (`claude plugin install <path>`) and invoke `/assess` against a real working session of ~10+ messages. Expected behavior matches calibration run 1.

## Cosmetic observations (low priority, do NOT block)

1. `extract-project-state.sh` lists `tailwind.config.js` twice — once in `config:` (intentional, signal-bearing) and once in `source files:` (because the find pipeline matches `*.js`). Could be tightened by excluding files already listed in `config:`. Not affecting analyst behavior.

2. Bundles always start with two blank lines after `=== LEDE INPUT BUNDLE ===` because `$TRUNCATED_NOTE` is empty in the typical case but the heredoc still outputs the line. Cosmetic.

## Verdict

- Format conformance: PASS across all runs.
- Classification quality: PASS — all deltas correctly classified, default-to-foldable rule respected.
- Multi-topic handling: graceful via analyst advisory.
- Cross-session feedback loop: end-to-end wiring works, surfaced in output.
- Privacy footer: always present.

The analyst's prompt does not need tuning for the fixture set. Real-session calibration is the next step the user runs hands-on after install.
