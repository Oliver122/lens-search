#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=cam

doc="$(./scripts/cycle-record.sh save "$slug" <<EOF
# Cycle — ${slug}

| field | value |
|---|---|
| slug | ${slug} |
| hash | deadbeef |
| delta | DELTA.md |
| orch | orchestrator/${slug} |
| req_pr |  |
| incomplete |  |
| lease |  |

## Subtasks

| n | text | state | worker | pr | attempt |
|---|---|---|---|---|---|
| 1 | First check | in-review | worker/${slug}/1-1 | 9 | 1 |
EOF
)"

git rev-parse --verify "cycle/${slug}" >/dev/null
echo "$doc" | grep -q '| hash | deadbeef |'
echo "$doc" | grep -q '| delta | DELTA.md |'
echo "$doc" | grep -q '| orch | orchestrator/cam |'
echo "$doc" | grep -q '| 1 | First check | in-review | worker/cam/1-1 | 9 | 1 |'

got="$(./scripts/cycle-record.sh load "$slug")"
assert_eq "$(echo "$got" | grep '| hash |')" "| hash | deadbeef |" "load hash"
assert_eq "$(echo "$got" | grep '| 1 |')" "| 1 | First check | in-review | worker/cam/1-1 | 9 | 1 |" "load subtask"

# observe: missing worker + missing orch repaired; stale lease cleared
git checkout "cycle/${slug}" >/dev/null
./scripts/cycle-record.sh save "$slug" >/dev/null <<EOF
# Cycle — ${slug}

| field | value |
|---|---|
| slug | ${slug} |
| hash | deadbeef |
| delta | DELTA.md |
| orch | orchestrator/${slug} |
| req_pr |  |
| incomplete |  |
| lease | 0:stale |

## Subtasks

| n | text | state | worker | pr | attempt |
|---|---|---|---|---|---|
| 1 | First check | in-review | worker/${slug}/1-1 | 9 | 1 |
EOF

obs="$(./scripts/cycle-record.sh observe "$slug")"
echo "$obs" | grep -q '| orch |  |'
echo "$obs" | grep -q '| lease |  |'
echo "$obs" | grep -q '| 1 | First check | pending |  |  | 1 |'

# observe: worker ancestor of orch → merged
git checkout -B "orchestrator/${slug}" main >/dev/null
echo impl > impl.txt
git add impl.txt && git commit -m orch >/dev/null
git checkout -B "worker/${slug}/1-1" "orchestrator/${slug}" >/dev/null
echo w > w.txt
git add w.txt && git commit -m worker >/dev/null
git checkout "orchestrator/${slug}" >/dev/null
git merge --no-ff -m merge-w "worker/${slug}/1-1" >/dev/null

git checkout "cycle/${slug}" >/dev/null
./scripts/cycle-record.sh save "$slug" >/dev/null <<EOF
# Cycle — ${slug}

| field | value |
|---|---|
| slug | ${slug} |
| hash | deadbeef |
| delta | DELTA.md |
| orch | orchestrator/${slug} |
| req_pr |  |
| incomplete |  |
| lease |  |

## Subtasks

| n | text | state | worker | pr | attempt |
|---|---|---|---|---|---|
| 1 | First check | in-review | worker/${slug}/1-1 | 9 | 1 |
EOF

obs="$(./scripts/cycle-record.sh observe "$slug")"
echo "$obs" | grep -q '| 1 | First check | merged | worker/cam/1-1 | 9 | 1 |'

# observe: missing-req sets incomplete
git checkout -B "missing-req/${slug}" main >/dev/null
git checkout "cycle/${slug}" >/dev/null
obs="$(./scripts/cycle-record.sh observe "$slug")"
echo "$obs" | grep -q '| incomplete | missing-req/cam is open |'
