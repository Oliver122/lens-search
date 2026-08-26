#!/usr/bin/env bash
# Merge a subtask worktree branch into HEAD (auto-feature/<slug>).
# Product-file conflicts: abort, no force-merge, no invented spec.
# Bookkeeping-only conflicts (PROGRESS.md, ORCHESTRATION.md, GAPS.md): combine lists, keep boards.
set -euo pipefail

slug="${1:?slug required}"
n="${2:?subtask number required}"
br="${3:?branch required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

author_email="${GIT_AUTHOR_EMAIL:-bot@local}"
author_name="${GIT_AUTHOR_NAME:-auto-feature}"
git_commit() {
  git -c user.email="$author_email" -c user.name="$author_name" commit "$@"
}

if git -c user.email="$author_email" -c user.name="$author_name" \
     merge --no-ff -m "orchestrator(${slug}): merge subtask ${n}" "$br"; then
  exit 0
fi

mapfile -t conflicts < <(git diff --name-only --diff-filter=U)
if [[ ${#conflicts[@]} -eq 0 ]]; then
  git merge --abort >/dev/null 2>&1 || true
  echo "merge-subtask-worktree: merge failed without conflict list" >&2
  exit 1
fi

for f in "${conflicts[@]}"; do
  case "$f" in
    GAPS.md | PROGRESS.md | ORCHESTRATION.md) ;;
    *)
      git merge --abort >/dev/null 2>&1 || true
      echo "merge-subtask-worktree: product conflict on ${f}; not force-merging" >&2
      exit 1
      ;;
  esac
done

union_gaps() {
  local ours theirs
  ours="$(git show :2:GAPS.md 2>/dev/null || true)"
  theirs="$(git show :3:GAPS.md 2>/dev/null || true)"
  {
    echo "# Gaps — ${slug}"
    echo
    echo "$ours"
    echo
    echo "$theirs"
  } | awk 'NF && !seen[$0]++' > GAPS.md
}

for f in "${conflicts[@]}"; do
  case "$f" in
    GAPS.md)
      union_gaps
      git add GAPS.md
      ;;
    PROGRESS.md)
      git checkout --ours PROGRESS.md
      git add PROGRESS.md
      ;;
    ORCHESTRATION.md)
      git checkout --ours ORCHESTRATION.md
      git add ORCHESTRATION.md
      ;;
  esac
done

git_commit -m "orchestrator(${slug}): merge subtask ${n} (bookkeeping)"
exit 0
