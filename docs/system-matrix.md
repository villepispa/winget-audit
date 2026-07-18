# SYSTEM / host matrix — WinGet.Audit

Two inventory planes exist. Pick by fleet constraint (PS7 allowed or not).

## Plane A — Microsoft.WinGet.Client (preferred when pwsh is available)

`Get-WinGetPackage` requires **PowerShell 7+**. Windows PowerShell **5.1** may
*enter* the demo; the script **hops to pwsh**. Do not use App Execution Alias /
`winget` on PATH for this plane.

| Context | Entry | Inventory | How |
|---------|-------|-----------|-----|
| User | pwsh | pwsh | `Invoke-WinGetInventoryDemo.ps1` |
| User | PS 5.1 | pwsh (hop) | same script / `Invoke-WinGetInventoryPs51SmokeTest.ps1` |
| SYSTEM | pwsh PsExec | pwsh | `Invoke-WinGetInventoryDemoAsSystem.ps1` |
| SYSTEM | PS 5.1 PsExec | pwsh (hop) | add `-WindowsPowerShell` (entry only; bootstrap still pwsh) |

`-BootstrapModule` installs `Microsoft.WinGet.Client` under **pwsh as SYSTEM**.

## Plane B — WindowsApps `winget.exe` as SYSTEM (no PS7)

**Product scripts (WGA-005):**

| Script | Role |
|--------|------|
| `scripts/Resolve-WinGetExe.ps1` | Dot-source; WindowsApps glob → Appx InstallLocation → (User) LocalAppData `WindowsApps\winget.exe` |
| `scripts/fallback/Convert-WingetTextToObject.ps1` | `#Requires 5.1` table parser |
| `scripts/Invoke-WinGetInventoryCliDemo.ps1` | Read-only inventory JSON (`--accept-source-agreements`) |

```powershell
# User or SYSTEM — no pwsh required
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Invoke-WinGetInventoryCliDemo.ps1 -UpdatesOnly -AgentSummary
```

**Operator pattern (lab / SCCM / Intune PR):** resolve the Desktop App Installer
package folder under `WindowsApps`, then invoke that folder’s `winget.exe`
directly. PATH / App Execution Alias is **not** required.

```powershell
# SYSTEM session (whoami -> …\system) — glob often works
$wingetDir = Resolve-Path `
  'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' |
  Sort-Object -Property Path |
  Select-Object -Last 1

& "$($wingetDir.Path)\winget.exe" list --accept-source-agreements
# User sessions that cannot enumerate WindowsApps: Get-AppxPackage InstallLocation,
# then %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe (SCCM user-collection detect).
# (Resolve-WinGetExe does all three). Operator upgrade: …\winget.exe upgrade --id <Id> …
```

### SCCM user-collection detection (credential split)

Installs often run as **SYSTEM**; detection for **user** collections runs as the
**user**, who typically cannot access `C:\Program Files\WindowsApps`. That is
illogical but expected — see [detection-semantics.md](detection-semantics.md)
(WGA-008). Prefer device/SYSTEM detection when possible; otherwise use
`Resolve-WinGetExe` (includes LocalAppData alias for non-SYSTEM).

Evidence (2026-07-18): SYSTEM `winget.exe list` via
`Microsoft.DesktopAppInstaller_1.29.280.0_x64__8wekyb3d8bbwe` returned package
table (after source agreement prompt). Prefer **`winget list WindowsAppRuntime`**
for lab/smoke queries (common on Win11 fleets; better than one-off apps).
Product smoke: User PS 5.1 Plane B demo → upgrade-available packages. Used in
production-style SCCM installs and Intune proactive remediation updates.

| Pros | Cons |
|------|------|
| Works on **PS 5.1 + SYSTEM** without fleet-wide pwsh | Text tables — culture/encoding/pin footers (`Convert-WingetTextToObject`) |
| Matches existing operator remediation patterns | Not Microsoft’s documented “supported” SYSTEM API (Client module is) |
| | First-run **source agreements** must be non-interactive (`--accept-source-agreements`) |
| | Package folder version changes — always resolve with wildcard + sort / Appx |

**Implication for no-PS7 Intune inventory:** prefer **Plane B**
(WindowsApps CLI + text→object), not “give up on SYSTEM.” Plane A remains
preferred where pwsh exists. **WGA-005** Verified.

## Shared lab findings

| Finding | Detail |
|---------|--------|
| Admin ≠ SYSTEM for Gallery modules | `Install-Module` as Admin does not satisfy SYSTEM pwsh profile |
| `Get-WinGetPackage` on 5.1 | Throws `WindowsPowerShellNotSupported` |
| SYSTEM Restricted EP | PsExec wrapper uses `-ExecutionPolicy Bypass` |
| PATH `winget` under SYSTEM | Unreliable — use WindowsApps full path (Plane B) or Client module (Plane A) |
| SCCM user-collection detect | Runs as user; no `Program Files\WindowsApps` ACL — use Appx and/or LocalAppData alias (`Resolve-WinGetExe`); install may still be SYSTEM |
| Lab 2026-07-18 User resolve | `programFilesGlobOk=false`; Appx InstallLocation → `…\DesktopAppInstaller_1.29.280.0_…\winget.exe`; LocalAppData alias **exists** (tertiary if Appx path unreadable) |
| Lab 2026-07-18 User detect | Plane B Presence `Microsoft.WindowsAppRuntime.1.5` → `InstalledCurrent` (1.5.9) exit 0 |
| Lab 2026-07-18 SYSTEM detect | PsExec `-s` → `InstalledUpdateAvailable` (1.5.8→1.5.9) Presence exit 0; `context=SYSTEM`. Local paths: copy [lab-host.example.md](lab-host.example.md) → `lab-host.md` (gitignored) |
| User vs SYSTEM package view | Same Id can differ by context (User current vs SYSTEM older + Available) — orthogonal to Presence vs UpToDate |

## Plane B detect PsExec (lab)

Put PsExec on PATH or set a local path in gitignored `docs/lab-host.md`
(from [lab-host.example.md](lab-host.example.md)).

User token (no elevation):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Invoke-WinGetPackageDetect.ps1 `
  -PackageId Microsoft.WindowsAppRuntime.1.5 -Purpose Presence -Exact -Plane B -AgentSummary
```

SYSTEM (elevated + PsExec). `Invoke-WinGetInventoryDemoAsSystem.ps1 -DemoScript`
does **not** forward `-PackageId` — call PsExec directly:

```powershell
# From elevated prompt; replace PsExecPath and RepoRoot
& 'C:\path\to\PsExec.exe' -accepteula -s -nobanner `
  "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -NoProfile -ExecutionPolicy Bypass `
  -File 'C:\path\to\winget-audit\scripts\Invoke-WinGetPackageDetect.ps1' `
  -PackageId Microsoft.WindowsAppRuntime.1.5 -Purpose Presence -Exact -Plane B -AgentSummary
```

Verified 2026-07-18: exit 0, `InstalledUpdateAvailable`, `context=SYSTEM`.

## Plane A PsExec cheat sheet

```powershell
.\scripts\Invoke-WinGetInventoryDemoAsSystem.ps1 `
  -PsExecPath 'C:\path\to\PsExec.exe' `
  -WindowsPowerShell -BootstrapModule
```

| Code | Meaning |
|------|---------|
| `0` | Demo OK |
| `2` | Module missing under SYSTEM pwsh |
| `3` | PsExec not found |
| `4` | Not elevated |
| `5` | Bootstrap failed |
| `6` | pwsh not found (hop impossible) |

## Plane B exit codes (`Invoke-WinGetInventoryCliDemo.ps1`)

| Code | Meaning |
|------|---------|
| `0` | Inventory OK |
| `1` | Parse / unexpected failure |
| `2` | `winget.exe` not found |
| `3` | `winget list` failed |

## Intune notes

- Default script host: **SYSTEM + Windows PowerShell 5.1**.
- **With pwsh on endpoints:** Plane A (Ensure-WinGetClient + demo hop).
- **Without fleet pwsh:** Plane B (WindowsApps `winget.exe` + CLI parser); EAC
  still owns catalog updates where applicable.
- Prefer EAC for catalog app supersede; WinGet.Audit is inventory/logging (and
  operator CLI update patterns outside EAC when you already use them).

## Honest gaps

- Plane A vs Plane B lists can diverge.
- `IsUpdateAvailable` (Client) ≠ “any newer catalog version.”
- CLI parse remains fragile vs objects — keep Client primary when pwsh is allowed.
- **Detection:** presence ≠ update-available — [detection-semantics.md](detection-semantics.md)
  (**WGA-007**). Do not use empty `--upgrade-available` as “not installed.”
- User vs SYSTEM inventory for the same Id can disagree (lab: User WAR 1.5.9
  current vs SYSTEM 1.5.8 with Available 1.5.9) — match detect **Purpose** and
  identity to the collection (user vs device).
- **WGA-006 (Verified):** on Desktop App Installer **1.29.280**, redirected
  `list` needed **no** ellipsis/mojibake strip (WAR + upgrade-available A/B).
  Parser default is trim-only; `-LegacyCellCleanup` for pre-1.29 fleets.
  CliDemo / PackageDetect prefer `--no-progress` and `--sort id` (degrade).
  Experimental `listDetails` / `--details` **not** adopted (settings gate;
  non-table output). Refs: [v1.29.280](https://github.com/microsoft/winget-cli/releases/tag/v1.29.280).
