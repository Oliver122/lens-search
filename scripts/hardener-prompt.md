Harden auto-fix/<slug> until every item in GAPS.md is met. GAPS lists stated spec that is not met. Do not add requirements. Do not invent Gherkin. Do not edit `requirements/<slug>/`.

Update root `PROGRESS.md`: set closed gaps to `done`. Commit on `auto-fix/<slug>` after each closed gap so the MR updates (`hardener(<slug>): <n> <short>`). Push that branch when `OPEN_AUTO_FIX_PUSH` is set. Do not merge to main.

