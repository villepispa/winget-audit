# Detect / Remediate → Enterprise App Catalog migration

WinGet.Audit does **not** replace EAC. This note records when classic Intune
Proactive Remediations still make sense and how thin stubs fit.

## Preferred path (catalog apps)

1. **Enterprise App Catalog (EAC)** owns install / update / supersede for apps
   present in the catalog.
2. Prefer EAC **default** install commands and file/registry detection.
3. Use PowerShell **install/uninstall overrides** only when needed — and keep
   each script ≤ **50 KB** (UTF-8). See `deploy/intune/`.

## When remediations remain

Keep or add Detect/Remediate pairs for:

| Case | Why |
|------|-----|
| Non-catalog Win32 apps | No EAC supersede path |
| Pins / holdbacks | Catalog may show newer while policy pins older |
| Installer-tech mismatch | MSI vs EXE / custom switches EAC cannot express |
| Inventory-only signals | Audit/logging without mutating (this product’s job) |

## Stub roles in this repo

| Script | Role |
|--------|------|
| `deploy/intune/Ensure-WinGetClient.ps1` | Bootstrap / readiness for `Microsoft.WinGet.Client` (pwsh) |
| `deploy/intune/Detect-WinGetPackagePresent.ps1` | Presence detect (calls `Invoke-WinGetPackageDetect`; set `WGA_AUDIT_ROOT` / `WGA_PACKAGE_ID`) |
| `deploy/intune/Detect-WinGetPackageCurrent.ps1` | Up-to-date detect (same; Purpose UpToDate) |

## Migration checklist (per app)

1. Is the app in Enterprise App Catalog? → Prefer EAC assignment.
2. Retire Detect/Remediate **update** logic that duplicates EAC supersede.
3. Keep inventory/diff logging in WinGet.Audit (module objects), not in fat Intune scripts.
4. Run `scripts/Test-IntuneStubSize.ps1` before upload.
5. Validate **SYSTEM** via [system-matrix.md](system-matrix.md) (PsExec lab + Intune pilot).
6. Pilot Present/Current stubs: [pilot-intune-detect.md](pilot-intune-detect.md).

## References

- [Add an Enterprise App Catalog app](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-enterprise-catalog-app)
- [product-brief.md](product-brief.md) §§ 4–5
- [deploy/intune/README.md](../deploy/intune/README.md)
