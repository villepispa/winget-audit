# Changelog — WinGet.Audit

All notable changes to this product are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- **WGA-011:** public GitHub publish prep — MIT `LICENSE`, expanded `.gitignore`
  (`docs/lab-host.md`, `scripts/_drafts/`, `.cursor/`),
  [docs/lab-host.example.md](docs/lab-host.example.md); scrub host paths from
  committed docs.
- **WGA-009:** [docs/pilot-intune-detect.md](docs/pilot-intune-detect.md) —
  Present/Current stub pilot with `WGA_AUDIT_ROOT` / `WGA_PACKAGE_ID`
  (WAR 1.5: Present=0, Current=0, fake Present=1).
- **WGA-007:** detection classifier `Get-WgaDetectionState.ps1`,
  `Invoke-WinGetPackageDetect.ps1` (Presence / UpToDate; Plane B default),
  Intune stubs `Detect-WinGetPackagePresent.ps1` /
  `Detect-WinGetPackageCurrent.ps1`, Pester 8/8. Smoke: WAR 1.5
  `InstalledCurrent`; fake Id `NotInstalled`.
- **WGA-007:** [docs/detection-semantics.md](docs/detection-semantics.md) —
  orthogonal detection states (`NotInstalled` / `InstalledCurrent` /
  `InstalledUpdateAvailable`); operator note that winget CLI switches alone
  are insufficient for SCCM/Intune.
- **WGA-005:** Plane B inventory — `Resolve-WinGetExe.ps1` (WindowsApps glob +
  Appx InstallLocation), `Invoke-WinGetInventoryCliDemo.ps1` (PS 5.1,
  `--accept-source-agreements`, probe JSON), parser `#Requires 5.1` with
  ASCII-safe optional mojibake strip (`-LegacyCellCleanup`), Pester
  `WingetCliPlaneB.Tests.ps1`. Smoke: 6 upgrade-available packages on
  powershell.exe 5.1.26100.
- **WGA-003:** first EAC stub `deploy/intune/Ensure-WinGetClient.ps1`,
  `scripts/Test-IntuneStubSize.ps1` + Pester + GitHub Actions size gate,
  SYSTEM matrix docs + `Invoke-WinGetInventoryDemoAsSystem.ps1`, optional Spine
  probe-envelope in the inventory demo, `docs/eac-migration.md` and
  `docs/spine-consumption.md`.
- Product tree bootstrap: charter in `docs/product-brief.md`, issue register
  `WGA-001`–`WGA-003`, module-based inventory demo, CLI text fallback under
  `scripts/fallback/`, Intune 50 KB stub folder.

### Changed

- Filed **WGA-010** (live SCCM/Intune pilot) and **WGA-011** (publish repo to
  [github.com/villepispa](https://github.com/villepispa)).
- **WGA-006:** on winget **1.29.280**, cell ellipsis/mojibake strip is
  **opt-in** (`Convert-WingetTextToObject -LegacyCellCleanup`); default trim-only.
  Plane B CliDemo / PackageDetect prefer `--no-progress` + `--sort id` (degrade).
  Experimental `listDetails` not adopted. Lab drafts under `scripts/_drafts/`
  (local; not published).
- **Lab host:** copy [docs/lab-host.example.md](docs/lab-host.example.md) →
  `docs/lab-host.md` (gitignored). SYSTEM Plane B detect verified
  (WAR 1.5 Presence exit 0; User vs SYSTEM version view can differ).
- **WGA-008:** `Resolve-WinGetExe` — non-SYSTEM fallback
  `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe` for SCCM user-collection
  detection when `Program Files\WindowsApps` is unreadable; documented in
  detection-semantics / system-matrix.
- SYSTEM matrix / **WGA-006:** document winget 1.28–1.29 list automation notes
  (`--no-progress`, redirected full-width `list`, experimental `listDetails`);
  Plane B CliDemo prefers `--no-progress` then degrades for older builds.
- SYSTEM matrix: two planes — **A** Client/pwsh; **B** WindowsApps `winget.exe`
  full path under SYSTEM (operator SCCM/Intune evidence 2026-07-18). PATH winget
  still unreliable. **WGA-005** Verified.
- **WGA-004:** inventory Client path requires **pwsh**; 5.1 entry hops to pwsh;
  Ensure/Bootstrap under pwsh; `-WindowsPowerShell` is entry-only; PsExec
  `-ExecutionPolicy Bypass`. Local host label uses `$hostEdition` (not
  `$psEdition` — collides with automatic `$PSEdition`).
- SYSTEM matrix: `Microsoft.WinGet.Client` must be installed **as SYSTEM**;
  Admin `Install-Module` is not enough (lab 2026-07-17). Wrapper adds
  `-BootstrapModule` / `-SkipDemo`; demo missing-module hint is context-aware;
  `Ensure-WinGetClient.ps1` uses CurrentUser when identity is SYSTEM.
