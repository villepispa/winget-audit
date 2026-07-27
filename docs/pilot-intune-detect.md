# Intune / SCCM detect stub pilot

Lab pattern for one real package using env vars (Intune can set these as
script parameters or device variables).

## Two packaging paths

| Path | When | Artifact |
|------|------|----------|
| **Standalone (recommended for live assignment)** | No product tree on the device | `dist/intune/Detect-WinGetPackagePresent.ps1` and `Detect-WinGetPackageCurrent.ps1` from `scripts/Build-WgaIntuneScripts.ps1` |
| **Thin stub + tree** | Lab checkout or fixed `WGA_AUDIT_ROOT` | `deploy/intune/Detect-WinGetPackagePresent.ps1` (and Current) |

Rebuild standalone after detect-source changes:

```powershell
pwsh -NoProfile -File .\scripts\Build-WgaIntuneScripts.ps1 -AgentSummary
# WGA-BUILD-OK presentBytes=… currentBytes=… sources=4
```

Merge order: `scripts/intune/bundle-order.json`. Entries:
`Detect-WinGetPackagePresent.Entry.ps1` and
`Detect-WinGetPackageCurrent.Entry.ps1`.
Do not hand-edit `dist/intune/*.ps1`.

## Env

| Variable | Example |
|----------|---------|
| `WGA_PACKAGE_ID` | `Microsoft.WindowsAppRuntime.1.5` (required for standalone and stubs) |
| `WGA_AUDIT_ROOT` | `C:\Tools\winget-audit` (thin stubs only — fixed path on the endpoint) |
| `WGA_DETECT_PLANE` | Optional on standalone: `B` (default), `A`, or `Auto` |

Deploy `scripts/` under that root when using thin stubs (lab may use a local
checkout). Stubs: `deploy/intune/Detect-WinGetPackagePresent.ps1` and
`Detect-WinGetPackageCurrent.ps1`.

## Lab helper

```powershell
# Standalone (no WGA_AUDIT_ROOT) — rebuild first if sources changed
pwsh -NoProfile -File .\scripts\Build-WgaIntuneScripts.ps1 -AgentSummary
$env:WGA_PACKAGE_ID = 'Microsoft.WindowsAppRuntime.1.5'
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\dist\intune\Detect-WinGetPackagePresent.ps1
# exit 0 = present

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\dist\intune\Detect-WinGetPackageCurrent.ps1
# exit 0 = InstalledCurrent

# Thin stubs (need tree / WGA_AUDIT_ROOT)
$root = (Resolve-Path .).Path
$env:WGA_AUDIT_ROOT = $root
$env:WGA_PACKAGE_ID = 'Microsoft.WindowsAppRuntime.1.5'

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\deploy\intune\Detect-WinGetPackagePresent.ps1
# exit 0 = present

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\deploy\intune\Detect-WinGetPackageCurrent.ps1
# exit 0 = InstalledCurrent

$env:WGA_PACKAGE_ID = 'WGA.Fake.Package.DoesNotExist'
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\deploy\intune\Detect-WinGetPackagePresent.ps1
# expect exit 1
```

## Results (2026-07-18, User lab)

| Stub | Package | Exit | State |
|------|---------|------|-------|
| Present | `Microsoft.WindowsAppRuntime.1.5` | **0** | `InstalledCurrent` |
| Current | same | **0** | `InstalledCurrent` |
| Present | `WGA.Fake.Package.DoesNotExist` | **1** | `NotInstalled` |

Pilot **ok**. For SYSTEM collections, re-run under PsExec (see
[lab-host.example.md](lab-host.example.md) / local `lab-host.md`) —
UpToDate may exit **1** when SYSTEM sees an older installed version than User.

## SCCM / Intune wiring (checklist)

1. **Standalone:** rebuild `dist/intune/` Present and/or Current and upload
   (no `WGA_AUDIT_ROOT`). **Or** copy product tree / thin stubs and set
   `WGA_AUDIT_ROOT`.
2. Set `WGA_PACKAGE_ID` to the WinGet Id for the app.
3. Detection script = Present **or** Current (one question per script). Standalone
   builder emits both.
4. Exit 0 = compliant; exit 1 = non-compliant (remediate / report).
5. Prefer device/SYSTEM detection when install is SYSTEM; user-collection → LocalAppData resolve (WGA-008).

## Next: live estate (WGA-010)

Lab pilot (WGA-009) is done. **WGA-010** tracks a real SCCM and/or Intune
assignment on a managed device/collection — prefer standalone Present/Current
scripts for upload; thin stubs remain for EAC / lab with a tree. Capture exit
codes + User vs SYSTEM divergence.
