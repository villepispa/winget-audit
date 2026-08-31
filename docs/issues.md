# WinGet.Audit — issue register

Product-local IDs: `WGA-NNN`. Keep IDs stable; never reuse.

## Workflow

- **Status:** `Open` → `In progress` → `Resolved` → `Verified`
- Prefer evidence links before `Verified`

## Open issues

| ID | Summary | Status | Notes |
|----|---------|--------|-------|
| WGA-015 | Dual-host GitHub Actions (`dual-host-ps.yml`) | Resolved | Pester on pwsh + Windows PowerShell 5.1 via `tests/Invoke-WgaPester.ps1`; `Invoke-WinGetInventoryPs51SmokeTest.ps1`. Complements `intune-stub-size.yml`. Workflow not yet proven on GitHub runners. |
| WGA-014 | Agent-compat full-pass remediations (docs + deps UX) | Open | From 2026-07-25 full pass (blended **53/100**). Top: README Agents/Validate-first; one Gallery prereq block; scoped `-TestPath`/`-Path` + duration note; `stage=deps` Install-Module hint. Non-top: deploy/intune Stubs table; CI workflow name clarity; `-SkipLint` in README; Safety stub `-AgentSummary` example; optional `-CheckOnly` bootstrap. Deferred: CODEOWNERS / pre-commit. Fabric: `docs/oss/agent-compatibility-ps-products.md` § 1.4. |
| WGA-013 | Post–agent-compat re-score hygiene (cold-host deps + conflict junk) | Verified | Validate `stage=deps` preflight + README Install-Module pair; Proton Drive `docs/issues (# Edit conflict…)` removed (already absent). Fabric re-score 52/100. |
| WGA-012 | Agent-compat remediations (validate + PSA; README SSOT) | Verified | `Invoke-WgaValidate.ps1` + Pester/PSA entries; CI; README Validate; no AGENTS.md. Smoke `WGA-VALIDATE-OK` (15/15, lint 0). |
| WGA-011 | Publish WinGet.Audit to GitHub (`villepispa`) | Verified | <https://github.com/villepispa/winget-audit> — public MIT; `main` @ `3df91cd`; origin SSH |
| WGA-010 | Live SCCM/Intune pilot (Present vs Current on real assignment) | Open | Standalone Present + Current bundles ready (`Build-WgaIntuneScripts.ps1` → `dist/intune/`). Still need live assignment: set `WGA_PACKAGE_ID`; capture exit codes + User vs SYSTEM. Checklist: [pilot-intune-detect.md](pilot-intune-detect.md) |
| WGA-009 | Intune Present/Current stub pilot (`WGA_AUDIT_ROOT` / `WGA_PACKAGE_ID`) | Verified | User lab: WAR 1.5 Present=0 Current=0 fake Present=1. Doc: [pilot-intune-detect.md](pilot-intune-detect.md) |
| WGA-008 | SCCM user-collection detect: LocalAppData winget when WindowsApps ACL blocks | Verified | Doc + `Resolve-WinGetExe` step 3 (`%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe` non-SYSTEM only). See [detection-semantics.md](detection-semantics.md) |
| WGA-007 | Detection states: installed vs update-available (CLI alone insufficient) | Verified | Classifier + `Invoke-WinGetPackageDetect.ps1`; Intune Present/Current stubs; smoke WAR 1.5 InstalledCurrent + fake NotInstalled. Spec: [detection-semantics.md](detection-semantics.md) |
| WGA-006 | Re-test / adopt winget 1.28–1.29 list automation improvements | Verified | Lab 1.29.280: redirected list needs no cell cleanup (ellipsis=0); `-LegacyCellCleanup` opt-in; `--no-progress`+`--sort id` with degrade; `listDetails` experimental not adopted. |
| WGA-005 | SYSTEM inventory via WindowsApps winget.exe + 5.1 CLI parse (no fleet pwsh) | Verified | `Resolve-WinGetExe` + `Invoke-WinGetInventoryCliDemo.ps1`; parser `#Requires 5.1`; User smoke 6 updates (PS 5.1.26100) |
| WGA-004 | Dual-host inventory (Windows PowerShell 5.1 + pwsh) | Verified | 5.1 entry hops to pwsh (`Get-WinGetPackage` pwsh-only); Plane A |
| WGA-001 | Module-primary inventory + JSON compare demo | Resolved | `scripts/Invoke-WinGetInventoryDemo.ps1`; module 1.29.280 CurrentUser; smoke 5 IsUpdateAvailable |
| WGA-002 | CLI text parser as fallback only | Resolved | Vendored improved gist → `scripts/fallback/`; not a public OSS pitch |
| WGA-003 | Intune/EAC ≤50 KB stub policy + detect/remediate → EAC migration notes | Verified | Stub + size CI; SYSTEM via PsExec `-BootstrapModule` → context SYSTEM, 8 packages, exit 0 (2026-07-17) |

## Activity

<!-- ISSUES-ACTIVITY+ -->
- **2026-08-18** — **WGA-015** Resolved: dual-host CI workflow + README CI note; Task palette `.vscode/tasks.json`.
- **2026-07-27 21:24:00** — Cut Keep a Changelog release **0.3.0** (standalone Intune Present/Current bundles); Unreleased holds **WGA-010** live pilot / **WGA-014**.
- **2026-07-27 21:18:00** — WGA-010 prep: standalone **UpToDate** Entry + builder emits `Detect-WinGetPackageCurrent.ps1` alongside Present.
- **2026-07-27 16:57:00** — WGA-010 prep: DSM-style `Build-WgaIntuneScripts.ps1` + `Wga.Detect.Runtime`; standalone Present ~23 KB under `dist/intune/`; thin `deploy/intune/` stubs unchanged.
- **2026-07-26 19:56:00** — Cut Keep a Changelog release **0.2.0** (WGA-012/013 validate gate + lessons-learnt + VirusTotal workflow); Unreleased holds **WGA-010** / **WGA-014**.
- **2026-07-25 09:01:40** — Filed **WGA-014** Open: full-pass Top + non-top remediable fixes (fabric blended 53/100); no product code yet.
- **2026-07-25 07:34:00** — **WGA-013** Verified: validate Gallery dep preflight (`stage=deps`); README Install-Module pair; sync-conflict issues copy gone.
- **2026-07-24 18:52:18** — **WGA-012** Verified: validate gate + PSA + README; local `WGA-VALIDATE-OK` (15/15, lint 0).
- **2026-07-18 23:16:00** — Cut Keep a Changelog release **0.1.0** (bootstrap → WGA-011 publish); left **WGA-010** under Unreleased.
- **2026-07-18 18:43:31** — Added [lessons-learnt.md](lessons-learnt.md) covering WGA-001–011 (planes, detect, dual-host, publish).
- **2026-07-18 18:24:39** — WGA-011 Verified: [villepispa/winget-audit](https://github.com/villepispa/winget-audit) public; Stream pushed `main` @ `3df91cd` (origin SSH).
- **2026-07-18 14:04:39** — WGA-011 In progress: plan filed; MIT LICENSE; gitignore `docs/lab-host.md` + `.cursor/`; scrub host paths for first push.
- **2026-07-18 14:00:00** — Filed **WGA-010** (live SCCM/Intune pilot) and **WGA-011** (publish to [github.com/villepispa](https://github.com/villepispa)).
- **2026-07-18 13:45:00** — WGA-009 Verified: Intune stub pilot via `WGA_AUDIT_ROOT`/`WGA_PACKAGE_ID` — Present=0, Current=0, fake Present=1 (`Microsoft.WindowsAppRuntime.1.5`); [pilot-intune-detect.md](pilot-intune-detect.md).
- **2026-07-18 13:24:00** — WGA-006 Verified: 1.29.280 A/B cleanupNeeded=false (WAR + upgrade list); cell strip opt-in `-LegacyCellCleanup`; CliDemo/Detect prefer `--sort id`; listDetails not adopted.
- **2026-07-18 13:11:00** — Lab item 2 complete: SYSTEM Plane B detect via PsExec → WAR 1.5 `InstalledUpdateAvailable` Presence exit 0; documented in local `lab-host.md` (User was `InstalledCurrent` 1.5.9 — context divergence).
- **2026-07-18 12:56:00** — Lab (item 2): User Plane B resolve — WindowsApps glob fail, Appx InstallLocation OK, LocalAppData alias present; detect WAR 1.5 Presence exit 0. SYSTEM detect deferred (no elevation / no PsExec in agent session); cheat sheet in system-matrix.
- **2026-07-18 10:01:00** — WGA-008: SCCM user-collection detection — document SYSTEM install vs user detect ACL split; `Resolve-WinGetExe` adds LocalAppData `WindowsApps\winget.exe` for non-SYSTEM.
- **2026-07-18 09:06:00** — WGA-007 Verified: `Get-WgaDetectionState` + `Invoke-WinGetPackageDetect` + Intune Present/Current stubs; Pester 8/8; smoke Microsoft.WindowsAppRuntime.1.5 InstalledCurrent, fake Id NotInstalled.
- **2026-07-18 09:02:00** — Filed WGA-007 + [detection-semantics.md](detection-semantics.md): presence vs update-available are orthogonal; CLI switches/exit alone insufficient (operator SCCM/Intune).
- **2026-07-18 08:39:00** — WGA-006 expanded: `--no-progress` (1.29), experimental `listDetails`/`--details` (1.28), plus redirected full-width list / `--sort` ([releases](https://github.com/microsoft/winget-cli/releases)).
- **2026-07-18 06:03:00** — Filed WGA-006: winget-cli [v1.29.280](https://github.com/microsoft/winget-cli/releases/tag/v1.29.280) non-truncating redirected `list` may retire cell ellipsis/mojibake strip — test before removing.
- **2026-07-18 05:55:00** — WGA-005 Verified: Plane B CLI demo on powershell.exe 5.1 — WindowsApps winget via Appx fallback, `--accept-source-agreements`, 6 upgrade-available packages.
- **2026-07-18 05:36:00** — Documented Plane B: SYSTEM winget via WindowsApps DesktopAppInstaller full path (operator SCCM/Intune); filed WGA-005. PATH winget still unreliable.
- **2026-07-18 04:46:00** — WGA-004 correction: `Get-WinGetPackage` throws on Windows PowerShell; demo hops 5.1→pwsh; bootstrap/Ensure under pwsh; `-WindowsPowerShell` is entry-only.
- **2026-07-17 22:12:00** — Documented `$psEdition` ≡ `$PSEdition` pitfall (local → `$hostEdition`; JSON property `psEdition` OK).
- **2026-07-17 22:05:00** — WGA-004 Verified: pwsh 7.6.3 + powershell.exe 5.1.26100 inventory smoke OK (5 packages each); avoided `$PSEdition` name collision.
- **2026-07-17 22:01:00** — WGA-004 started: dual-host inventory (PS 5.1 floor + pwsh); PS 5.1 smoke; SYSTEM `-WindowsPowerShell`.
- **2026-07-17 21:34:00** — Spine User smoke: `-AgentSummary` spine=True; `$env:WGA_SPINE_MODULE_PATH` + `-Json` → spineUsed true, 5 packages, User context.
- **2026-07-17 21:31:00** — WGA-003 Verified: `Invoke-WinGetInventoryDemoAsSystem.ps1 -PsExecPath … -BootstrapModule` → SYSTEM, 8 IsUpdateAvailable, exit 0.
- **2026-07-17 20:15:00** — SYSTEM matrix lab: WinGet.Client must be installed as SYSTEM; Admin CurrentUser insufficient; wrapper `-BootstrapModule`.
- **2026-07-17 19:23:41** — WGA-003: EAC stub + size CI gate; SYSTEM matrix (PsExec/Intune); optional Spine probe-envelope; eac-migration notes.
- **2026-07-17 17:30:00** — WGA-001 smoke: `Invoke-WinGetInventoryDemo.ps1` OK (5 updates; module 1.29.280; context User).
- **2026-07-17 17:27:00** — Bootstrap product tree; filed WGA-001–WGA-003 from design discussion.
