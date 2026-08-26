# orchestrator

CI cycle for a RequirementSet. Personal repo. Same freeze rules as today.

## In scope

- After `openAutoFeature`, an orchestrator runs instead of one long coder.
- Orchestrator splits `specified-tests.md` into subtasks. Each subtask is one coder agent with a fresh context: that subtask, the overview, and only the files it needs. It does not carry other subtasks’ transcripts.
- Coders run in parallel in separate git worktrees. Orchestrator merges each finished worktree onto `auto-feature/<slug>`.
- `ORCHESTRATION.md` on that branch lists each subtask as running, done, or blocked (`GAPS` / missing-req).
- Still one CYCLE, one MR to `main`. Unmet specified tests still become `GAPS.md`. Thin spec still opens `missing-req`. Agents still do not merge to `main`.

## Out of scope

- Changing freeze (human still approves the MR).
- Changing a product RequirementSet’s tests (e.g. marketplace-scan-store).
- Graphical UI for progress.

## Done when

- A cycle never depends on a single coder holding the whole spec in one context window.
- Parallel subtask coders merge onto one `auto-feature/<slug>` branch, progress is readable in `ORCHESTRATION.md`, and GAPS / missing-req / CYCLE / one-MR rules still hold.
