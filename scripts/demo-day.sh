#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCKSMITH_DIR="${LOCKSMITH_DIR:-${DEMO_ROOT}/../locksmith}"
LOCKSMITH_REMOTE="${LOCKSMITH_REMOTE:-git@github.com:jaelliot/locksmith.git}"
PYTHON_BIN="${PYTHON_BIN:-}"
SETUP_ONLY="${SETUP_ONLY:-0}"
UPDATE_LOCKSMITH="${UPDATE_LOCKSMITH:-0}"

if [[ -z "${PYTHON_BIN}" ]]; then
  if command -v python3.13 >/dev/null 2>&1; then
    PYTHON_BIN="python3.13"
  elif command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN="python3.12"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  fi
fi

if [[ ! -d "${LOCKSMITH_DIR}" ]]; then
  echo "[demo-day] locksmith repo not found at ${LOCKSMITH_DIR}"
  echo "[demo-day] cloning ${LOCKSMITH_REMOTE}"
  git clone "${LOCKSMITH_REMOTE}" "${LOCKSMITH_DIR}"
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "[demo-day] ${PYTHON_BIN} not found. Set PYTHON_BIN or install Python 3.12+."
  exit 1
fi

echo "[demo-day] using locksmith repo: ${LOCKSMITH_DIR}"

pushd "${LOCKSMITH_DIR}" >/dev/null

if [[ "${UPDATE_LOCKSMITH}" == "1" ]]; then
  echo "[demo-day] pulling latest locksmith changes"
  git pull --ff-only
fi

if [[ ! -d ".venv" ]]; then
  echo "[demo-day] creating virtual environment"
  "${PYTHON_BIN}" -m venv .venv
fi

VENV_PY_VER="$(./.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "${VENV_PY_VER}" == "3.14" ]]; then
  echo "[demo-day] existing .venv uses Python 3.14, recreating for PySide6 compatibility"
  rm -rf .venv
  "${PYTHON_BIN}" -m venv .venv
fi

echo "[demo-day] installing locksmith in editable mode"
./.venv/bin/python -m pip install --upgrade pip >/dev/null
./.venv/bin/python -m pip install -e .

echo "[demo-day] refreshing Qt resources"
./.venv/bin/python ./scripts/generate_qrc.py
./.venv/bin/pyside6-rcc resources.qrc -o resources_rc.py
mv resources_rc.py ./src/locksmith/resources_rc.py

if [[ "${SETUP_ONLY}" == "1" ]]; then
  echo "[demo-day] setup complete (SETUP_ONLY=1), exiting before launch"
  exit 0
fi

echo "[demo-day] launching locksmith"
exec ./.venv/bin/python ./src/locksmith/main.py
