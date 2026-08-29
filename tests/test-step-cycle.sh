#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
install_test_agent "$tmp/bin"
export CURSOR_API_KEY=test

assert_fail "bad slug" ./scripts/step-cycle.sh '../x'

write_catalog() {
  local slug="$1"
  mkdir -p "requirements/${slug}"
  cat > "requirements/${slug}/overview.md" <<EOF
# ${slug}

## Catalog

### group

ungrouped

### slices

process

### defs

EOF
}

# resume: one legal step per wake
slug=cam
git checkout -b "req/${slug}" >/dev/null
write_catalog "$slug"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
1. [process] First observable check
2. [process] Second observable check
EOF
git add requirements && git commit -m spec >/dev/null

./scripts/step-cycle.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| delta | DELTA.md |'
assert_fail "orch not yet" git rev-parse --verify "orchestrator/${slug}"

# cycle/ snapshots main; those scripts may be 0644. Next wake must still run.
chmod a-x scripts/*.sh
bash ./scripts/step-cycle.sh "$slug"
git rev-parse --verify "orchestrator/${slug}" >/dev/null
assert_fail "worker not yet" git rev-parse --verify "worker/${slug}/1-1"

./scripts/step-cycle.sh "$slug"
git rev-parse --verify "worker/${slug}/1-1" >/dev/null
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 1 | First observable check | in-review |'
assert_fail "no second worker" git rev-parse --verify "worker/${slug}/2-1"

# pending review: same step is apply (no-op), still one worker
./scripts/step-cycle.sh "$slug"
assert_fail "still no second worker" git rev-parse --verify "worker/${slug}/2-1"

WORKER_REVIEW=approve ./scripts/step-cycle.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 1 | First observable check | merged |'

./scripts/step-cycle.sh "$slug"
git rev-parse --verify "worker/${slug}/2-1" >/dev/null

WORKER_REVIEW=reject ./scripts/step-cycle.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 2 | Second observable check | respawned |'

./scripts/step-cycle.sh "$slug"
git rev-parse --verify "worker/${slug}/2-2" >/dev/null

WORKER_REVIEW=approve ./scripts/step-cycle.sh "$slug"
assert_fail "req PR not opened as a side effect of review" \
  grep -q '| req_pr | req/cam |' <<<"$(./scripts/cycle-record.sh load "$slug")"

./scripts/step-cycle.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| req_pr | req/cam |'
git checkout "req/${slug}" >/dev/null
test -f subtask-1.txt
test -f subtask-2.txt

# lease: busy wake does nothing
slug2=lease
git checkout main >/dev/null
write_catalog "$slug2"
echo "1. [process] Only one check" > "requirements/${slug2}/specified-tests.md"
git add requirements && git commit -m lease >/dev/null
git checkout -b "req/${slug2}" >/dev/null
./scripts/step-cycle.sh "$slug2" >/dev/null
now="$(date +%s)"
./scripts/cycle-record.sh save "$slug2" >/dev/null <<EOF
$(./scripts/cycle-record.sh load "$slug2" | sed "s/| lease |  |/| lease | ${now}:held |/")
EOF
./scripts/step-cycle.sh "$slug2"
assert_fail "lease blocks orch" git rev-parse --verify "orchestrator/${slug2}"

# incomplete: thin spec
slug3=thin
git checkout main >/dev/null
mkdir -p "requirements/${slug3}"
echo in > "requirements/${slug3}/overview.md"
echo "no numbers" > "requirements/${slug3}/specified-tests.md"
git add requirements && git commit -m thin >/dev/null
git checkout -b "req/${slug3}" >/dev/null
./scripts/step-cycle.sh "$slug3" >/dev/null
./scripts/step-cycle.sh "$slug3"
git rev-parse --verify "missing-req/${slug3}" >/dev/null
rec="$(./scripts/cycle-record.sh load "$slug3")"
echo "$rec" | grep -q '| incomplete |'
test -f MISSING.md || git checkout "missing-req/${slug3}" >/dev/null
git checkout "missing-req/${slug3}" >/dev/null
test -f MISSING.md

# pin: cycle/ carries main's stale open-worker; wake still uses req scripts
slug_pin=pin
git checkout main >/dev/null
mkdir -p "requirements/${slug_pin}" requirements/_defs
cat > "requirements/${slug_pin}/overview.md" <<EOF
# ${slug_pin}

## Catalog

### group

ungrouped

### slices

process

### defs

hook-shape
EOF
echo "1. [process] Only one check" > "requirements/${slug_pin}/specified-tests.md"
git add requirements && git commit -m pin-spec >/dev/null
git checkout -b "req/${slug_pin}" >/dev/null
echo '# hook-shape' > requirements/_defs/hook-shape.md
git add requirements/_defs/hook-shape.md && git commit -m pin-def >/dev/null
git checkout main >/dev/null
printf '%s\n' '#!/usr/bin/env bash' 'echo stale-open-worker >&2' 'exit 1' > scripts/open-worker.sh
git add scripts/open-worker.sh && git commit -m stale-ow >/dev/null
git checkout "req/${slug_pin}" >/dev/null
./scripts/step-cycle.sh "$slug_pin" >/dev/null
./scripts/step-cycle.sh "$slug_pin" >/dev/null
./scripts/step-cycle.sh "$slug_pin"
git rev-parse --verify "worker/${slug_pin}/1-1" >/dev/null
git checkout "worker/${slug_pin}/1-1" >/dev/null
test -f requirements/_defs/hook-shape.md
git checkout main >/dev/null
git checkout "req/${slug_pin}" -- scripts/open-worker.sh
git add scripts/open-worker.sh && git commit -m restore-ow >/dev/null

# incomplete: bad shape (untagged tests)
slug_shape=shape
git checkout main >/dev/null
write_catalog "$slug_shape"
echo "1. Untagged numbered check" > "requirements/${slug_shape}/specified-tests.md"
git add requirements && git commit -m shape >/dev/null
git checkout -b "req/${slug_shape}" >/dev/null
./scripts/step-cycle.sh "$slug_shape" >/dev/null
./scripts/step-cycle.sh "$slug_shape"
git rev-parse --verify "missing-req/${slug_shape}" >/dev/null
rec="$(./scripts/cycle-record.sh load "$slug_shape")"
echo "$rec" | grep -q '| incomplete |'
assert_fail "no orch on bad shape" git rev-parse --verify "orchestrator/${slug_shape}"

# dual-truth: observe repairs missing worker, next wake re-opens
slug4=drift
git checkout main >/dev/null
write_catalog "$slug4"
echo "1. [process] Only one check" > "requirements/${slug4}/specified-tests.md"
git add requirements && git commit -m drift >/dev/null
git checkout -b "req/${slug4}" >/dev/null
./scripts/step-cycle.sh "$slug4" >/dev/null
./scripts/step-cycle.sh "$slug4" >/dev/null
./scripts/step-cycle.sh "$slug4" >/dev/null
git branch -D "worker/${slug4}/1-1" >/dev/null
obs="$(./scripts/cycle-record.sh observe "$slug4")"
echo "$obs" | grep -q '| 1 | Only one check | pending |'
./scripts/step-cycle.sh "$slug4"
git rev-parse --verify "worker/${slug4}/1-1" >/dev/null
