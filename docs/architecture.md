# Architecture — WinGet.Audit

SYSTEM-aware **inventory**, **version diff**, and **detection** for Windows
Package Manager. Intune / Enterprise App Catalog stays the updater. This
product does not install or upgrade packages.

Charter: [product-brief.md](product-brief.md). Host matrix:
[system-matrix.md](system-matrix.md).

## Layout

Same shape as Driver Store Manager: a versioned module under `src/`, thin
orchestration under `scripts/`, generated Intune scripts under `dist/`.

```text
src/WinGet.Audit/
  WinGet.Audit.psd1          # PS 5.1+, exported function list
  WinGet.Audit.psm1          # Private (fixed order) then Public
  Public/                    # one exported function per file
  Private/
    Wga.Cli.ps1              # Get-WgaWingetCell
    Wga.Detect.ps1           # Plane A/B helpers (not exported)
scripts/                     # demos, validate, build, smoke — import the module
scripts/intune/              # bundle-order.json + Entry templates
dist/intune/                 # generated standalone detect (gitignored *.ps1)
deploy/intune/               # ≤50 KB EAC stubs (call scripts/, not the fat parser)
tests/helpers/               # dot-source harness (Private then Public)
```

`WinGet.Audit.psm1` loads Private in the same order as
`scripts/intune/bundle-order.json`, then every `Public/*.ps1`.

## Design principles

1. **Objects first** — Plane A uses `Microsoft.WinGet.Client` when `pwsh` is
   available. Plane B parses `winget.exe` text only as a fallback.
2. **One detection record** — `New-WgaDetectionResult` is the shape for
   presence and up-to-date. Purposes stay orthogonal
   ([detection-semantics.md](detection-semantics.md)).
3. **Signals, not installs** — detect and inventory are read-only. Exit codes
   advise Intune; they do not upgrade.
4. **Full path under SYSTEM** — `Resolve-WinGetExe` never trusts PATH or the
   App Execution Alias for the SYSTEM row.
5. **Thin uploads** — EAC stubs stay ≤50 KB. Standalone Proactive Remediation
   scripts are a concat of this module, not a second copy of the logic.

## Planes

| Plane | When | Entry |
|-------|------|--------|
| **A** | `pwsh` + `Microsoft.WinGet.Client` | `scripts/Invoke-WinGetInventoryDemo.ps1` (hops to pwsh from 5.1) |
| **B** | Windows PowerShell 5.1 / no fleet pwsh | `Resolve-WinGetExe` + `Convert-WingetTextToObject`; demo `scripts/Invoke-WinGetInventoryCliDemo.ps1` |

Detect (`Invoke-WgaDetectPackage`) defaults to Plane B. `-Plane A` or `Auto`
uses the Client module. The function writes a probe envelope and **exits**
with the compliance code so Intune and the lab script share one implementation.

## Intune bundle

`scripts/Build-WgaIntuneScripts.ps1` concatenates `bundle-order.json` sources
and appends an Entry template. Rebuild after any `src/WinGet.Audit` change.
The endpoint script does not `Import-Module` — the functions are inlined so
the device does not need the repo tree.

`deploy/intune/Detect-WinGetPackage*.ps1` stays thin: it calls
`scripts/Invoke-WinGetPackageDetect.ps1`, which imports the module. That path
needs `WGA_AUDIT_ROOT` or a checkout. Use `dist/intune/` when the tree is not
on the device.

## What stays outside the module

Demos, PsExec SYSTEM wrapper, validate, Pester entry, ScriptAnalyzer, and the
Intune builder stay in `scripts/`. They are host orchestration, not the
product API.
