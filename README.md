# WinGet.Audit

SYSTEM-aware **inventory**, **version diff**, and **logging** for Windows Package
Manager — built for Intune / Enterprise App Catalog (EAC), not as a competing
updater.

**License:** [MIT](LICENSE) · **Charter:** [docs/product-brief.md](docs/product-brief.md)

## Quick start (interactive)

```powershell
# One-time (CurrentUser)
Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Force

# Demo inventory of packages with updates (JSON)
pwsh -NoProfile -File .\scripts\Invoke-WinGetInventoryDemo.ps1
```

**Plane A (pwsh):** `Microsoft.WinGet.Client` / `Get-WinGetPackage`.  
**Plane B (no fleet pwsh):** WindowsApps `winget.exe` + CLI parser —

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Invoke-WinGetInventoryCliDemo.ps1 -UpdatesOnly
```

**SYSTEM matrix:** [docs/system-matrix.md](docs/system-matrix.md) (User / PsExec /
Intune). Plane A lab wrapper:
`scripts/Invoke-WinGetInventoryDemoAsSystem.ps1`.

Install `Microsoft.WinGet.Client` **as SYSTEM** for the SYSTEM row (Admin
`Install-Module` is not enough):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-WinGetInventoryDemoAsSystem.ps1 `
  -PsExecPath 'C:\path\to\PsExec.exe' -BootstrapModule
```

## Layout

| Path | Role |
|------|------|
| `docs/product-brief.md` | Spec from 2026-07-17 design discussion |
| `docs/lessons-learnt.md` | Bootstrap → publish lessons (WGA-001–011) |
| `docs/issues.md` | Product issue register (`WGA-*`) |
| `docs/system-matrix.md` | User vs SYSTEM (PsExec / Intune) |
| `docs/lab-host.example.md` | Template for machine-local PsExec / paths (`lab-host.md` gitignored) |
| `docs/pilot-intune-detect.md` | Present/Current stub pilot (`WGA_*` env) |
| `docs/eac-migration.md` | Detect/Remediate → EAC notes |
| `docs/detection-semantics.md` | Installed vs update-available (WGA-007) |
| `docs/spine-consumption.md` | Optional Spine probe-envelope |
| `scripts/Get-WgaDetectionState.ps1` | Detection classifier (dot-source) |
| `scripts/Invoke-WinGetPackageDetect.ps1` | One-package Presence / UpToDate detect |
| `scripts/Invoke-WinGetInventoryDemo.ps1` | Plane A: module inventory + compare (PS 5.1 hops → pwsh) |
| `scripts/Invoke-WinGetInventoryCliDemo.ps1` | Plane B: WindowsApps winget + 5.1 CLI parse (no pwsh) |
| `scripts/Resolve-WinGetExe.ps1` | Resolve DesktopAppInstaller `winget.exe` (dot-source) |
| `scripts/Invoke-WinGetInventoryPs51SmokeTest.ps1` | Plane A Intune-host floor smoke |
| `scripts/Invoke-WinGetInventoryDemoAsSystem.ps1` | Plane A PsExec SYSTEM wrapper |
| `scripts/Test-IntuneStubSize.ps1` | ≤50 KB gate for `deploy/intune/` |
| `scripts/Invoke-WgaValidate.ps1` | Repo-root validate (stub size + Pester + PSA) |
| `scripts/Invoke-WgaScriptAnalyzer.ps1` | PSScriptAnalyzer on `scripts/` + `deploy/intune/` |
| `tests/Invoke-WgaPester.ps1` | Pester entry for `tests/unit` |
| `PSScriptAnalyzerSettings.psd1` | Product PSA settings |
| `scripts/fallback/` | Plane B CLI text→object (`#Requires 5.1`) |
| `deploy/intune/` | ≤50 KB stubs (Ensure + Present/Current detect) |

## Validate

One-time Gallery deps (CurrentUser) if missing:

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force `
  -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force `
  -SkipPublisherCheck
```

Repo-root gate for agents and CI (Pester + stub size + PSScriptAnalyzer).
Fails fast with `WGA-VALIDATE-FAIL stage=deps` when those modules are missing
(does not auto-install):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-WgaValidate.ps1 -AgentSummary
```

Individual stages:

```powershell
pwsh -NoProfile -File .\tests\Invoke-WgaPester.ps1 -AgentSummary
pwsh -NoProfile -File .\scripts\Test-IntuneStubSize.ps1 -AgentSummary
pwsh -NoProfile -File .\scripts\Invoke-WgaScriptAnalyzer.ps1 -AgentSummary
```

README remains the agent SSOT for this product — no `AGENTS.md`. Note:
third-party `agent-compatibility` scanners often classify PowerShell-first
trees as `unknown` (no `package.json` / Node layout); treat that as a scanner
blind spot, not a quality verdict.

## Requirements

- Windows 10/11 with WinGet / App Installer
- **Plane A:** PowerShell 7+ (`pwsh`) for `Get-WinGetPackage`
- **Plane B (no fleet pwsh):** WindowsApps `winget.exe` under SYSTEM — see
  [docs/system-matrix.md](docs/system-matrix.md)
- Windows PowerShell **5.1** OK as Intune entry (Plane A hops to pwsh)
- PS 5.1 entry smoke (Plane A): `powershell.exe -NoProfile -File .\scripts\Invoke-WinGetInventoryPs51SmokeTest.ps1`
- PS 5.1 Plane B smoke: `powershell.exe -NoProfile -File .\scripts\Invoke-WinGetInventoryCliDemo.ps1 -Query WindowsAppRuntime -AgentSummary`
- Detect smoke: `powershell.exe -NoProfile -File .\scripts\Invoke-WinGetPackageDetect.ps1 -PackageId Microsoft.WindowsAppRuntime.1.5 -Purpose Presence -Exact -AgentSummary`
- Optional: sibling product **Spine.Automation** (local OSS tree) — [docs/spine-consumption.md](docs/spine-consumption.md)

## Safety

- Demo script is **read-only** (no install/upgrade)
- Mutating WinGet operations are out of scope for v0
- Never put secrets in Intune-uploaded scripts
- Run `pwsh -NoProfile -File .\scripts\Test-IntuneStubSize.ps1` before uploading stubs
- Release download URL scan: [`.github/workflows/virustotal-release-scan.yml`](.github/workflows/virustotal-release-scan.yml) — set repo secret `VIRUSTOTAL_API_KEY` (never commit)

## Changelog / issues / AI disclosure

- [CHANGELOG.md](CHANGELOG.md)
- [docs/issues.md](docs/issues.md)
- [docs/lessons-learnt.md](docs/lessons-learnt.md)
- [docs/ai-assistance-log.md](docs/ai-assistance-log.md)
