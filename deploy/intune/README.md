# Intune / EAC deploy stubs

**Hard limit:** PowerShell install and uninstall script overrides for
[Enterprise App Catalog apps](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-enterprise-catalog-app)
are **maximum 50 KB** (51200 bytes) each.

## Rules

1. Only **stubs** live here: ensure module present → call one function → exit codes.
2. Fat inventory/compare/logging logic belongs in a module (or content payload), not in these files.
3. Prefer EAC default install commands when possible; use script overrides only when needed.
4. Detection/requirement scripts should stay small; prefer file/registry rules when EAC allows.
5. **CI / local gate:** `scripts/Test-IntuneStubSize.ps1` and
   `.github/workflows/intune-stub-size.yml` fail if any `deploy/intune/*.ps1`
   exceeds 51200 bytes. Never import Spine.Automation from these stubs.

## EAC vs remediations

EAC **replaces or complements** classic Intune Detect/Remediate for catalog app
updates. Stubs here support EAC (and optional detect-only checks). Do not grow a
second full updater in this folder. Migration notes:
[docs/eac-migration.md](../../docs/eac-migration.md).

**Standalone Proactive Remediation / SCCM detect** (no tree on device): rebuild
with `scripts/Build-WgaIntuneScripts.ps1` → `dist/intune/Detect-WinGetPackagePresent.ps1`
and `Detect-WinGetPackageCurrent.ps1`
(see [pilot-intune-detect.md](../../docs/pilot-intune-detect.md)). That path is
not size-gated by this folder’s 50 KB EAC rule.

## Stubs

| Script | Role | Exit codes |
|--------|------|------------|
| `Ensure-WinGetClient.ps1` | Bootstrap readiness for `Microsoft.WinGet.Client` | `0` ready/installed; `1` missing (or `-WhatIf`); `2` install error |
| `Detect-WinGetPackagePresent.ps1` | Presence (WGA-007); calls `Invoke-WinGetPackageDetect` | `0` installed; `1` NotInstalled |
| `Detect-WinGetPackageCurrent.ps1` | UpToDate (WGA-007) | `0` InstalledCurrent; `1` otherwise |

```powershell
# Check only (probes Microsoft.WinGet.Client under pwsh)
powershell.exe -NoProfile -File .\deploy\intune\Ensure-WinGetClient.ps1 -WhatIf

# Bootstrap under pwsh (even when this stub is started by Windows PowerShell)
powershell.exe -NoProfile -File .\deploy\intune\Ensure-WinGetClient.ps1 -InstallIfMissing

# Intune / lab: run as SYSTEM so CurrentUser scope is SYSTEM's pwsh profile
# (Get-WinGetPackage is pwsh-only — see docs/system-matrix.md)
```
