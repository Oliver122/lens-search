# Specified tests — orchestrator

Each item is an observable check. A coder treats an unmet item as a gap (`GAPS.md`), not as a license to widen the spec.

1. [process] Push of `req/<slug>` wakes `step-cycle.sh` (not `open-auto-feature` / one coder job). The first legal step saves the requirement delta versus `main` on `cycle/<slug>` as `DELTA.md` plus `CYCLE.md`.
2. [process] A later wake opens `orchestrator/<slug>` and splits `requirements/<slug>/specified-tests.md` into two or more subtasks when that file has more than one specified test. A RequirementSet with a single specified test may yield one subtask.
3. [process] Each worker is a separate agent invocation. Its prompt contains that subtask, `overview.md`, and not the transcripts or full prompts of sibling subtasks.
4. [process] Workers are sequential: one worker branch and PR at a time. A second worker is not opened while another is in-review.
5. [process] A good review merges the worker into `orchestrator/<slug>`. A bad review respawns the same subtask on a new worker branch (new attempt).
6. [process] `CYCLE.md` on `cycle/<slug>` is what the PO opens: it lists the saved delta, orchestrator branch, each subtask’s worker/PR/state (including respawned), incomplete-requirement, and the requirement PR.
7. [process] The requirement → `main` PR opens only after every subtask has merged. Bots do not merge that PR and do not enable auto-merge.
8. [process] A spec too thin to split or implement without guessing opens `missing-req/<slug>` with `MISSING.md` only and sets `incomplete` on the cycle record. Resume after timeout, pending review, or a held lease is the same `step-cycle.sh` wake.
