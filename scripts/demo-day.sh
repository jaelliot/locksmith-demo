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
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-}"
SETUP_ONLY="${SETUP_ONLY:-0}"

# ── Interpreter selection ─────────────────────────────────────────────────────
# PySide6 6.9.x is incompatible with Python 3.14; prefer 3.13 then 3.12.
if [[ -z "${PYTHON_BIN}" ]]; then
  for candidate in python3.13 python3.12 python3; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      PYTHON_BIN="${candidate}"
      break
    fi
  done
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "[demo-day] ERROR: no usable Python found. Install Python 3.13 or set PYTHON_BIN."
  exit 1
fi

PY_VER="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "${PY_VER}" == "3.14" ]]; then
  echo "[demo-day] ERROR: ${PYTHON_BIN} is Python 3.14, which is incompatible with PySide6 6.9.x."
  echo "[demo-day]        Install Python 3.13 (brew install python@3.13) and re-run, or set:"
  echo "[demo-day]        PYTHON_BIN=python3.13 ./scripts/demo-day.sh"
  exit 1
fi

echo "[demo-day] using ${PYTHON_BIN} (${PY_VER})"
cd "${REPO_ROOT}"

# ── Virtual environment ───────────────────────────────────────────────────────
if [[ ! -d ".venv" ]]; then
  echo "[demo-day] creating virtual environment"
  "${PYTHON_BIN}" -m venv .venv
fi

VENV_VER="$(.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "${VENV_VER}" == "3.14" ]]; then
  echo "[demo-day] existing .venv is Python 3.14; recreating with ${PYTHON_BIN}"
  rm -rf .venv
  "${PYTHON_BIN}" -m venv .venv
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
