---
description: "Plan a RequirementSet. Interview like /flow-1-problem; do not hunt for a product problem or invent a feature."
argument-hint: "[feature-slug]"
---

You are `/plan-requirement`. This repo is not a generic design-notes flow.

How this project works: a human writes `requirements/<slug>/` on `req/<slug>` (`/specify` or this command). Push of `req/<slug>` (when `missing-req/<slug>` is not open) starts `auto-feature/<slug>`, writes `CYCLE`, runs coder, and opens one MR to `main`. `GAPS.md` means a stated specified test is unmet. `MISSING.md` means the spec is too thin. You freeze by merging that MR. Agents commit only on `auto-feature/*`, `auto-fix/*`, or `missing-req/*` (`MISSING.md` only). Not `main`, not `req/*`.

This command is `/flow-1-problem` for a **requirement**, not for finding a problem or a feature. You start from an intended RequirementSet. You do not diagnose a product bug. You do not brainstorm features. You do not propose implementations, write product code, or run `/flow-2-options` / `/flow-3-detail`. You do not read or write `~/.cursor/design-notes/`. If I drift into solutions or feature ideas, pull me back to the requirement.

Slug: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask for a kebab-case feature slug and stop.

## Branch

1. `git fetch origin 2>/dev/null; git branch -a`
2. If `missing-req/<slug>` exists: check it out. Fill holes listed in `MISSING.md`. After the requirement is planned, tell me to push **`req/<slug>`** (new CYCLE). Do not treat `missing-req/<slug>` as the cycle trigger.
3. Else: check out `req/<slug>`, creating it from `main` if needed. Do not plan on `main`. Do not commit on `auto-feature/*` or `auto-fix/*`.

## Interview

Ask what prompted this requirement. Then interview me Socratically, **one question at a time**. Cover: the observable contract (what must be true), who is affected, what is in scope and out of scope, constraints, which part of the existing RequirementSet or product we understand poorly, and how we will know the requirement is met (specified tests). Do not pad the interview. Stop when open questions run out.

Restate the requirement in your own words. Ask if the restatement is correct.

## Write

If `requirements/<slug>/` is missing, copy `requirements/_template/` into it and replace `<slug>`.

Write:

- `overview.md` — in scope, out of scope, done when. Maximum 30 lines.
- `specified-tests.md` — observable checks derived from done-when. Do not invent Gherkin unless this set already uses it.

Do not create `CYCLE`. Do not create `GAPS.md`. Do not implement. Do not open MRs. Do not run coder or hardener.

Then tell me to commit on this branch and push `req/<slug>` to open auto-feature. If `specified-tests.md` is still too thin for a coder, tell me to run `/specify <slug>` next.

Handoff: if `HERDR_ENV` is 1, offer to open `/specify <slug>` in a fresh pane. On my yes, create a pane in this workspace running `agent "/specify $ARGUMENTS"` from the repo root. Otherwise end with: "Next: /specify <slug> if tests are thin, else commit and push `req/<slug>`."
