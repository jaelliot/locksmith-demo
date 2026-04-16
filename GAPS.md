# LockSmith Demo Gaps Tracker

Living tracker for script parity and platform gaps discovered during demo hardening.

Scope:
- `scripts/demo-day.ps1`
- `scripts/demo-day.sh`
- Cross-platform setup/reset/launch behavior for presenter and participant flows

## Current Gaps (Parity + Platform)

### 1) Python discovery parity differs between scripts
- **PowerShell** has Windows-specific fallback resolution (`python3.13` -> `python` -> `py -3.13` -> `uv` provisioning).
- **Bash** currently does `python3.13` first, then `uv` provisioning.
- Impact: behavior is intentionally stronger on Windows, but not fully symmetric by script design.

Status: `open`

### 2) uv auto-install controls use different interfaces
- **PowerShell:** `-NoAutoInstallUv`
- **Bash:** `AUTO_INSTALL_UV=0`
- Impact: same capability, different operator experience and docs burden.

Status: `open`

### 3) Reset root paths are platform-specific by necessity
- **PowerShell reset** clears multiple roots including `C:\\usr\\local\\var\\keri` and `C:\\ProgramData\\keri`.
- **Bash reset** clears `${HOME}/.keri` and `/usr/local/var/keri`.
- Impact: not a defect, but tests must validate per-platform roots explicitly.

Status: `expected-difference`

### 4) Turret/plugin bridge transport on Windows
- Some Windows Python/runtime combinations do not provide `socket.AF_UNIX`.
- Current behavior: Turret disables for that session, vault open continues.
- Impact: core wallet demo works; browser-plugin bridge features unavailable in affected sessions.

Status: `mitigated` (long-term transport parity still open)

## Action Tracker

- [x] Fix Windows reset reliability for `LOCKSMITH_BASE` scoped vault state.
- [x] Add reset summary logging (`removed/missing/failed`) in both scripts.
- [x] Document reset + verify flow in `README.md`.
- [ ] Align operator-facing option names for uv auto-install controls across scripts/docs.
- [ ] Decide whether to mirror more Python interpreter discovery behavior in Bash.
- [ ] Define long-term Turret cross-platform transport strategy (Unix sockets vs TCP/named pipes abstraction).

## Verification Checklist (Windows + macOS/Linux)

- [ ] `SetupOnly` passes in native shell.
- [ ] full launch works after setup.
- [ ] create vault -> open -> lock -> reopen works.
- [ ] create second vault works.
- [ ] reset command reports `failed=0`.
- [ ] post-reset launch shows empty vault drawer for current `LOCKSMITH_BASE`.

## Upstream Issue Handoff (keri-foundation/locksmith)

Use upstream `keri-foundation/locksmith` for shared behavior gaps and platform compatibility issues.

### Why `arilieb` may not appear as assignable
GitHub only lets you assign users who have sufficient access to that specific repository (direct or via team). Being in the org or active on other repos is not enough.

### Practical workaround
1. Create issue unassigned.
2. Mention `@arilieb` in the issue body/comment.
3. Add labels (for example: `platform/windows`, `needs-triage`) if available.
4. Ask a repo maintainer/admin to grant access/team membership for assignability.

### Ready-to-paste issue body

```md
## Summary
Windows demo flow surfaced platform-specific behavior differences and one compatibility bug area.

## Environment
- Repo: `keri-foundation/locksmith`
- OS: Windows 10
- Shell: PowerShell
- Python: 3.13.x

## What was observed
1. Setup/preflight passes (`7` smoke tests).
2. Vault create/open/lock/reopen works.
3. Reset behavior needed root-path parity with actual runtime storage roots.
4. Turret/plugin bridge may be unavailable on Windows runtimes without `socket.AF_UNIX`.

## Reproduction (example)
1. Run:
   - `.\scripts\demo-day.ps1 -SetupOnly`
   - `.\scripts\demo-day.ps1`
2. Create vault(s), open/close, then run:
   - `.\scripts\demo-day.ps1 -ResetDemoState`
3. Relaunch and verify vault drawer state.

## Expected
- Reset reliably clears `LOCKSMITH_BASE`-scoped vault state.
- Core vault demo flow remains functional on Windows.
- If Turret transport is unavailable, failure should degrade gracefully.

## Actual
- Prior to fix, reset could miss active storage root(s) on Windows.
- Turret path could fail on missing `AF_UNIX` in some runtimes.

## Current status / mitigation
- Local branch now clears base-scoped stores across active roots and logs `removed/missing/failed`.
- Turret gracefully disables in affected Windows sessions; vault open continues.

## Ask
- Confirm preferred long-term approach for cross-platform Turret transport parity.
- Confirm whether script option/interface parity should be normalized across shells.
```

## Team Message Draft (Sam/Ari)

Use this quick note:

```text
I created a gaps tracker and validated Windows demo flow. Reset reliability and Windows vault-open compatibility are now mitigated locally, with Turret gracefully disabling when AF_UNIX is unavailable. I opened/plan to open the upstream issue in keri-foundation/locksmith and tagged @arilieb. If assignment is blocked, we’ll need maintainer access/team mapping on that repo.
```
# LockSmith Demo Gaps Tracker

Living tracker for script parity and platform gaps discovered during demo hardening.

Scope:
- `scripts/demo-day.ps1`
- `scripts/demo-day.sh`
- Cross-platform setup/reset/launch behavior for presenter and participant flows

## Current Gaps (Parity + Platform)

### 1) Python discovery parity differs between scripts
- **PowerShell** has Windows-specific fallback resolution (`python3.13` -> `python` -> `py -3.13` -> `uv` provisioning).
- **Bash** currently does `python3.13` first, then `uv` provisioning.
- Impact: behavior is intentionally stronger on Windows, but not fully symmetric by script design.

Status: `open`

### 2) uv auto-install controls use different interfaces
- **PowerShell:** `-NoAutoInstallUv`
- **Bash:** `AUTO_INSTALL_UV=0`
- Impact: same capability, different operator experience and docs burden.

Status: `open`

### 3) Reset root paths are platform-specific by necessity
- **PowerShell reset** clears multiple roots including `C:\\usr\\local\\var\\keri` and `C:\\ProgramData\\keri`.
- **Bash reset** clears `${HOME}/.keri` and `/usr/local/var/keri`.
- Impact: not a defect, but tests must validate per-platform roots explicitly.

Status: `expected-difference`

### 4) Turret/plugin bridge transport on Windows
- Some Windows Python/runtime combinations do not provide `socket.AF_UNIX`.
- Current behavior: Turret disables for that session, vault open continues.
- Impact: core wallet demo works; browser-plugin bridge features unavailable in affected sessions.

Status: `mitigated` (long-term transport parity still open)

## Action Tracker

- [x] Fix Windows reset reliability for `LOCKSMITH_BASE` scoped vault state.
- [x] Add reset summary logging (`removed/missing/failed`) in both scripts.
- [x] Document reset + verify flow in `README.md`.
- [ ] Align operator-facing option names for uv auto-install controls across scripts/docs.
- [ ] Decide whether to mirror more Python interpreter discovery behavior in Bash.
- [ ] Define long-term Turret cross-platform transport strategy (Unix sockets vs TCP/named pipes abstraction).

## Verification Checklist (Windows + macOS/Linux)

- [ ] `SetupOnly` passes in native shell.
- [ ] full launch works after setup.
- [ ] create vault -> open -> lock -> reopen works.
- [ ] create second vault works.
- [ ] reset command reports `failed=0`.
- [ ] post-reset launch shows empty vault drawer for current `LOCKSMITH_BASE`.

## Upstream Issue Handoff (keri-foundation/locksmith)

Use upstream `keri-foundation/locksmith` for shared behavior gaps and platform compatibility issues.

### Why `arilieb` may not appear as assignable
GitHub only lets you assign users who have sufficient access to that specific repository (direct or via team). Being in the org or active on other repos is not enough.

### Practical workaround
1. Create issue unassigned.
2. Mention `@arilieb` in the issue body/comment.
3. Add labels (for example: `platform/windows`, `needs-triage`) if available.
4. Ask a repo maintainer/admin to grant access/team membership for assignability.

### Ready-to-paste issue body

```md
## Summary
Windows demo flow surfaced platform-specific behavior differences and one compatibility bug area.

## Environment
- Repo: `keri-foundation/locksmith`
- OS: Windows 10
- Shell: PowerShell
- Python: 3.13.x

## What was observed
1. Setup/preflight passes (`7` smoke tests).
2. Vault create/open/lock/reopen works.
3. Reset behavior needed root-path parity with actual runtime storage roots.
4. Turret/plugin bridge may be unavailable on Windows runtimes without `socket.AF_UNIX`.

## Reproduction (example)
1. Run:
   - `.\scripts\demo-day.ps1 -SetupOnly`
   - `.\scripts\demo-day.ps1`
2. Create vault(s), open/close, then run:
   - `.\scripts\demo-day.ps1 -ResetDemoState`
3. Relaunch and verify vault drawer state.

## Expected
- Reset reliably clears `LOCKSMITH_BASE`-scoped vault state.
- Core vault demo flow remains functional on Windows.
- If Turret transport is unavailable, failure should degrade gracefully.

## Actual
- Prior to fix, reset could miss active storage root(s) on Windows.
- Turret path could fail on missing `AF_UNIX` in some runtimes.

## Current status / mitigation
- Local branch now clears base-scoped stores across active roots and logs `removed/missing/failed`.
- Turret gracefully disables in affected Windows sessions; vault open continues.

## Ask
- Confirm preferred long-term approach for cross-platform Turret transport parity.
- Confirm whether script option/interface parity should be normalized across shells.
```

## Team Message Draft (Sam/Ari)

Use this quick note:

```text
I created a gaps tracker and validated Windows demo flow. Reset reliability and Windows vault-open compatibility are now mitigated locally, with Turret gracefully disabling when AF_UNIX is unavailable. I opened/plan to open the upstream issue in keri-foundation/locksmith and tagged @arilieb. If assignment is blocked, we’ll need maintainer access/team mapping on that repo.
```
