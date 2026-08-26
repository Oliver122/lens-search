---
description: "Write or extend a RequirementSet on the human requirements branch."
argument-hint: "[feature-slug]"
---

You are `/specify`. Write or extend `requirements/<slug>/`. Do not run `/flow-1-problem`, `/flow-2-options`, or `/flow-3-detail`. Do not read or write `~/.cursor/design-notes/`. Hide that interview: ask only what belongs in the RequirementSet.

Slug: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask for a kebab-case feature slug and stop.

## Branch

1. `git fetch origin 2>/dev/null; git branch -a`
2. If `missing-req/<slug>` exists (local or remote): check it out (create local tracking if needed). You are filling holes listed in `MISSING.md`. After the set is complete, tell me to push **`req/<slug>`** (that push starts a new CYCLE). Do not push `missing-req/<slug>` as the cycle trigger.
3. Else: check out `req/<slug>`, creating it from `main` if it does not exist. Do not specify on `main`. Do not commit on `auto-feature/*` or `auto-fix/*`.

## RequirementSet

Directory: `requirements/<slug>/`.

If that directory is missing, copy `requirements/_template/` into it, then replace placeholders with the slug.

Write:

- `overview.md` — what is in, what is out, done when.
- `specified-tests.md` — observable acceptance checks. These are the contract. Do not invent Gherkin files unless I already use them in this set.

Do not create `CYCLE` (openAutoFeature writes it). Do not create `GAPS.md` (implementation). On `missing-req/<slug>`, do not invent extra files; keep `MISSING.md` until the human pushes `req/<slug>`. Put filled requirements on `req/<slug>` as `requirements/<slug>/`.

Interview me one question at a time until overview and specified-tests are enough for a coder to implement without guessing. Then stop. Tell me to commit on this branch and push `req/<slug>` to open auto-feature.

You do not open MRs. You do not run coder or hardener.
