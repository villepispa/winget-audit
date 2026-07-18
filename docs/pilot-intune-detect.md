# Intune / SCCM detect stub pilot

Lab pattern for one real package using env vars (Intune can set these as
script parameters or device variables).

## Env

| Variable | Example |
|----------|---------|
| `WGA_AUDIT_ROOT` | `C:\Tools\winget-audit` (fixed path on the endpoint) |
| `WGA_PACKAGE_ID` | `Microsoft.WindowsAppRuntime.1.5` |

Deploy `scripts/` under that root on the endpoint (lab may use a local
checkout). Stubs: `deploy/intune/Detect-WinGetPackagePresent.ps1` and
`Detect-WinGetPackageCurrent.ps1`.

## Lab helper

```powershell
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

1. Copy product tree (or at least `scripts/` + `deploy/intune/`) to a fixed path; set `WGA_AUDIT_ROOT`.
2. Set `WGA_PACKAGE_ID` to the WinGet Id for the app.
3. Detection script = Present **or** Current (one question per script).
4. Exit 0 = compliant; exit 1 = non-compliant (remediate / report).
5. Prefer device/SYSTEM detection when install is SYSTEM; user-collection → LocalAppData resolve (WGA-008).

## Next: live estate (WGA-010)

Lab pilot (WGA-009) is done. **WGA-010** tracks a real SCCM and/or Intune
assignment on a managed device/collection — same env vars and stubs, production
content source and reporting.
