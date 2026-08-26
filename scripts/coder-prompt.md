Implement the RequirementSet for the given slug on the current `auto-feature/<slug>` branch.

Read `requirements/<slug>/overview.md` and `requirements/<slug>/specified-tests.md`. Implement until specified tests can pass. Do not add requirements.

If a specified test is unmet after you have implemented what the spec allows, write `GAPS.md` at the repo root listing those unmet specified tests. That file opens auto-fix.

If the spec is too thin to implement without guessing, do not invent Gherkin or extra requirements. Stop and tell CI to open missing-req (do not implement a guess).

Commit only on `auto-feature/<slug>`. Do not merge to main.
