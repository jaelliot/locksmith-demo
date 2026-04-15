# LockSmith Demo

A self-contained demo snapshot of [LockSmith](https://github.com/keri-foundation/locksmith) — the KERI
Foundation's desktop identity wallet, built on [keripy](https://github.com/WebOfTrust/keripy) and PySide6.

This repo embeds the full LockSmith source. No sibling clone required.

---

## Prerequisites

| Requirement | Version | Install |
|---|---|---|
| Python | **3.13** (3.14 does not work with PySide6 6.9.x) | `brew install python@3.13` |
| Git | any recent | `brew install git` |
| macOS | 12 Monterey or newer | — |

Verify:

```bash
python3.13 --version   # must print 3.13.x
```

---

## Quick Start

### 1. Clone

```bash
git clone https://github.com/jaelliot/locksmith-demo.git
cd locksmith-demo
```

### 2. Preflight (install + run smoke tests, no GUI)

```bash
SETUP_ONLY=1 ./scripts/demo-day.sh
```

The script will:
- auto-select Python 3.13
- create `.venv/`
- install the package and dev extras (`pip install -e .[dev]`)
- regenerate Qt resources (`pyside6-rcc`)
- run the smoke test suite (`pytest tests/ -v`)

Expected output ends with something like:

```
tests/test_smoke.py::TestImports::test_import_configing PASSED
tests/test_smoke.py::TestImports::test_import_habbing PASSED
tests/test_smoke.py::TestImports::test_import_vaulting PASSED
tests/test_smoke.py::TestImports::test_import_plugins_base PASSED
tests/test_smoke.py::TestKeriLayer::test_aid_inception PASSED
tests/test_smoke.py::TestKeriLayer::test_transferable_aid_has_next_key_digest PASSED
tests/test_smoke.py::TestConfig::test_config_loads PASSED

7 passed in ...
```

### 3. Run the tests separately

```bash
.venv/bin/pytest tests/ -v
```

### 4. Launch the wallet

```bash
./scripts/demo-day.sh
```

---

## Demo Walkthrough

### AID creation

1. Launch LockSmith — the welcome screen appears.
2. Choose **Create new identifier**.
3. Enter a display name (e.g. `demo-aid`).
4. Accept the default witness configuration.
5. LockSmith generates a self-certifying AID and anchors it with the configured witnesses.

### Credential issuance

> **Known limitation:** Credential issuance requires a live witness pool *and* a running ACDC schema
> registry. The smoke tests verify the KERI layer headlessly but do not exercise credential issuance
> end-to-end. For a full credential demo, a witness set and registry must be reachable on the network.

### PySide6 architecture (for developer audiences)

LockSmith is a native desktop application built with:

- **PySide6** — Qt for Python binding, providing the widget layer
- **keripy** — KERI protocol library handling key management, event logs, and witness interactions
- **hio** — concurrent I/O framework for managing async KERI tasks within the Qt event loop

The UI layer in `src/locksmith/ui/` is deliberately thin; all identity state lives in the keripy
`Habery` / `Hab` objects and is persisted via LMDB.

---

## Keeping in Sync with Upstream

This repo embeds a point-in-time snapshot of locksmith source under `src/`. To pull in upstream
changes later:

```bash
# from the parent of this repo, assuming locksmith sits at ../locksmith
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.egg-info' \
  ../locksmith/src/ ./src/

# review the diff, run tests, then commit
git diff
.venv/bin/pytest tests/ -v
git add src/
git commit -m "chore: sync locksmith source from upstream <SHA>"
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PYTHON_BIN` | auto-detected | Force a specific interpreter, e.g. `PYTHON_BIN=python3.13` |
| `SETUP_ONLY` | `0` | Set to `1` to install + test without launching the GUI |

---

## Troubleshooting

**Python 3.14 error**

```
ERROR: could not build wheels for PySide6
```

`python3` on your machine resolves to 3.14. Force 3.13:

```bash
PYTHON_BIN=python3.13 ./scripts/demo-day.sh
```

**`pyside6-rcc` not found**

Make sure you activated (or let the script activate) the project's `.venv`. The script runs
`pyside6-rcc` from `.venv/bin/` — it does not need to be on your system PATH.

**Display / headless errors during tests**

Tests set `QT_QPA_PLATFORM=offscreen` automatically via `tests/conftest.py`. If you run pytest
manually, prepend the variable:

```bash
QT_QPA_PLATFORM=offscreen .venv/bin/pytest tests/ -v
```

**SSH vs HTTPS clone**

If your SSH key is not configured for GitHub, clone via HTTPS:

```bash
git clone https://github.com/jaelliot/locksmith-demo.git
```

---

## License

Apache 2.0 — see [LICENSE](LICENSE).
