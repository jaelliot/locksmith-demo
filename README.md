# LockSmith Demo

Self-contained demo snapshot of LockSmith, the KERI Foundation desktop wallet.

This repository embeds the full LockSmith source so attendees can clone one repo and run.

## Support Model

- Primary lane: Docker headless preflight (most consistent across attendee devices)
- GUI lane: native host launch (macOS/Linux/Windows)
- Windows posture: native PowerShell is the reference path; WSL2 is supported with caveats

## Runtime Constraints

- Python 3.13 is required for reliable PySide6 6.9.x behavior.
- Python 3.14 is not supported by this demo bootstrap.
- Setup assumes internet access (package and runtime downloads).

## Windows Presenter Lane (Recommended)

If you are presenting from a Windows laptop, use native PowerShell, not WSL2, for GUI reliability.

1. Open PowerShell or Windows Terminal (PowerShell profile)
2. Clone and enter the repo
3. Run setup-only preflight:

```powershell
.\scripts\demo-day.ps1 -SetupOnly
```

4. Confirm smoke tests report `7 passed`
5. Launch GUI:

```powershell
.\scripts\demo-day.ps1
```

If execution policy blocks the script, see Troubleshooting below.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/jaelliot/locksmith-demo.git
cd locksmith-demo
```

### 2. Run preflight (recommended first)

Choose one lane:

- Docker headless preflight (primary)

```bash
docker build -f Dockerfile.preflight -t locksmith-demo-preflight .
docker run --rm locksmith-demo-preflight
```

- Native POSIX preflight (macOS/Linux)

```bash
SETUP_ONLY=1 ./scripts/demo-day.sh
```

- Native Windows preflight (PowerShell)

```powershell
.\scripts\demo-day.ps1 -SetupOnly
```

Expected test summary:

```text
7 passed in ...
```

### 3. Launch GUI (native host)

- macOS/Linux

```bash
./scripts/demo-day.sh
```

- Windows PowerShell

```powershell
.\scripts\demo-day.ps1
```

## Device Matrix

| Environment | Preflight | GUI Launch | Notes |
|---|---|---|---|
| Docker Desktop (Windows/macOS/Linux) | Yes (primary) | No | Deterministic smoke tests only |
| macOS native | Yes | Yes | Recommended presenter lane |
| Linux native | Yes | Yes | Requires desktop/display stack |
| Windows native (PowerShell) | Yes | Yes | Reference Windows lane |
| WSL2 | Yes | Best-effort | Prefer native Windows for conference GUI reliability |

## Script Behavior

Both launchers perform the same flow:

1. Locate Python 3.13
2. If unavailable, install `uv` (unless disabled) and provision Python 3.13
3. Create or refresh `.venv`
4. Install editable package and dev dependencies
5. Regenerate Qt resources
6. Run smoke tests
7. Launch GUI unless setup-only mode is requested

### POSIX launcher

- File: `scripts/demo-day.sh`
- Setup-only: `SETUP_ONLY=1 ./scripts/demo-day.sh`
- Disable auto uv install: `AUTO_INSTALL_UV=0 ./scripts/demo-day.sh`

### PowerShell launcher

- File: `scripts/demo-day.ps1`
- Setup-only: `.\scripts\demo-day.ps1 -SetupOnly`
- Disable auto uv install: `.\scripts\demo-day.ps1 -NoAutoInstallUv`
- Force interpreter: `.\scripts\demo-day.ps1 -PythonBin python3.13`

### Windows prep shortcut

Run preflight and GUI from one native PowerShell session:

```powershell
Set-Location <path-to-locksmith-demo>
.\scripts\demo-day.ps1 -SetupOnly
.\scripts\demo-day.ps1
```

## Known Limitations

- Credential issuance requires a live witness pool and active ACDC schema/registry infrastructure.
- Smoke tests validate core KERI wiring and app bootstrap, not full credential issuance end-to-end.
- WSL2 display and filesystem semantics may differ from native Windows behavior.

## Demo Walkthrough

1. Launch LockSmith.
2. Create a new identifier.
3. Incept the AID with default witnesses.
4. Explain architecture:
5. PySide6 provides UI.
6. keripy handles KERI logic and key event workflows.
7. hio handles asynchronous task orchestration.

## Troubleshooting

### Python 3.14 errors

Use Python 3.13 explicitly.

Python 3.12 is also rejected by the PowerShell launcher to avoid non-reproducible conference setups.

- POSIX:

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

- PowerShell:

```powershell
.\scripts\demo-day.ps1 -PythonBin python3.13
```

### `pyside6-rcc` not found

The launcher installs dependencies into `.venv` and invokes the tool from that venv. Re-run setup-only mode.

### `No module named pip`

The launchers now auto-bootstrap `pip` inside `.venv` via `ensurepip` before dependency installation. Re-run setup-only mode:

```powershell
.\scripts\demo-day.ps1 -SetupOnly
```

### Docker cannot open GUI

Expected behavior. Docker lane is headless preflight only. Use native host launcher for GUI.

### WSL2 GUI instability

Use WSL2 for preflight checks and switch to native Windows PowerShell for conference GUI launch.

### Script cannot run due to execution policy

If you see a policy error, run this in the same PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\demo-day.ps1 -SetupOnly
```

This affects only the current shell and does not change system-wide policy.

## Save and Commit Checklist

Use this before conference day so local edits are not lost:

1. Verify repo status:

```bash
git status -sb
```

2. Commit demo repo updates:

```bash
git add -A
git commit -m "docs: expand PowerShell runbook and prep checklist"
```

3. Push main:

```bash
git push origin main
```

4. If you also updated private planning notes (daily summary, prep docs), commit and push those in the `projects/private-tools/billing-ops-tasks` repo separately.

## Keeping in Sync with Upstream

This repo embeds a point-in-time source snapshot under `src/`.

```bash
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.egg-info' \
  ../locksmith/src/ ./src/
```

Then rerun preflight and commit the sync.

## License

Apache 2.0. See LICENSE.
