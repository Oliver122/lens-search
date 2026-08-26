Implement the RequirementSet for the given slug on the current `auto-feature/<slug>` branch.

Read `requirements/<slug>/overview.md` and `requirements/<slug>/specified-tests.md`. Implement until specified tests can pass. Do not add requirements. Do not edit files under `requirements/<slug>/` (that would change CYCLE).

Keep `PROGRESS.md` at the repo root in sync with `specified-tests.md`. States: `todo`, `in-progress`, `done`, `blocked`, `gap`. Set a test to `in-progress` before you work on it, then `done` when that specified test holds. Use `gap` only for an unmet specified test you also list in `GAPS.md`. Use `blocked` if you cannot continue without a thicker spec (missing-req).

Commit often on `auto-feature/<slug>` so the MR shows progress: at least one commit per specified test (code plus the `PROGRESS.md` row). Commit message form: `coder(<slug>): <n> <short>`. After each commit, if `OPEN_AUTO_FEATURE_PUSH` is set, push `auto-feature/<slug>` to origin. Do not merge to main.

If a specified test is unmet after you have implemented what the spec allows, write `GAPS.md` at the repo root listing those unmet specified tests. That file opens auto-fix.

If the spec is too thin to implement without guessing, do not invent Gherkin or extra requirements. Stop and tell CI to open missing-req (do not implement a guess).
