# LockSmith Demo

Self-contained demo snapshot of LockSmith, the KERI Foundation desktop wallet.

This repo is meant to answer one question quickly: can someone clone one repo, run a preflight, and open the desktop wallet without stitching together upstream dependencies by hand?

## Current Status

- Native macOS launch is verified with Python 3.13.
- The bootstrap preflight currently passes `7` smoke tests.
- Windows native PowerShell is the intended Windows lane.
- Docker is useful for headless proof only, not GUI launch.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/jaelliot/locksmith-demo.git
cd locksmith-demo
```

### 2. Run preflight

- macOS/Linux

```bash
PYTHON_BIN=python3.13 SETUP_ONLY=1 ./scripts/demo-day.sh
```

- Windows PowerShell

```powershell
.\scripts\demo-day.ps1 -PythonBin python3.13 -SetupOnly
```

- Docker headless

```bash
docker build -f Dockerfile.preflight -t locksmith-demo-preflight .
docker run --rm locksmith-demo-preflight
```

Expected result:

```text
7 passed in ...
```

### 3. Launch the app

- macOS/Linux

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

- Windows PowerShell

```powershell
.\scripts\demo-day.ps1 -PythonBin python3.13
```

## What To Do In The App

Once the GUI opens, the current useful demo path is:

1. Create or open a vault.
2. Open Local Identifiers and add a local AID.
3. Inspect Remote Identifiers, Group Identifiers, Credentials, and Settings to confirm the empty-state UI and vault configuration surfaces render correctly.
4. Use Settings to confirm the vault is writable and the browser-plugin identifier surface is present.

This repo currently proves local wallet bootstrap and UI navigation. It does not yet prove a full live credential issuance flow.

## Runtime Notes

- Python 3.13 is required for the pinned PySide6 6.9.x stack.
- Python 3.14 is not supported by this bootstrap.
- Demo launchers default to `LOCKSMITH_BASE=locksmith-demo` so vault discovery is scoped to demo data instead of your full global `~/.keri` history.
- The native launchers create `.venv`, install the editable package plus dev dependencies, regenerate Qt resources, run smoke tests, and then launch the GUI.

## Blank-Slate Demo State

If your vault drawer shows old vaults from previous runs, clear demo-scoped state and relaunch.

- macOS/Linux:

```bash
RESET_DEMO_STATE=1 ./scripts/demo-day.sh
```

- Windows PowerShell:

```powershell
.\scripts\demo-day.ps1 -ResetDemoState
```

## Troubleshooting

### Wrong Python version

Use Python 3.13 explicitly:

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

```powershell
.\scripts\demo-day.ps1 -PythonBin python3.13
```

### `LoadLibrary() argument 1 must be str, not None`

On Windows, this means `pysodium` could not locate `libsodium.dll`. The PowerShell launcher now auto-downloads libsodium from official GitHub releases if the `libsodium/` directory is missing or does not contain required DLL candidates.

The launcher also prepends base CPython runtime directories (`sys.base_prefix` and `sys.base_prefix\\DLLs`) to `PATH` so dependent runtime DLLs are discoverable when using a `uv`-provisioned Python.

The launcher performs an explicit `ctypes.WinDLL(...)` probe against bundled `libsodium` candidates before smoke tests. If this probe fails, it now warns and continues instead of hard-failing immediately.

If you still see this error, re-run setup-only mode in a fresh shell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\demo-day.ps1 -PythonBin python3.13 -SetupOnly
```

### PowerShell execution policy blocks the script

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\demo-day.ps1 -SetupOnly
```

### Windows `libsodium` load failure

If `pysodium` still cannot load `libsodium.dll`, install the Microsoft Visual C++ Redistributable (x64), open a fresh PowerShell session, and rerun preflight.

### Docker GUI expectations

Docker is preflight-only. Use a native host launch for the desktop app.

## Known Limits

- Credential issuance still depends on live witness, registry, and schema infrastructure.
- Smoke tests validate bootstrap and core KERI wiring, not the full conference story.
- WSL2 remains best-effort for GUI behavior; use native Windows PowerShell if presenting from Windows.

## Syncing From Upstream

This repo embeds a point-in-time snapshot under `src/`. If you resync from upstream `libs/locksmith`, rerun preflight before trusting the result.

## License

Apache 2.0. See LICENSE.
