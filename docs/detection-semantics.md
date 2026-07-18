# Detection semantics — installed vs updates

Operator lesson (SCCM / Intune Proactive Remediations): **winget CLI
parameters alone often do not separate** “package is present” from “an update
is available.” The same `list` switches can yield the same exit code and a
similar-looking table; **PowerShell must classify rows** (or use Plane A
objects).

## Two questions (do not collapse)

| # | Question | Compliant when… |
|---|----------|-----------------|
| 1 | **Is the software installed?** | At least one matching package row (Id / Name / query) |
| 2 | **Are updates available?** | That row has a usable newer **Available** version (Plane B) or `IsUpdateAvailable` (Plane A) |

These are **orthogonal**. Mixing them into one “winget list with magic flags”
check is how detections lie.

## Derived states (product contract)

| State | Installed? | Update available? | Typical remediations use |
|-------|------------|-------------------|--------------------------|
| `NotInstalled` | no | n/a | Install |
| `InstalledCurrent` | yes | no | Presence OK; update detect = compliant |
| `InstalledUpdateAvailable` | yes | yes | Presence OK; update detect = non-compliant |

Optional later: `InstalledPinned` / `InstalledUnknownVersion` (pins, empty Version).

## Why CLI switches are not enough

- `winget list <Id>` exit **0** when installed — whether or not **Available** is filled.
- `winget list --upgrade-available` answers question **2** only (no row ⇒ either
  not installed **or** current — ambiguous for question **1**).
- Redirected / non-interactive flags (`--accept-source-agreements`,
  `--no-progress`, …) improve automation hygiene; they **do not** encode the
  two-state model.
- Experimental `--details` (1.28 `listDetails`) can enrich a single package but
  still needs PS to map “Available Upgrades” vs absence.

## Recommended classification

**Plane A (preferred when pwsh):** `Get-WinGetPackage` → presence by Id;
update via `IsUpdateAvailable` (honest gap: not identical to “any newer catalog
version”).

**Plane B:** resolve `winget.exe` → `list` **without** `--upgrade-available` for
presence; parse table; then:

1. Match Id (prefer `--id` / exact when targeting one app).
2. `Installed = ($match -ne $null)`.
3. `UpdateAvailable = Installed -and -not [string]::IsNullOrWhiteSpace($match.Available)`
   (optionally compare versions when both parse as `[version]` / SemVer).

Do **not** infer “not installed” solely from an empty `--upgrade-available`
result.

## Intune / SCCM exit-code sketch

Pick **one** question per detection script (or emit both in JSON and map
explicitly):

| Script purpose | Exit 0 (compliant) | Exit 1 (non-compliant) |
|----------------|--------------------|-------------------------|
| Presence | `InstalledCurrent` or `InstalledUpdateAvailable` | `NotInstalled` |
| Up-to-date | `InstalledCurrent` | `InstalledUpdateAvailable` (and often `NotInstalled` if policy requires install first) |

Emit probe JSON (`state`, `id`, `installedVersion`, `availableVersion`) for
logging; keep stubs ≤50 KB.

## SCCM exception — user-collection detection vs SYSTEM install

Illogical but common:

| Phase | Typical identity | WindowsApps ACL |
|-------|------------------|-----------------|
| SCCM/Intune **install** | SYSTEM | Can resolve `Program Files\WindowsApps\…\winget.exe` |
| SCCM **detection** for a **user collection** | End-user | Often **cannot** list or read `C:\Program Files\WindowsApps` |

So a detect script that only globs `Program Files\WindowsApps` fails in user
context even though the same machine’s SYSTEM install path worked.

### What WinGet.Audit already does

`Resolve-WinGetExe` (Plane B) order:

1. **Glob** `Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*` (SYSTEM-friendly).
2. **`Get-AppxPackage` → InstallLocation** — avoids directory enumeration; path may
   still point at `Program Files\WindowsApps` (works for many interactive users;
   may still fail under locked-down user detection if that tree is unreadable).
3. **Non-SYSTEM only:** `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`
   (per-user App Execution Alias). Required for SCCM user-collection detection
   when (1)/(2) cannot open the package folder.

**Do not** use the LocalAppData alias as the SYSTEM inventory entry (Plane B
SYSTEM matrix still prefers the real package path).

### Operator notes

- Prefer **device** collections / SYSTEM detection when policy allows — one
  identity for install and detect.
- If detection must stay user-scoped: rely on `Resolve-WinGetExe` (or an
  equivalent LocalAppData fallback); do not hard-code only the Program Files path.
- Plane A (`Get-WinGetPackage` under the user’s pwsh) avoids `winget.exe` path
  ACL issues but needs pwsh + Client module in that user profile.

## Tracking

**WGA-007** Verified — classifier + detect scripts.  
**WGA-008** — SCCM user-collection / LocalAppData resolve path (documented +
`Resolve-WinGetExe` step 3).
