# Progress — orchestrator

States: `todo` | `in-progress` | `done` | `blocked` | `gap`

Live board is `CYCLE.md` on `cycle/<slug>`. Do not edit `requirements/orchestrator/` to record status.

| # | specified test | state |
|---|---|---|
| 1 | Push of `req/<slug>` wakes `step-cycle.sh`; first step saves delta vs `main` on `cycle/<slug>`. | done |
| 2 | Later wake opens `orchestrator/<slug>` and splits specified tests into subtasks. | done |
| 3 | Each worker is a separate agent; prompt is that subtask + overview only. | done |
| 4 | Workers are sequential: one in-review at a time. | done |
| 5 | Good review merges into orchestrator; bad review respawns the same subtask. | done |
| 6 | `CYCLE.md` lists delta, orch, workers, incomplete, requirement PR. | done |
| 7 | Requirement → `main` PR only after every subtask merged; no bot merge / automerge. | done |
| 8 | Thin spec → missing-req + incomplete; resume is the same `step-cycle.sh` wake. | done |
