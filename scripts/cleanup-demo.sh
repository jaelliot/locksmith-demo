#!/usr/bin/env bash
# cleanup-demo.sh — remove local demo setup artifacts while leaving the repo clone intact.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCKSMITH_BASE="${LOCKSMITH_BASE:-locksmith-demo}"
KEEP_DEMO_STATE="${KEEP_DEMO_STATE:-0}"
KEEP_VENV="${KEEP_VENV:-0}"
KEEP_CACHES="${KEEP_CACHES:-0}"
KEEP_DOWNLOADS="${KEEP_DOWNLOADS:-0}"
DRY_RUN="${DRY_RUN:-0}"

log() {
  echo "[cleanup-demo] $*"
}

remove_path() {
  local label="$1"
  local target="$2"

  if [[ ! -e "${target}" ]]; then
    log "missing ${label}: ${target}"
    return 0
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "would remove ${label}: ${target}"
    return 0
  fi

  rm -rf -- "${target}"
  log "removed ${label}: ${target}"
}

cd "${REPO_ROOT}"
export LOCKSMITH_BASE
log "using LOCKSMITH_BASE=${LOCKSMITH_BASE}"

if [[ "${KEEP_VENV}" != "1" ]]; then
  remove_path ".venv" "${REPO_ROOT}/.venv"
fi

if [[ "${KEEP_CACHES}" != "1" ]]; then
  remove_path ".pytest_cache" "${REPO_ROOT}/.pytest_cache"
  remove_path ".coverage" "${REPO_ROOT}/.coverage"
fi

if [[ "${KEEP_DOWNLOADS}" != "1" ]]; then
  remove_path "libsodium_download.zip" "${REPO_ROOT}/libsodium_download.zip"
  remove_path "libsodium_temp" "${REPO_ROOT}/libsodium_temp"
fi

if [[ "${KEEP_DEMO_STATE}" != "1" ]]; then
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "would reset demo state via ./scripts/reset-demo-state.sh"
  else
    ./scripts/reset-demo-state.sh
  fi
fi

log "cleanup complete"