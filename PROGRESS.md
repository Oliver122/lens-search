# Progress — orchestrator

States: `todo` | `in-progress` | `done` | `blocked` | `gap`

Live board on `auto-feature/orchestrator`. Do not edit `requirements/orchestrator/` to record status.

| # | specified test | state |
|---|---|---|
| 1 | Push of `req/<slug>` (when `missing-req/<slug>` is not open) still runs `openAutoFeature` (CYCLE, `auto-feature/<slug>`, one MR to `main`). The next agent in that job is an orchestrator, not a single coder for the whole RequirementSet. | done |
| 2 | The orchestrator splits `requirements/<slug>/specified-tests.md` into two or more subtasks when that file has more than one specified test. A RequirementSet with a single specified test may yield one subtask. | done |
| 3 | Each subtask coder is a separate agent invocation. Its prompt contains that subtask, `overview.md`, and not the transcripts or full prompts of sibling subtasks. | done |
| 4 | Subtask coders run in parallel in distinct git worktrees. They do not share one working tree while running. | done |
| 5 | When a subtask coder finishes, the orchestrator merges its worktree into `auto-feature/<slug>`. The MR head is that branch, not a worktree branch left unmerged. | done |
| 6 | If two worktrees conflict on merge, the orchestrator does not invent a spec. It records the conflict as blocked in `ORCHESTRATION.md` and either retries a serial merge after the other subtask lands or opens `GAPS.md` / missing-req per existing rules (unmet test vs thin spec). It does not force-merge through conflicts. | done |
| 7 | `ORCHESTRATION.md` exists on `auto-feature/<slug>` during the cycle and lists each subtask with state `running`, `done`, or `blocked`, updated as subtasks start and finish. | done |
| 8 | Unmet specified tests of the product RequirementSet still produce `GAPS.md` on `auto-feature/<slug>` (hardener path unchanged). A spec too thin to split or implement without guessing still opens `missing-req/<slug>` with `MISSING.md` only. | done |
| 9 | Bots still do not merge the auto-feature MR to `main`. `CYCLE` still hashes the RequirementSet tree as today. | todo |
