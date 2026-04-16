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

- Windows PowerShell

```powershell
.\scripts\demo-day.ps1 -SetupOnly
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
.\scripts\demo-day.ps1
```

## Demo Walkthrough

Once the GUI opens, follow this guided tour:

### 1. Vault Unlock (30 seconds)

- The app opens to the **Vault drawer** (left sidebar).
- You will see "**Vault Jay**" or similar (name from local machine).
- Click the **lock icon** to unlock the vault and enter the password you created (or press Enter if using default demo data).
- Expected: Unlock succeeds, vault drawer expands to show **Settings**, **Identifiers**, **Credentials**, **Schemas**, **Notifications**.

### 2. Local Identifiers (1 minute)

- Click **Local Identifiers** in the left sidebar.
- You will see an **empty state** with "NO LOCAL IDENTIFIERS" (first time setup).
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

## Blank-Slate Demo State

If your vault drawer shows old vaults from previous runs, run the reset + verify flow below.

Close LockSmith fully before reset (including any background terminal run). Reset removes `LOCKSMITH_BASE`-scoped records from both home and `/usr/local/var/keri` roots, including `db`, `ks`, `cf`, `rt`, `reg`, `mbx`, `not`, and `locksmith` stores.

### Reset + Verify

1. **Run reset**

- macOS/Linux:
```bash
RESET_DEMO_STATE=1 ./scripts/demo-day.sh
```

- Windows PowerShell:
```powershell
.\scripts\demo-day.ps1 -ResetDemoState
```

2. **Run setup-only verify**

- macOS/Linux:
```bash
RESET_DEMO_STATE=1 SETUP_ONLY=1 ./scripts/demo-day.sh
```

- Windows PowerShell:
```powershell
.\scripts\demo-day.ps1 -ResetDemoState -SetupOnly
```

3. **Confirm reset summary in logs**

```text
[demo-day] reset summary: removed=<N> missing=<N> failed=0
```

If `failed` is non-zero, close all running LockSmith processes and rerun the same reset command.

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

- Windows PowerShell:

```powershell
$env:LOCKSMITH_ROOT_AID = "<root-aid>"
$env:LOCKSMITH_API_AID = "<api-aid>"
$env:LOCKSMITH_ROOT_OOBI = "<root-oobi-url>"
$env:LOCKSMITH_API_OOBI = "<api-oobi-url>"
$env:LOCKSMITH_UNPROTECTED_URL = "<registration-url>"
$env:LOCKSMITH_PROTECTED_URL = "<api-url>"
.\scripts\demo-day.ps1
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
   
   # Windows PowerShell
   .\scripts\demo-day.ps1 -SetupOnly
   ```

3. **Launch the app:**
   ```bash
   # macOS/Linux
   PYTHON_BIN=python3.13 ./scripts/demo-day.sh
   
   # Windows PowerShell
   .\scripts\demo-day.ps1
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

**PowerShell (Windows):**
```powershell
$env:LOCKSMITH_ROOT_AID = "EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
$env:LOCKSMITH_ROOT_OOBI = "http://localhost:8080/oobi"
$env:LOCKSMITH_API_AID = "EB0a3Zm8yKHjXHHPzFcYQ0N_7Dxq2ZoFXnwJgfKoXo0Q"
$env:LOCKSMITH_API_OOBI = "http://localhost:8080/api/oobi"
$env:LOCKSMITH_UNPROTECTED_URL = "http://localhost:8080/register"
$env:LOCKSMITH_PROTECTED_URL = "http://localhost:8080/api"
.\scripts\demo-day.ps1
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

- **PowerShell execution policy blocks script**: Run once to unblock:
  ```powershell
  Set-ExecutionPolicy -Scope Process Bypass
  ```
- **`python3.13` is not on PATH** (common on Windows): The preflight looks for `python3.13`, then `python` if it reports 3.13, then the `py -3.13` launcher, then installs 3.13 via `uv` if available. You can pass a specific executable with `-PythonBin` (for example `-PythonBin python` when `python --version` is 3.13).
- **"python3.13 is not recognized"** when typed in the shell: That is normal; Windows typically exposes `python.exe` or `py.exe`. Install Python 3.13 (x64) from [python.org](https://www.python.org/downloads/) and ensure the installer checks "Add python.exe to PATH", then run `.\scripts\demo-day.ps1` without relying on a `python3.13` command name.
- **libsodium.dll not found**: The launcher now auto-downloads libsodium. If issues persist, install the Microsoft Visual C++ Redistributable (x64).
- **Vault opens but Turret/plugin bridge is unavailable**: On Windows runtimes without Unix-domain sockets (`socket.AF_UNIX`), LockSmith now disables Turret for the current session instead of failing vault open. Core wallet flows continue to work; browser-plugin bridge features are unavailable in that session.

### General Troubleshooting

If you see `uv : The term 'uv' is not recognized...` on Windows, that is okay when Python 3.13 is already installed and available as `python` or `py`. You can run:

```powershell
.\scripts\demo-day.ps1 -SetupOnly
.\scripts\demo-day.ps1
```

Install `uv` only if you specifically want automatic Python provisioning.

Use Python 3.13 explicitly:

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

```powershell
.\scripts\demo-day.ps1
# optional when `python --version` is 3.13:
# .\scripts\demo-day.ps1 -PythonBin python
```

### `LoadLibrary() argument 1 must be str, not None`

On Windows, this means `pysodium` could not locate `libsodium.dll`. The PowerShell launcher now auto-downloads libsodium from official GitHub releases if the `libsodium/` directory is missing or does not contain required DLL candidates.

The launcher also prepends base CPython runtime directories (`sys.base_prefix` and `sys.base_prefix\\DLLs`) to `PATH` so dependent runtime DLLs are discoverable when using a `uv`-provisioned Python.

The launcher performs an explicit `ctypes.WinDLL(...)` probe against bundled `libsodium` candidates before smoke tests. If this probe fails, it now warns and continues instead of hard-failing immediately.

If you still see this error, re-run setup-only mode in a fresh shell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\demo-day.ps1 -SetupOnly
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
