# locksmith-demo

Demo-day workflow for running the KERI Foundation LockSmith wallet from a clean machine with minimal steps.

## Goal

This repo gives you one stable command you can run before or during the conference demo:

```bash
./scripts/demo-day.sh
```

The script will:

1. Clone LockSmith (if missing)
2. Create a local virtual environment
3. Install LockSmith in editable mode
4. Regenerate Qt resources
5. Launch the app

## Prerequisites

- macOS (conference host environment)
- Python 3.13 preferred (LockSmith currently pins PySide6 6.9.2)
- Git
- Internet access (first run only)

## Quick Start

From this repo root:

```bash
chmod +x ./scripts/demo-day.sh
./scripts/demo-day.sh
```

If you want to preflight setup without opening the app window:

```bash
SETUP_ONLY=1 ./scripts/demo-day.sh
```

## Optional Environment Variables

You can override defaults if needed:

```bash
LOCKSMITH_DIR=/custom/path/to/locksmith \
LOCKSMITH_REMOTE=git@github.com:jaelliot/locksmith.git \
PYTHON_BIN=python3.13 \
UPDATE_LOCKSMITH=1 \
./scripts/demo-day.sh
```

Interpreter selection order when PYTHON_BIN is not set:

1. python3.13
2. python3.12
3. python3

## Suggested Demo-Day Runbook

1. Run the script once before your live session to warm dependencies and verify launch.
2. Keep the same checkout and virtual environment for the live demo.
3. Re-run the same command for predictable startup.
4. If you need to pull latest changes quickly:

```bash
cd ../locksmith
git pull --ff-only
cd ../locksmith-demo
./scripts/demo-day.sh
```

## Troubleshooting

- pyside6-rcc not found:
	- Re-run the script. It installs dependencies into .venv and should provide pyside6-rcc.
- Python 3.12 not found:
	- Install Python 3.12+ and set PYTHON_BIN accordingly.
- Clone failed due to SSH:
	- Set LOCKSMITH_REMOTE to HTTPS URL if SSH keys are unavailable.
