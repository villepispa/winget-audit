# WinGet.Audit — product brief

**Status:** bootstrap (docs + demo)  
**Charter (2026-07-17):** SYSTEM-aware inventory, version diff, and Intune-thin
scripts that support **Enterprise App Catalog (EAC)** as the preferred update
channel, with Proactive Remediations as a fallback for non-catalog gaps — **not**
a second updater and **not** another CLI text→object gist.

**Sibling products:** [Driver Store Manager](../../driver-store-manager/),
[Spine.Automation](../../spine-automation/) (shared primitives only).

---

## 1. Problem

1. `winget.exe` emits tables (culture/encoding sensitive). Parsing text for
   logging and version compare is fragile (truncation, pins footers, mojibake).
2. Running under **SYSTEM** (Intune) is a first-class pain: App Execution Alias
   / MSIX lifecycle means **`winget.exe` is not supported as SYSTEM**; Microsoft
   points operators at **`Microsoft.WinGet.Client`** (COM) with remaining caveats.
3. **Enterprise App Catalog** (Intune Suite EAM) is becoming the update path for
   many Win32 apps, **replacing or complementing** classic Detect/Remediate pairs.
4. EAC PowerShell install/uninstall overrides are capped at **50 KB**.

## 2. Non-goals

| Non-goal | Why |
|----------|-----|
| Another `Convert-WingetTextToObject` / `cvwg` OSS module | Crowded (WingetTools, PS-TextTable, official client module) |
| Compete with EAC as the updater | EAC owns catalog install/update/supersede |
| Fold domain logic into Spine.Automation | Spine is thin dual-host primitives; WinGet is domain (like DSM/`pnputil`) |
| Embed Spine or fat parsers into Intune uploads | 50 KB ceiling |

## 3. Goals (v0)

| Goal | Notes |
|------|--------|
| **Primary inventory** | `Microsoft.WinGet.Client` objects → JSON log / compare |
| **CLI text fallback** | Only when module/COM unavailable; see `scripts/fallback/` |
| **Version compare** | Installed vs available; distinguish *applicable* update vs *newer in catalog* |
| **Detection states** | Orthogonal: **installed?** vs **update available?** — do not collapse into one winget switch; see [detection-semantics.md](detection-semantics.md) (WGA-007) |
| **Context axis** | `User` \| `SYSTEM` documented and tested |
| **Dual-host entry** | Intune/5.1 may *start* the demo; inventory API runs on **pwsh 7+** (hop). `Get-WinGetPackage` is not supported in Windows PowerShell (WGA-004). |
| **EAC alignment** | Thin stubs under `deploy/intune/`; remediations only for non-EAC remainder |
| **Spine consume** | Optional: probe envelope / UTF-8 helpers — never ship Spine in 50 KB stubs |

## 4. Role split (EAC era)

| Surface | Job |
|---------|-----|
| **EAC / Enterprise App Management** | Authoritative install / update / supersede for catalog apps |
| **Proactive Remediations** | Complement or sunset for catalog apps; keep for non-catalog / pins / installer-tech mismatch |
| **WinGet.Audit** | Inventory, diff, logging; ≤50 KB Intune stubs; optional detect-only helpers |

## 5. Intune / EAC packaging

- Installer/Uninstaller type **PowerShell script** max **50 KB** (UTF-8).
  Source: [Add an Enterprise App Catalog app](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-enterprise-catalog-app).
- Rule: any file under `deploy/intune/` must be ≤ **51200** bytes —
  enforced by `scripts/Test-IntuneStubSize.ps1` and
  `.github/workflows/intune-stub-size.yml`.
- Pattern: **module-on-device + stub script** (bootstrap → call → exit codes).
  First stub: `deploy/intune/Ensure-WinGetClient.ps1`.
- Prefer file/registry detection when EAC defaults suffice; keep custom detect scripts small.
- When WinGet-based detection is required: classify **presence** and **update
  available** separately — [detection-semantics.md](detection-semantics.md)
  (WGA-007). winget CLI exit codes alone are not enough (operator SCCM/Intune).
- Migration notes: [eac-migration.md](eac-migration.md). Context axis:
  [system-matrix.md](system-matrix.md). Optional Spine:
  [spine-consumption.md](spine-consumption.md).

## 6. SYSTEM notes

- Do **not** rely on `winget` on **PATH** / App Execution Alias under SYSTEM.
- **Plane A (pwsh available):** `Microsoft.WinGet.Client` / `Get-WinGetPackage`
  (PS 7+ only). Install the module **as SYSTEM under pwsh**. Admin
  `Install-Module` is not enough (lab 2026-07-17).
- **Plane B (no fleet pwsh):** invoke
  `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe`
  by resolved full path (wildcard + sort). Proven for SYSTEM list/install/update
  in SCCM and Intune remediations (operator evidence 2026-07-18). Pair with CLI
  text→object for inventory logging when Client is unavailable.
- Machine scope installs: `-Scope SystemOrUnknown` when using module mutators
  (future; not v0 demo).
- Honest gaps: CLI list ≠ module list; agreements must be non-interactive;
  `IsUpdateAvailable` ≠ “any newer catalog version.”

## 7. Primary vs fallback (decision 2026-07-17, refined 2026-07-18)

1. **Prefer** `Microsoft.WinGet.Client` when **pwsh** is available (objects,
   `IsUpdateAvailable`, `AvailableVersions`).
2. **Else** (PS 5.1 SYSTEM / no fleet pwsh): WindowsApps **`winget.exe` full path**
   via `scripts/Resolve-WinGetExe.ps1` + CLI text parser
   (`scripts/fallback/Convert-WingetTextToObject.ps1`, `#Requires 5.1`) —
   demo `scripts/Invoke-WinGetInventoryCliDemo.ps1` (**WGA-005** Verified).
3. **Never** treat PATH `winget` under SYSTEM as the supported entry.

## 8. Related landscape (do not reinvent)

| Project | Fit |
|---------|-----|
| [Microsoft.WinGet.Client](https://www.powershellgallery.com/packages/Microsoft.WinGet.Client) | Primary API |
| [PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit) | Enterprise deploy UI/session; not inventory |
| [PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet) | WinGet under PSADT / SYSTEM deploy |
| WingetTools / PS-TextTable | CLI text helpers — fallback inspiration only |

## 9. Open backlog (product IDs)

See [issues.md](issues.md) and host [ps-products-backlog.md](../../../docs/ps-products-backlog.md)
(`WGA-*`).
