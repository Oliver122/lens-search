# Specified tests — orchestrator

Each item is an observable check. A coder treats an unmet item as a gap (`GAPS.md`), not as a license to widen the spec.

1. Push of `req/<slug>` (when `missing-req/<slug>` is not open) still runs `openAutoFeature` (CYCLE, `auto-feature/<slug>`, one MR to `main`). The next agent in that job is an orchestrator, not a single coder for the whole RequirementSet.
2. The orchestrator splits `requirements/<slug>/specified-tests.md` into two or more subtasks when that file has more than one specified test. A RequirementSet with a single specified test may yield one subtask.
3. Each subtask coder is a separate agent invocation. Its prompt contains that subtask, `overview.md`, and not the transcripts or full prompts of sibling subtasks.
4. Subtask coders run in parallel in distinct git worktrees. They do not share one working tree while running.
5. When a subtask coder finishes, the orchestrator merges its worktree into `auto-feature/<slug>`. The MR head is that branch, not a worktree branch left unmerged.
6. If two worktrees conflict on merge, the orchestrator does not invent a spec. It records the conflict as blocked in `ORCHESTRATION.md` and either retries a serial merge after the other subtask lands or opens `GAPS.md` / missing-req per existing rules (unmet test vs thin spec). It does not force-merge through conflicts.
7. `ORCHESTRATION.md` exists on `auto-feature/<slug>` during the cycle and lists each subtask with state `running`, `done`, or `blocked`, updated as subtasks start and finish.
8. Unmet specified tests of the product RequirementSet still produce `GAPS.md` on `auto-feature/<slug>` (hardener path unchanged). A spec too thin to split or implement without guessing still opens `missing-req/<slug>` with `MISSING.md` only.
9. Bots still do not merge the auto-feature MR to `main`. `CYCLE` still hashes the RequirementSet tree as today.
