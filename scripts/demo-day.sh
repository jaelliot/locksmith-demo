#!/usr/bin/env bash
# demo-day.sh — set up and launch LockSmith from this self-contained repo.
#
# Usage:
#   ./scripts/demo-day.sh              # install deps and launch
#   SETUP_ONLY=1 ./scripts/demo-day.sh # install + preflight tests, no GUI
#
# Environment overrides:
#   PYTHON_BIN=python3.13    — force a specific interpreter
#   SETUP_ONLY=1             — stop after install + smoke tests, skip launch
#   AUTO_INSTALL_UV=1        — install uv if missing (default: 1)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-}"
SETUP_ONLY="${SETUP_ONLY:-0}"
AUTO_INSTALL_UV="${AUTO_INSTALL_UV:-1}"
LOCKSMITH_BASE="${LOCKSMITH_BASE:-locksmith-demo}"
RESET_DEMO_STATE="${RESET_DEMO_STATE:-0}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-8}"

log() {
  echo "[demo-day] $*"
}

format_elapsed() {
  local total_seconds="$1"
  printf '%02d:%02d' "$((total_seconds / 60))" "$((total_seconds % 60))"
}

run_with_heartbeat() {
  local label="$1"
  shift
  local started_at="${SECONDS}"

  "$@" &
  local pid=$!

  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${HEARTBEAT_SECONDS}"
    if kill -0 "${pid}" 2>/dev/null; then
      local elapsed="$((SECONDS - started_at))"
      log "${label} still running... $(format_elapsed "${elapsed}") elapsed"
    fi
  done

  wait "${pid}"
  local exit_code=$?
  if [[ "${exit_code}" != "0" ]]; then
    return "${exit_code}"
  fi

  local elapsed="$((SECONDS - started_at))"
  log "${label} finished in $(format_elapsed "${elapsed}")"
}

remove_dir_with_heartbeat() {
  local label="$1"
  local target="$2"
  local started_at="${SECONDS}"

  if [[ ! -e "${target}" ]]; then
    return 0
  fi

  rm -rf -- "${target}" &
  local pid=$!

  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${HEARTBEAT_SECONDS}"
    if kill -0 "${pid}" 2>/dev/null; then
      local elapsed="$((SECONDS - started_at))"
      log "${label} still running... $(format_elapsed "${elapsed}") elapsed"
    fi
  done

  wait "${pid}"
  local exit_code=$?
  if [[ "${exit_code}" != "0" ]]; then
    return "${exit_code}"
  fi

  local elapsed="$((SECONDS - started_at))"
  log "${label} finished in $(format_elapsed "${elapsed}")"
}

install_uv_if_needed() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  if [[ "${AUTO_INSTALL_UV}" != "1" ]]; then
    return 1
  fi

  echo "[demo-day] uv not found; attempting automatic install"
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  else
    echo "[demo-day] ERROR: curl is required to auto-install uv"
    return 1
  fi

  if [[ -x "${HOME}/.local/bin/uv" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  command -v uv >/dev/null 2>&1
}

# ── Interpreter selection ─────────────────────────────────────────────────────
# PySide6 6.9.x in this demo is pinned to Python 3.13 for reproducibility.
if [[ -z "${PYTHON_BIN}" ]]; then
  for candidate in python3.13; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      PYTHON_BIN="${candidate}"
      break
    fi
  done
fi

# If no compatible Python is found on PATH, use uv to provision 3.13.
if [[ -z "${PYTHON_BIN}" ]]; then
  if install_uv_if_needed; then
    echo "[demo-day] provisioning Python 3.13 via uv"
    uv python install 3.13 >/dev/null
    PYTHON_BIN="uv run --python 3.13 python"
  fi
fi

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "[demo-day] ERROR: no usable Python found."
  echo "[demo-day] Install Python 3.13 manually, or run with AUTO_INSTALL_UV=1."
  exit 1
fi

if [[ "${PYTHON_BIN}" != uv\ run* ]] && ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "[demo-day] ERROR: PYTHON_BIN is set to '${PYTHON_BIN}' but is not executable on PATH."
  exit 1
fi

if [[ "${PYTHON_BIN}" == uv\ run* ]]; then
  PY_VER="$(uv run --python 3.13 python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
else
  PY_VER="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
fi
if [[ "${PY_VER}" != "3.13" ]]; then
  echo "[demo-day] ERROR: ${PYTHON_BIN} resolved to Python ${PY_VER}."
  echo "[demo-day]        This demo requires Python 3.13 (PySide6 6.9.x compatibility)."
  echo "[demo-day]        Install/use Python 3.13 and re-run, or set:"
  echo "[demo-day]        PYTHON_BIN=python3.13 ./scripts/demo-day.sh"
  exit 1
fi

log "using ${PYTHON_BIN} (${PY_VER})"
cd "${REPO_ROOT}"

export LOCKSMITH_BASE
log "using LOCKSMITH_BASE=${LOCKSMITH_BASE}"

if [[ "${RESET_DEMO_STATE}" == "1" ]]; then
  ./scripts/reset-demo-state.sh
fi

# ── Virtual environment ───────────────────────────────────────────────────────
if [[ ! -d ".venv" ]]; then
  echo "[demo-day] creating virtual environment"
  eval "${PYTHON_BIN}" -m venv .venv
fi

VENV_VER="$(.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "${VENV_VER}" != "3.13" ]]; then
  echo "[demo-day] existing .venv is Python ${VENV_VER}; recreating with ${PYTHON_BIN}"
  log "removing existing virtual environment"
  remove_dir_with_heartbeat "virtual environment cleanup" .venv
  eval "${PYTHON_BIN}" -m venv .venv
fi

# ── Install ───────────────────────────────────────────────────────────────────
log "installing dependencies (editable + dev extras)"
.venv/bin/python -m pip --version >/dev/null 2>&1 || {
  log "pip missing in .venv; bootstrapping with ensurepip"
  .venv/bin/python -m ensurepip --upgrade
}
log "upgrading pip"
run_with_heartbeat "pip upgrade" .venv/bin/python -m pip install --upgrade pip --quiet
log "installing project dependencies"
run_with_heartbeat "dependency install" .venv/bin/python -m pip install -e ".[dev]" --quiet

# ── Qt resources ─────────────────────────────────────────────────────────────
log "refreshing Qt resources"
log "generating resources.qrc"
run_with_heartbeat "resource manifest generation" .venv/bin/python ./scripts/generate_qrc.py
log "compiling Qt resource module"
run_with_heartbeat "Qt resource compilation" .venv/bin/pyside6-rcc resources.qrc -o resources_rc.py
mv resources_rc.py ./src/locksmith/resources_rc.py

# ── Smoke tests ───────────────────────────────────────────────────────────────
log "running smoke tests"
QT_QPA_PLATFORM=offscreen .venv/bin/pytest tests/ -v --tb=short

if [[ "${SETUP_ONLY}" == "1" ]]; then
  log "preflight complete (SETUP_ONLY=1) — ready to demo"
  exit 0
fi

# ── Launch ────────────────────────────────────────────────────────────────────
log "launching LockSmith"
exec .venv/bin/python ./src/locksmith/main.py
