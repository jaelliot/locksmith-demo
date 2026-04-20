# LockSmith Demo

Self-contained demo snapshot of LockSmith, the KERI Foundation desktop wallet.

This repo is meant to answer one question quickly: can someone clone one repo, run a preflight, and open the desktop wallet without stitching together upstream dependencies by hand?

## Current Status

- Native macOS launch is verified with Python 3.13.
- The bootstrap preflight currently passes `7` smoke tests.
- Windows native PowerShell is the intended Windows lane.
- Docker is useful for headless proof only, not GUI launch.

## Cross-Platform Prerequisites

### macOS

- **Python 3.13** (install via Homebrew, `pyenv`, or `uv`)
  ```bash
  brew install python@3.13
  # or
  uv python install 3.13
  ```
- **Git**
- A recent **Xcode Command Line Tools** (for native compilation of dependencies)
  ```bash
  xcode-select --install
  ```

### Linux (Ubuntu/Debian-based)

- **Python 3.13**
  ```bash
  sudo apt update
  sudo apt install python3.13 python3.13-venv python3.13-dev
  ```
- **Git** and build essentials
  ```bash
  sudo apt install git build-essential libssl-dev libffi-dev
  ```

### Windows

- **Python 3.13 (x64)** from [python.org](https://www.python.org/downloads/) (recommended)
- **Optional:** `uv` (only needed if you want the script to auto-provision Python)
  ```powershell
  uv python install 3.13
  ```
- **Git for Windows**
- **PowerShell 5.1 or later** (built-in on Windows 10/11)
- **Microsoft Visual C++ Redistributable (x64)** (auto-downloaded by launcher if needed)

## Quick Start

### 1. Clone

```bash
git clone https://github.com/jaelliot/locksmith-demo.git
cd locksmith-demo
```

### 2. Run preflight

> Use commands from the section that matches your shell. `PYTHON_BIN=... ./scripts/demo-day.sh` is for macOS/Linux shells, not PowerShell.

- macOS/Linux

```bash
PYTHON_BIN=python3.13 SETUP_ONLY=1 ./scripts/demo-day.sh
```

- Windows (Command Prompt or PowerShell — recommended)

```bat
scripts\demo-day.cmd -SetupOnly
```

If you launch from a `\\wsl.localhost\...` path, `scripts\demo-day.cmd` may still show one `cmd.exe` UNC warning before continuing. That message comes from `cmd.exe` itself before the wrapper starts. If you want a clean Windows launch from a UNC-backed repo, invoke [`scripts/demo-day.ps1`](scripts/demo-day.ps1) directly with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-day.ps1 -SetupOnly`.

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

- Windows

```bat
scripts\demo-day.cmd
```

Same as preflight: you can use [`scripts/demo-day.ps1`](scripts/demo-day.ps1) directly if your execution policy allows it, or invoke it with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-day.ps1`.

## Participant Command Cheat Sheet

Use this section if you just need the right command for your machine during the conference.

| Task | macOS/Linux | Windows |
|--------|----------------|----------------|
| Verify setup only | `PYTHON_BIN=python3.13 SETUP_ONLY=1 ./scripts/demo-day.sh` | `scripts\demo-day.cmd -SetupOnly` |
| Launch app | `PYTHON_BIN=python3.13 ./scripts/demo-day.sh` | `scripts\demo-day.cmd` |
| Preview cleanup | `make locksmith-clean-preview` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-demo.ps1 -WhatIf` |
| Clean demo files + state | `make locksmith-clean` | `scripts\cleanup-demo.cmd` |

If you are on Windows in a `\\wsl.localhost\...` checkout, the `scripts\demo-day.cmd` and `scripts\cleanup-demo.cmd` wrappers may still show one `cmd.exe` UNC warning before continuing. That is expected.

## Conference breakout: follow-along

Use this for KERICONF-style demos or any session where attendees might run the demo alongside you. Full detail and timing are in **[Demo Walkthrough](#demo-walkthrough)** below; this section is the short path.

**Presenter (macOS / Linux)**

1. Clone this repo and `cd` into it (see [Quick Start](#quick-start)).
2. Run `make locksmith-up` from the repo root (see [Makefile](#makefile-unixmacoslinux)) — installs dependencies, regenerates Qt resources, runs smoke tests (`7 passed`), then launches the GUI. Override with `PYTHON_BIN=python3.13` if needed.
3. On stage, follow the **Short live-demo script** below or the full **Demo Walkthrough**.

**Audience**

- **Watch-only** is fine if Wi‑Fi or time is limited.
- **Hands-on:** same clone and Python 3.13. Run `make locksmith-verify` to run setup and tests **without** opening the GUI (faster check). For the full app, use `make locksmith-up` or `./scripts/demo-day.sh` (Unix) / `scripts\demo-day.cmd` (Windows).

**Short live-demo script (~5–7 minutes)**

1. **Home** → click **Vaults** in the top toolbar. The vault list appears in a **drawer from the right**.
2. Choose a vault (or **Initialize New Vault** first), then **Open** and enter the passcode.
3. After unlock, use the **left** navigation: **Local Identifiers** → **+ Add Identifier** to create a local AID (or show one you created in rehearsal).
4. Skim **Remote Identifiers**, **Group Identifiers**, **Issued** / **Received** credentials, and **Credential Schemas** — mostly empty states are normal unless you have seeded data.
5. Optional: **Settings** for configuration placeholders and vault metadata.

**Reset between runs (Unix)**

Quit the app, then `make locksmith-down` and `make locksmith-reset-state` (or the **Blank-Slate Demo State** flow). See [Blank-Slate Demo State](#blank-slate-demo-state).

## Demo Walkthrough

Once the GUI opens, follow this guided tour:

### 1. Vault Unlock (30 seconds)

- The app opens to the **home** screen. Click **Vaults** in the top toolbar to open the vault list (**drawer from the right**).
- You will see existing vault names (for example a vault you created earlier) or use **Initialize New Vault**.
- Choose a vault, then **Open**, and enter the passcode (or follow your rehearsal defaults).
- Expected: Unlock succeeds; the **left** sidebar shows **Settings**, **Identifiers**, **Credentials**, **Schemas**, **Notifications** for the unlocked vault.

### 2. Local Identifiers (1 minute)

- Click **Local Identifiers** in the left sidebar.
- First time you may see **NO LOCAL IDENTIFIERS**; after you create one, it appears in the list.
- Optionally, click **+ Add Identifier** to create a new local AID. This proves the creation flow works.
- Expected: Form opens to let you name and configure a new identifier.

### 3. View Remote and Group Identifiers (1 minute)

- Click **Remote Identifiers**, expect empty state with "NO REMOTE IDENTIFIERS".
- Click **Group Identifiers**, expect empty state with "NO GROUP IDENTIFIERS".
- These surfaces validate that the UI correctly renders unpopulated data states.

### 4. Credentials and Schemas (1 minute)

- Click **Issued Credentials**, expect "NO ISSUED CREDENTIALS".
- Click **Received Credentials**, expect "NO RECEIVED CREDENTIALS".
- Click **Credential Schemas**, expect "NO CREDENTIAL SCHEMAS".
- These are read-only views for the demo (live issuance requires external witness/schema infrastructure not included).

### 5. Notifications (30 seconds)

- Click **Notifications**.
- You will see a **search bar** at the top. Notifications feature is not yet live in the demo; this is placeholder UI.
- Expected: Search bar displays; no notifications listed (expected state).

### 6. Configuration and Settings (1 minute)

- Click **Settings** in the left sidebar.
- Scroll to the bottom to see **Configuration** or open the **Configuration modal** if available.
- Inspect the six configuration fields:
  - **Root AID**
  - **Root OOBI**
  - **API AID**
  - **API OOBI**
  - **Registration URL**
  - **API URL**
- If these are empty, you will see: `"Not configured (set LOCKSMITH_ROOT_AID)"` etc. in **muted gray text**.
- These fields can optionally be pre-populated via environment variables (see **Optional Presenter Pre-Population** below).

### 7. Vault Settings (30 seconds)

- Also under **Settings**, view the **Vault Settings** card:
  - **Database Directory Base**: Shows where local vault data is stored (e.g., `/tmp/keri-locksmith-demo` or similar).
  - **Key Salt**: A random value used to derive encryption keys for the vault.
- This confirms the vault is writable and bootstrapped correctly.

**What This Proves:**
- ✅ Desktop app launches and initializes all UI subsystems.
- ✅ Vault unlock (password) flow works.
- ✅ Navigation and empty-state rendering work correctly.
- ✅ Configuration surfaces are ready for live provider connection (with env var seeding).
- ❌ **Not yet supported**: Live credential issuance (requires external witness, registry, schema resolver).

**Total Time:** ~5 minutes for a complete walkthrough.

## Runtime Notes

- Python 3.13 is required for the pinned PySide6 6.9.x stack.
- Python 3.14 is not supported by this bootstrap.
- Demo launchers default to `LOCKSMITH_BASE=locksmith-demo` so vault discovery is scoped to demo data instead of your full global `~/.keri` history.
- The native launchers create `.venv`, install the editable package plus dev dependencies, regenerate Qt resources, run smoke tests, and then launch the GUI.
- Cross-platform parity and open follow-up items are tracked in `GAPS.md`.

## Makefile (Unix/macOS/Linux)

The repo root includes a [`Makefile`](Makefile) for common demo workflows (same idea as the Fort-ios app Makefile). **Native Windows** presenters should use [`scripts/demo-day.cmd`](scripts/demo-day.cmd) (or [`scripts/demo-day.ps1`](scripts/demo-day.ps1) with a suitable execution policy) instead of `make`.

Optional variables: `LOCKSMITH_BASE` (default `locksmith-demo`), `PYTHON_BIN` (e.g. `python3.13`).

| Target | What it does |
|--------|----------------|
| `make help` | List targets |
| `make locksmith-up` | Install deps, refresh Qt resources, run smoke tests, launch the GUI (wraps `scripts/demo-day.sh`) |
| `make locksmith-down` | Best-effort stop of a dev-launched LockSmith (`pkill` matches `.../src/locksmith/main.py`) |
| `make locksmith-reset-state` | Delete on-disk demo data for the current `LOCKSMITH_BASE` via [`scripts/reset-demo-state.sh`](scripts/reset-demo-state.sh) |
| `make locksmith-clean` | Remove `.venv`, test/cache artifacts, temporary download folders, and reset current `LOCKSMITH_BASE` demo state via [`scripts/cleanup-demo.sh`](scripts/cleanup-demo.sh) |
| `make locksmith-clean-preview` | Preview the cleanup plan without deleting anything (`DRY_RUN=1`) |
| `make locksmith-verify` | Same bootstrap as `locksmith-up` but `SETUP_ONLY=1` (no GUI) — use after a reset to confirm tests pass |

Examples:

```bash
make locksmith-down
make locksmith-reset-state
make locksmith-clean-preview
make locksmith-clean
make locksmith-verify
make locksmith-up
```

## Cleanup / Teardown

Use the cleanup script when you want to reverse the local demo setup without manually hunting through files. It removes the local virtual environment, common test/cache artifacts, temporary libsodium download folders, and the current `LOCKSMITH_BASE` demo state. It leaves the cloned source tree intact.

- macOS/Linux:

```bash
./scripts/cleanup-demo.sh
```

- macOS/Linux dry run:

```bash
DRY_RUN=1 ./scripts/cleanup-demo.sh
```

- macOS/Linux via Makefile:

```bash
make locksmith-clean-preview
```

- Windows:

```bat
scripts\cleanup-demo.cmd
```

- Windows PowerShell preview (same idea as `make locksmith-clean-preview`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-demo.ps1 -WhatIf
```

If you only want to keep on-disk demo state and remove the Python environment/caches, use `KEEP_DEMO_STATE=1 ./scripts/cleanup-demo.sh` on macOS/Linux or `-KeepDemoState` with [`scripts/cleanup-demo.ps1`](scripts/cleanup-demo.ps1) on Windows.

If a workstation keeps KERI data under additional roots, append them with `LOCKSMITH_EXTRA_RESET_ROOTS`. Use a semicolon-separated list in both shells. Example on macOS/Linux: `LOCKSMITH_EXTRA_RESET_ROOTS="/srv/keri;/opt/demo-keri" ./scripts/reset-demo-state.sh`. Example in PowerShell: `$env:LOCKSMITH_EXTRA_RESET_ROOTS = 'C:\demo\keri;\\server\share\keri'` before running [`scripts/cleanup-demo.ps1`](scripts/cleanup-demo.ps1) or [`scripts/demo-day.ps1`](scripts/demo-day.ps1).

## Blank-Slate Demo State

If your vault drawer shows old vaults from previous runs, run the reset + verify flow below.

**Default data scope:** If `LOCKSMITH_BASE` is not set in the environment, the app defaults to `locksmith-demo`, so the vault list only shows haberies under `~/.keri/db/locksmith-demo/` (not every top-level folder under `~/.keri/db/`). Older runs that wrote directly under `~/.keri/db/<name>/` without that segment can leave folders on disk; they will not appear in the drawer once scoped.

Close LockSmith fully before reset (including any background terminal run). Use `make locksmith-down` or quit the app so files are not locked. Reset removes `LOCKSMITH_BASE`-scoped records from all known KERI roots for the current platform, including `~/.keri`, `/usr/local/var/keri`, `/opt/homebrew/var/keri`, `/var/keri`, and the `db`, `ks`, `cf`, `rt`, `reg`, `mbx`, `not`, and `locksmith` stores beneath them (see [`scripts/reset-demo-state.sh`](scripts/reset-demo-state.sh)). If a particular machine uses additional roots, add them with `LOCKSMITH_EXTRA_RESET_ROOTS`.

### Reset + Verify

1. **Run reset**

- macOS/Linux (recommended): from the repo root, `make locksmith-reset-state`, or run the script directly:
```bash
./scripts/reset-demo-state.sh
```

- macOS/Linux (reset then full launcher with `RESET_DEMO_STATE=1` still works — it invokes the same script):
```bash
RESET_DEMO_STATE=1 ./scripts/demo-day.sh
```

- Windows:
```bat
scripts\demo-day.cmd -ResetDemoState
```

2. **Run setup-only verify**

- macOS/Linux:
```bash
make locksmith-verify
```

Or, combining reset with a one-shot launcher:

```bash
RESET_DEMO_STATE=1 SETUP_ONLY=1 ./scripts/demo-day.sh
```

- Windows:
```bat
scripts\demo-day.cmd -ResetDemoState -SetupOnly
```

3. **Confirm reset summary in logs**

```text
[reset-demo-state] reset roots: <root1> <root2> ...
[reset-demo-state] reset summary: removed=<N> missing=<N> failed=0
```

If `failed` is non-zero, close all running LockSmith processes (`make locksmith-down` on Unix), ensure nothing else holds those directories open, and rerun reset.

### Troubleshooting: "Last seed" / authentication error when initializing a vault

If **Initialize New Vault** fails with an error mentioning **last seed**, **aeid**, or **Authentication error** from the keystore, the usual cause is **on-disk state** for that vault name (or a corrupted/partial store) that does not match the passcode you entered—often after earlier experiments or an interrupted run.

1. **Use a blank slate** — run the [Reset + Verify](#reset--verify) flow above, then launch again and create a vault with a **new unique name** and a **passcode of at least 21 characters** (required by the KERI `Habery` setup path).
2. **Avoid reusing a name** tied to old data until you have reset or removed that vault’s directories under your configured base (`LOCKSMITH_BASE`, default `locksmith-demo`).
3. **Quit the app** before reset or manual deletion of vault data so files are not locked.

The upstream error originates in the keystore `Manager` when an existing encrypted id (`aeid`) does not match the seed derived from the current passcode—not a UI-only bug.

## Optional Presenter Pre-Population

The Configuration modal reflects startup config values. If provider fields are empty,
the UI now shows an explicit "Not configured" placeholder with the expected env var.

If you want those fields populated during a demo, export values before launch.

- macOS/Linux:

```bash
export LOCKSMITH_ROOT_AID="<root-aid>"
export LOCKSMITH_API_AID="<api-aid>"
export LOCKSMITH_ROOT_OOBI="<root-oobi-url>"
export LOCKSMITH_API_OOBI="<api-oobi-url>"
export LOCKSMITH_UNPROTECTED_URL="<registration-url>"
export LOCKSMITH_PROTECTED_URL="<api-url>"
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

- Windows (set env vars in PowerShell, then run the launcher from **Command Prompt** or **PowerShell**):

```powershell
$env:LOCKSMITH_ROOT_AID = "<root-aid>"
$env:LOCKSMITH_API_AID = "<api-aid>"
$env:LOCKSMITH_ROOT_OOBI = "<root-oobi-url>"
$env:LOCKSMITH_API_OOBI = "<api-oobi-url>"
$env:LOCKSMITH_UNPROTECTED_URL = "<registration-url>"
$env:LOCKSMITH_PROTECTED_URL = "<api-url>"
```

```bat
scripts\demo-day.cmd
```

### Configuration Variable Reference

| Environment Variable | UI Field | Purpose | Example |
|---|---|---|---|
| `LOCKSMITH_ROOT_AID` | Root AID | KERI Autonomic Identifier (AID) of the root provider | `EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q` |
| `LOCKSMITH_ROOT_OOBI` | Root OOBI | Out-of-Band Introduction URL for the root provider | `http://localhost:8080/oobi` |
| `LOCKSMITH_API_AID` | API AID | AID used for API authentication / protected routes | `EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q` |
| `LOCKSMITH_API_OOBI` | API OOBI | OOBI URL for the API provider | `http://localhost:8080/api/oobi` |
| `LOCKSMITH_UNPROTECTED_URL` | Registration URL | Base URL for public registration endpoints | `http://localhost:8080/register` |
| `LOCKSMITH_PROTECTED_URL` | API URL | Base URL for authenticated API endpoints | `http://localhost:8080/api` |

**For Demo Use:** If you are using a live witness or schema registry on your local network, populate these with real values from your infrastructure. Otherwise, leave them empty (the "Not configured" placeholder is correct and expected).

## Sample Demo Configuration (For Follow-Along Audiences)

If attendees want to clone this repo and follow along on their own machines (Windows, macOS, or Linux), they can use these steps:

### On Your Machine (Presenter)

1. **Clone the repo:**
   ```bash
   git clone https://github.com/jaelliot/locksmith-demo.git
   cd locksmith-demo
   ```

2. **Run preflight** to validate your platform:
   ```bash
   # macOS/Linux
   PYTHON_BIN=python3.13 SETUP_ONLY=1 ./scripts/demo-day.sh
   
   # Windows
   scripts\demo-day.cmd -SetupOnly
   ```

3. **Launch the app:**
   ```bash
   # macOS/Linux
   PYTHON_BIN=python3.13 ./scripts/demo-day.sh
   
   # Windows
   scripts\demo-day.cmd
   ```

4. **Follow the Demo Walkthrough** (see section above).

### Optional: Pre-Populate Configuration for Rehearsal

If you want to screenshots or video with configuration fields populated, use the environment variables before launch:

**Shell (macOS/Linux):**
```bash
export LOCKSMITH_ROOT_AID="EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
export LOCKSMITH_ROOT_OOBI="http://localhost:8080/oobi"
export LOCKSMITH_API_AID="EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
export LOCKSMITH_API_OOBI="http://localhost:8080/api/oobi"
export LOCKSMITH_UNPROTECTED_URL="http://localhost:8080/register"
export LOCKSMITH_PROTECTED_URL="http://localhost:8080/api"
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

**Windows (env vars in PowerShell, then launcher):**
```powershell
$env:LOCKSMITH_ROOT_AID = "EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
$env:LOCKSMITH_ROOT_OOBI = "http://localhost:8080/oobi"
$env:LOCKSMITH_API_AID = "EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
$env:LOCKSMITH_API_OOBI = "http://localhost:8080/api/oobi"
$env:LOCKSMITH_UNPROTECTED_URL = "http://localhost:8080/register"
$env:LOCKSMITH_PROTECTED_URL = "http://localhost:8080/api"
```

```bat
scripts\demo-day.cmd
```

> **Note:** These are example values. Replace with real values from your witness/registry infrastructure if you have one running. For a "clean slate" demo, leaving the fields "Not configured" is perfectly fine—it shows a realistic default state.

## Demo Day Rehearsal Checklist

Run through this 10-minute checklist **on presentation day** (before you demo):

- [ ] **1. Fresh setup** (5 min): Complete the **Reset + Verify** flow in the **Blank-Slate Demo State** section and confirm reset summary shows `failed=0`.
- [ ] **2. App launch** (1 min): Verify the GUI opens without errors.
- [ ] **3. Vault unlock** (1 min): Click unlock, enter password (or press Enter for default), confirm vault opens.
- [ ] **4. Walkthrough flow** (3 min): Walk through sections in order: Local ID → Remote ID → Group ID → Credentials → Schemas → Notifications → Settings → Configuration.
- [ ] **5. Verify expected states** (1 min): Confirm all list views show empty state UI (e.g., "NO LOCAL IDENTIFIERS").
- [ ] **6. Configuration modal** (1 min): Open Settings → Configuration. Verify fields display correctly (populated or "Not configured" placeholders).
- [ ] **7. Notes app open** (optional): Have this README or a speaker notes document open on a second monitor for reference.
- [ ] **8. Backup**: Optional—take a 30-second screen recording of the happy-path for fallback if live demo encounters issues.

**Total Time:** ~10 minutes.

After this checklist passes, you are ready to demo live.

## Troubleshooting

### Platform-Specific Setup Issues

#### macOS

- **"command not found: python3.13"**: Install Python 3.13 via Homebrew or `uv`:
  ```bash
  brew install python@3.13
  # or
  uv python install 3.13
  # then verify
  python3.13 --version
  ```
- **Xcode Command Line Tools missing**: Run `xcode-select --install` and retry.
- **Vault unlock fails**: Run the **Reset + Verify** flow in **Blank-Slate Demo State** to clear scoped state and confirm reset succeeded.

#### Linux

- **"python3.13: command not found"**: Install via your package manager:
  ```bash
  sudo apt install python3.13 python3.13-venv python3.13-dev
  ```
- **libssl/libffi build failures**: Install development headers:
  ```bash
  sudo apt install libssl-dev libffi-dev build-essential
  ```
- **Window manager issues over remote SSH**: Use X forwarding (`ssh -X`) or prefer running presentation locally.

#### Windows

- **PowerShell execution policy blocks `.\scripts\demo-day.ps1`**: From the repo root, prefer **`scripts\demo-day.cmd`** (it launches PowerShell with a process-scoped `-ExecutionPolicy Bypass` for that run). Alternatives: run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` once in the session, or `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-day.ps1 ...`. If scripts are blocked by **Group Policy**, you may need an IT exception or use WSL/macOS/Linux for this demo.
- **`python3.13` is not on PATH** (common on Windows): The preflight looks for `python3.13`, then `python` if it reports 3.13, then the `py -3.13` launcher, then installs 3.13 via `uv` if available. You can pass a specific executable with `-PythonBin` (for example `-PythonBin python` when `python --version` is 3.13).
- **"python3.13 is not recognized"** when typed in the shell: That is normal; Windows typically exposes `python.exe` or `py.exe`. Install Python 3.13 (x64) from [python.org](https://www.python.org/downloads/) and ensure the installer checks "Add python.exe to PATH", then run `scripts\demo-day.cmd` without relying on a `python3.13` command name.
- **`virtualenv python not found at .venv\Scripts\python.exe`**: The `.venv` folder was almost certainly created on **Linux/WSL** (`bin/python`), not Windows (`Scripts\python.exe`). **`scripts\demo-day.cmd -SetupOnly` always deletes `.venv` first**, then creates a fresh Windows venv (so mixed Linux/Windows checkouts are safe). The launcher also recreates `.venv` when it detects a non-Windows layout or wrong Python version. Under `\\wsl.localhost\...`, removal uses **`wsl rm -rf`** when needed. You can still delete `.venv` manually from WSL (`rm -rf .venv`) if something is stuck.
- **UNC path / `\\wsl.localhost\...`**: `cmd.exe` may warn that UNC paths are not supported as the current directory; PowerShell still resolves the repo from the script path. If anything behaves oddly, open the repo from a **mapped drive letter** or run the demo from **WSL** (`./scripts/demo-day.sh`) instead of Windows against the same folder.
- **libsodium.dll not found**: The launcher now auto-downloads libsodium. If issues persist, install the Microsoft Visual C++ Redistributable (x64).
- **Vault opens but Turret/plugin bridge is unavailable**: On Windows runtimes without Unix-domain sockets (`socket.AF_UNIX`), LockSmith now disables Turret for the current session instead of failing vault open. Core wallet flows continue to work; browser-plugin bridge features are unavailable in that session.

### General Troubleshooting

If you see `uv : The term 'uv' is not recognized...` on Windows, that is okay when Python 3.13 is already installed and available as `python` or `py`. You can run:

```bat
scripts\demo-day.cmd -SetupOnly
scripts\demo-day.cmd
```

Install `uv` only if you specifically want automatic Python provisioning.

Use Python 3.13 explicitly:

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

```bat
scripts\demo-day.cmd
```

```bat
REM optional when `python --version` is 3.13:
REM scripts\demo-day.cmd -PythonBin python
```

### `LoadLibrary() argument 1 must be str, not None`

On Windows, this means `pysodium` could not locate `libsodium.dll`. The PowerShell launcher now auto-downloads libsodium from official GitHub releases if the `libsodium/` directory is missing or does not contain required DLL candidates.

The launcher also prepends base CPython runtime directories (`sys.base_prefix` and `sys.base_prefix\\DLLs`) to `PATH` so dependent runtime DLLs are discoverable when using a `uv`-provisioned Python.

The launcher performs an explicit `ctypes.WinDLL(...)` probe against bundled `libsodium` candidates before smoke tests. If this probe fails, it now warns and continues instead of hard-failing immediately.

If you still see this error, re-run setup-only mode in a fresh shell:

```bat
scripts\demo-day.cmd -SetupOnly
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
