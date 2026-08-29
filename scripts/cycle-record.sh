#!/usr/bin/env bash
# Load, observe, and save the cycle as one document on cycle/<slug>.
set -euo pipefail

CR_SLUG=""
CR_HASH=""
CR_DELTA=""
CR_ORCH=""
CR_REQ_PR=""
CR_INCOMPLETE=""
CR_LEASE=""
CR_N=()
CR_TEXT=()
CR_STATE=()
CR_WORKER=()
CR_PR=()
CR_ATTEMPT=()

cycle_record_trim() {
  local s="${1-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

cycle_record_empty_doc() {
  local slug="$1"
  cat <<EOF
# Cycle — ${slug}

| field | value |
|---|---|
| slug | ${slug} |
| hash |  |
| delta |  |
| orch |  |
| req_pr |  |
| incomplete |  |
| lease |  |

## Subtasks

| n | text | state | worker | pr | attempt |
|---|---|---|---|---|---|
EOF
}

cycle_record_render() {
  local slug="${CR_SLUG:?}"
  local i
  echo "# Cycle — ${slug}"
  echo
  echo "| field | value |"
  echo "|---|---|"
  echo "| slug | ${slug} |"
  echo "| hash | ${CR_HASH:-} |"
  echo "| delta | ${CR_DELTA:-} |"
  echo "| orch | ${CR_ORCH:-} |"
  echo "| req_pr | ${CR_REQ_PR:-} |"
  echo "| incomplete | ${CR_INCOMPLETE:-} |"
  echo "| lease | ${CR_LEASE:-} |"
  echo
  echo "## Subtasks"
  echo
  echo "| n | text | state | worker | pr | attempt |"
  echo "|---|---|---|---|---|---|"
  if [[ ${#CR_N[@]} -gt 0 ]]; then
    for i in "${!CR_N[@]}"; do
      printf '| %s | %s | %s | %s | %s | %s |\n' \
        "${CR_N[$i]}" "${CR_TEXT[$i]}" "${CR_STATE[$i]}" \
        "${CR_WORKER[$i]}" "${CR_PR[$i]}" "${CR_ATTEMPT[$i]}"
    done
  fi
}

cycle_record_clear() {
  CR_SLUG=""
  CR_HASH=""
  CR_DELTA=""
  CR_ORCH=""
  CR_REQ_PR=""
  CR_INCOMPLETE=""
  CR_LEASE=""
  CR_N=()
  CR_TEXT=()
  CR_STATE=()
  CR_WORKER=()
  CR_PR=()
  CR_ATTEMPT=()
}

cycle_record_parse() {
  local file="$1"
  cycle_record_clear
  local section="fields"
  local line cells
  local -a cols
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "## Subtasks" ]]; then
      section="subtasks"
      continue
    fi
    if [[ "$line" != \|* ]]; then
      continue
    fi
    if [[ "$line" == *"---"* ]]; then
      continue
    fi
    line="${line#|}"
    line="${line%|}"
    IFS='|' read -r -a cols <<< "$line"
    if [[ "$section" == "fields" ]]; then
      local key value
      key="$(cycle_record_trim "${cols[0]:-}")"
      value="$(cycle_record_trim "${cols[1]:-}")"
      case "$key" in
        field) continue ;;
        slug) CR_SLUG="$value" ;;
        hash) CR_HASH="$value" ;;
        delta) CR_DELTA="$value" ;;
        orch) CR_ORCH="$value" ;;
        req_pr) CR_REQ_PR="$value" ;;
        incomplete) CR_INCOMPLETE="$value" ;;
        lease) CR_LEASE="$value" ;;
      esac
    else
      local n text state worker pr attempt
      n="$(cycle_record_trim "${cols[0]:-}")"
      if [[ "$n" == "n" || ! "$n" =~ ^[0-9]+$ ]]; then
        continue
      fi
      text="$(cycle_record_trim "${cols[1]:-}")"
      state="$(cycle_record_trim "${cols[2]:-}")"
      worker="$(cycle_record_trim "${cols[3]:-}")"
      pr="$(cycle_record_trim "${cols[4]:-}")"
      attempt="$(cycle_record_trim "${cols[5]:-}")"
      [[ -n "$attempt" ]] || attempt=0
      CR_N+=("$n")
      CR_TEXT+=("$text")
      CR_STATE+=("$state")
      CR_WORKER+=("$worker")
      CR_PR+=("$pr")
      CR_ATTEMPT+=("$attempt")
    fi
  done < "$file"
}

cycle_record_commit() {
  local msg="$1"
  if [[ -n "$(git status --porcelain -- CYCLE.md)" ]]; then
    git add CYCLE.md
    git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-cycle}" \
      commit -m "$msg" >/dev/null
  fi
}

cycle_record_base_ref() {
  if git rev-parse --verify refs/heads/main >/dev/null 2>&1; then
    echo main
  elif git rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
    echo origin/main
  else
    echo HEAD
  fi
}

cycle_record_chmod_scripts() {
  local root
  root="$(git rev-parse --show-toplevel)"
  chmod +x "${root}/scripts/"*.sh
}

cycle_record_ensure_branch() {
  local slug="$1"
  local br="cycle/${slug}"
  local root
  root="$(git rev-parse --show-toplevel)"
  cd "$root"
  if git rev-parse --verify "refs/heads/${br}" >/dev/null 2>&1; then
    git checkout -f "$br" >/dev/null 2>&1
  elif git rev-parse --verify "refs/remotes/origin/${br}" >/dev/null 2>&1; then
    git checkout -f -B "$br" "origin/${br}" >/dev/null 2>&1
  else
    git checkout -f -B "$br" "$(cycle_record_base_ref)" >/dev/null 2>&1
    cycle_record_empty_doc "$slug" > CYCLE.md
    git add CYCLE.md
    git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-cycle}" \
      commit -m "cycle(${slug}): open record" >/dev/null
  fi
  cycle_record_chmod_scripts
  bash "${root}/scripts/assert-agent-branch.sh" "$br"
}

cycle_record_load() {
  local slug="${1:?slug required}"
  cycle_record_ensure_branch "$slug"
  if [[ ! -f CYCLE.md ]]; then
    cycle_record_empty_doc "$slug" > CYCLE.md
    cycle_record_commit "cycle(${slug}): open record"
  fi
  cat CYCLE.md
}

cycle_record_save() {
  local slug="${1:?slug required}"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  cycle_record_ensure_branch "$slug"
  cp "$tmp" CYCLE.md
  rm -f "$tmp"
  cycle_record_parse CYCLE.md
  CR_SLUG="$slug"
  cycle_record_render > CYCLE.md
  cycle_record_commit "cycle(${slug}): save"
  cat CYCLE.md
}

cycle_record_push_ref() {
  local br="$1"
  git remote get-url origin >/dev/null 2>&1 || return 0
  git push -u origin "$br"
}

cycle_record_ref_exists() {
  local name="$1"
  git rev-parse --verify "refs/heads/${name}" >/dev/null 2>&1 \
    || git rev-parse --verify "refs/remotes/origin/${name}" >/dev/null 2>&1
}

cycle_record_is_ancestor() {
  local older="$1"
  local newer="$2"
  git merge-base --is-ancestor "$older" "$newer" 2>/dev/null
}

cycle_record_observe() {
  local slug="${1:?slug required}"
  local now lease_epoch i worker orch changed=0
  now="$(date +%s)"
  cycle_record_ensure_branch "$slug"
  cycle_record_parse CYCLE.md
  CR_SLUG="$slug"

  if [[ -n "${CR_LEASE:-}" ]]; then
    lease_epoch="${CR_LEASE%%:*}"
    if [[ "$lease_epoch" =~ ^[0-9]+$ ]] && (( now - lease_epoch >= 7200 )); then
      CR_LEASE=""
      changed=1
    fi
  fi

  orch="${CR_ORCH:-}"
  if [[ -n "$orch" ]] && ! cycle_record_ref_exists "$orch"; then
    CR_ORCH=""
    changed=1
    orch=""
  fi

  if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    worker="${CR_WORKER[$i]}"
    [[ -n "$worker" ]] || continue
    if ! cycle_record_ref_exists "$worker"; then
      if [[ "${CR_STATE[$i]}" != "merged" ]]; then
        CR_WORKER[$i]=""
        CR_PR[$i]=""
        CR_STATE[$i]="pending"
        changed=1
      fi
    elif [[ -n "$orch" ]] && cycle_record_is_ancestor "$worker" "$orch"; then
      if [[ "${CR_STATE[$i]}" != "merged" ]]; then
        CR_STATE[$i]="merged"
        changed=1
      fi
    fi
  done
  fi

  if cycle_record_ref_exists "missing-req/${slug}" && [[ -z "${CR_INCOMPLETE:-}" ]]; then
    CR_INCOMPLETE="missing-req/${slug} is open"
    changed=1
  fi

  if [[ "$changed" -eq 1 ]]; then
    cycle_record_render > CYCLE.md
    cycle_record_commit "cycle(${slug}): observe"
  fi
  cat CYCLE.md
}

cycle_record_usage() {
  echo "usage: cycle-record.sh load|save|observe <slug>" >&2
  exit 2
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cmd="${1:-}"
  slug="${2:-}"
  case "$cmd" in
    load|save|observe)
      [[ -n "$slug" ]] || cycle_record_usage
      "cycle_record_${cmd}" "$slug"
      ;;
    *)
      cycle_record_usage
      ;;
  esac
fi
