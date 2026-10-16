# Changelog — WinGet.Audit

All notable changes to this product are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## [Unreleased]

_Nothing queued — latest release: **0.4.0**._

## [0.4.0] — 2026-10-12

### Changed

- **WGA-016:** Module layout. Domain logic moved from loose `scripts/` into
  `src/WinGet.Audit` (`Public/` + `Private/`), same shape as Driver Store
  Manager. Exported: `Resolve-WgaDetectionState`, `Get-WgaDetectionExitCode`,
  `New-WgaDetectionResult`, `Resolve-WinGetExe`, `Convert-WingetTextToObject`,
  `Invoke-WgaDetectPackage`. Lab scripts import the module. Intune bundles
  still concat those sources (`scripts/intune/bundle-order.json`).
  See [docs/architecture.md](docs/architecture.md).
- Intune builder status lines use `Write-Output` (`PSAvoidUsingWriteHost`).

## [0.3.1] — 2026-10-12

### Fixed

- **AI assistance log:** `docs/ai-assistance-log.md` renders as one GitHub table.
  The `<!-- AAI+ -->` marker sits in the newest row's When cell. A comment on
  its own line under the header made GitHub show only the header.

### Added

- Repo-root markdownlint (`.markdownlint.json` + `.markdownlint-cli2.jsonc`).
- Call-through VS Code tasks (`.vscode/tasks.json`); default ScriptSafetyGate
  path is `scripts/Invoke-WgaValidate.ps1`.
- **WGA-015:** Dual-host GitHub Actions (`.github/workflows/dual-host-ps.yml`)
  — Pester via `tests/Invoke-WgaPester.ps1` on `pwsh` and Windows PowerShell
  5.1, plus `Invoke-WinGetInventoryPs51SmokeTest.ps1`. Complements
  `intune-stub-size.yml` (full `Invoke-WgaValidate.ps1` on pwsh).

### Changed

- Dual-host CI and `intune-stub-size.yml`: `actions/checkout@v4` → `@v7` (Node 24).
- VirusTotal workflow: `actions/upload-artifact@v4` → `@v7` (Node 24). GitHub
  hosted runners deprecated Node 20 and warn when v4 runs on Node 24 runners.
- **WGA-014:** Filed Open — agent-compat full-pass remediations (README
  validate-first, scoped loops, deps AgentSummary hint, deploy/intune Stubs,
  CI name clarity; deferred CODEOWNERS/pre-commit). See `docs/issues.md`.

### Added

- **WGA-010:** Live SCCM/Intune pilot (Present vs Current on real assignment) —
  beyond lab WGA-009; standalone bundles shipped in **0.3.0**; live assignment
  still Open — see [docs/pilot-intune-detect.md](docs/pilot-intune-detect.md)
  and `docs/issues.md`.

## [0.3.0] — 2026-07-27

### Added

- **WGA-010 (prep):** DSM-style Intune detect bundles —
  `scripts/Build-WgaIntuneScripts.ps1`, `scripts/intune/bundle-order.json`,
  Present + Current Entry templates → `dist/intune/Detect-WinGetPackage*.ps1`
  (~24 KB each); `scripts/Wga.Detect.Runtime.ps1` shared with lab detect.
  Docs: [pilot-intune-detect.md](docs/pilot-intune-detect.md).

## [0.2.0] — 2026-07-26

### Added

- **WGA-013:** Cold-host validate deps — README Install-Module pair for
  Pester (≥5.5) + PSScriptAnalyzer; `Invoke-WgaValidate.ps1` fails fast with
  `WGA-VALIDATE-FAIL stage=deps` (no auto-install). Removed Proton Drive
  sync-conflict junk under `docs/` when present.
- **WGA-012:** Repo-root agent validate gate —
  `scripts/Invoke-WgaValidate.ps1` (stub size → Pester → PSScriptAnalyzer),
  `tests/Invoke-WgaPester.ps1`, `scripts/Invoke-WgaScriptAnalyzer.ps1`,
  `PSScriptAnalyzerSettings.psd1`; README Validate section (no `AGENTS.md`);
  CI job runs the same validate entry.
- [docs/lessons-learnt.md](docs/lessons-learnt.md) — bootstrap → first publish
  lessons (`WGA-001`–`WGA-011`).
- VirusTotal release URL scan —
  `.github/workflows/virustotal-release-scan.yml` on `release: published`
  (and manual dispatch); README notes `VIRUSTOTAL_API_KEY` secret (never commit).

### Changed

- `Get-WgaDetectionState.ps1` — PSA suppress for unused `PackageId` on the
  public classifier contract (callers pass Id for logging/API symmetry).

## [0.1.0] — 2026-07-18

### Added

- **WGA-011:** published <https://github.com/villepispa/winget-audit> (public MIT;
  `main` @ `3df91cd`). Prep: expanded `.gitignore` (`docs/lab-host.md`,
  `scripts/_drafts/`, `.cursor/`), [docs/lab-host.example.md](docs/lab-host.example.md);
  scrub host paths from committed docs.
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
