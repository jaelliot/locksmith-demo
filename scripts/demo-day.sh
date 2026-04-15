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
# PySide6 6.9.x is incompatible with Python 3.14; prefer 3.13 then 3.12.
if [[ -z "${PYTHON_BIN}" ]]; then
  for candidate in python3.13 python3.12; do
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
if [[ "${PY_VER}" == "3.14" ]]; then
  echo "[demo-day] ERROR: ${PYTHON_BIN} is Python 3.14, which is incompatible with PySide6 6.9.x."
  echo "[demo-day]        Install/use Python 3.13 and re-run, or set:"
  echo "[demo-day]        PYTHON_BIN=python3.13 ./scripts/demo-day.sh"
  exit 1
fi

echo "[demo-day] using ${PYTHON_BIN} (${PY_VER})"
cd "${REPO_ROOT}"

# ── Virtual environment ───────────────────────────────────────────────────────
if [[ ! -d ".venv" ]]; then
  echo "[demo-day] creating virtual environment"
  eval "${PYTHON_BIN}" -m venv .venv
fi

VENV_VER="$(.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "${VENV_VER}" == "3.14" ]]; then
  echo "[demo-day] existing .venv is Python 3.14; recreating with ${PYTHON_BIN}"
  rm -rf .venv
  eval "${PYTHON_BIN}" -m venv .venv
fi

# ── Install ───────────────────────────────────────────────────────────────────
echo "[demo-day] installing dependencies (editable + dev extras)"
.venv/bin/python -m pip install --upgrade pip --quiet
.venv/bin/python -m pip install -e ".[dev]" --quiet

# ── Qt resources ─────────────────────────────────────────────────────────────
echo "[demo-day] refreshing Qt resources"
.venv/bin/python ./scripts/generate_qrc.py
.venv/bin/pyside6-rcc resources.qrc -o resources_rc.py
mv resources_rc.py ./src/locksmith/resources_rc.py

# ── Smoke tests ───────────────────────────────────────────────────────────────
echo "[demo-day] running smoke tests"
QT_QPA_PLATFORM=offscreen .venv/bin/pytest tests/ -v --tb=short

if [[ "${SETUP_ONLY}" == "1" ]]; then
  echo "[demo-day] preflight complete (SETUP_ONLY=1) — ready to demo"
  exit 0
fi

# ── Launch ────────────────────────────────────────────────────────────────────
echo "[demo-day] launching LockSmith"
exec .venv/bin/python ./src/locksmith/main.py
