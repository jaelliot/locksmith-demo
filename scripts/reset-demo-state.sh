#!/usr/bin/env bash
# Remove KERI store directories scoped to LOCKSMITH_BASE (same roots/stores as demo-day.sh).
#
# Usage (from repo root):
#   ./scripts/reset-demo-state.sh
#   LOCKSMITH_BASE=my-base ./scripts/reset-demo-state.sh
#
# Refuses an empty base after trim (never deletes unscoped ~/.keri/db trees).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

LOCKSMITH_BASE="${LOCKSMITH_BASE:-locksmith-demo}"
LOCKSMITH_EXTRA_RESET_ROOTS="${LOCKSMITH_EXTRA_RESET_ROOTS:-}"
# Trim leading/trailing whitespace (bash parameter expansion)
LOCKSMITH_BASE="${LOCKSMITH_BASE#"${LOCKSMITH_BASE%%[![:space:]]*}"}"
LOCKSMITH_BASE="${LOCKSMITH_BASE%"${LOCKSMITH_BASE##*[![:space:]]}"}"

if [[ -z "${LOCKSMITH_BASE}" ]]; then
  echo "[reset-demo-state] ERROR: LOCKSMITH_BASE is empty; refusing to delete unscoped global KERI data." >&2
  exit 1
fi

RESET_ROOTS=()

add_reset_root_if_missing() {
  local candidate="$1"
  if [[ -z "${candidate}" ]]; then
    return 0
  fi
  if [[ ! -e "${candidate}" ]]; then
    return 0
  fi
  for existing in "${RESET_ROOTS[@]:-}"; do
    if [[ "${existing}" == "${candidate}" ]]; then
      return 0
    fi
  done
  RESET_ROOTS+=("${candidate}")
}

add_configured_reset_roots() {
  local raw_roots="$1"
  local candidate=""

  if [[ -z "${raw_roots}" ]]; then
    return 0
  fi

  while IFS= read -r candidate; do
    candidate="${candidate#"${candidate%%[![:space:]]*}"}"
    candidate="${candidate%"${candidate##*[![:space:]]}"}"
    add_reset_root_if_missing "${candidate}"
  done < <(printf '%s\n' "${raw_roots//;/$'\n'}")
}

collect_reset_roots() {
  RESET_ROOTS=()
  add_reset_root_if_missing "${HOME}/.keri"
  add_reset_root_if_missing "/usr/local/var/keri"
  add_reset_root_if_missing "/opt/homebrew/var/keri"
  add_reset_root_if_missing "/var/keri"
  add_configured_reset_roots "${LOCKSMITH_EXTRA_RESET_ROOTS}"
}

removed=0
missing=0
failed=0

echo "[reset-demo-state] clearing demo state for base '${LOCKSMITH_BASE}'"
collect_reset_roots
stores=(db ks cf rt reg mbx not locksmith)

if [[ "${#RESET_ROOTS[@]}" == "0" ]]; then
  echo "[reset-demo-state] no existing demo state roots found"
  echo "[reset-demo-state] reset summary: removed=0 missing=0 failed=0"
  exit 0
fi

echo "[reset-demo-state] reset roots: ${RESET_ROOTS[*]}"

for root in "${RESET_ROOTS[@]}"; do
  for store in "${stores[@]}"; do
    target="${root}/${store}/${LOCKSMITH_BASE}"
    if [[ -e "${target}" ]]; then
      if ! rm -rf "${target}"; then
        echo "[reset-demo-state] WARNING: failed to remove ${target}" >&2
        failed=$((failed + 1))
      else
        echo "[reset-demo-state] removed ${target}"
        removed=$((removed + 1))
      fi
    else
      missing=$((missing + 1))
    fi
  done
done

echo "[reset-demo-state] reset summary: removed=${removed} missing=${missing} failed=${failed}"
if [[ "${failed}" != "0" ]]; then
  echo "[reset-demo-state] WARNING: reset completed with failed removals. Ensure LockSmith is fully closed and retry." >&2
fi
