# Optional Spine.Automation probe-envelope consumption

WinGet.Audit may **optionally** use [Spine.Automation](../../spine-automation/)
helpers for the standard probe envelope
`{ ok, exitCode, safetyTier, summary, data }`. Spine is **not** required to run
the inventory demo, and **must never** be embedded in `deploy/intune/` stubs
(EAC ≤50 KB ceiling).

## When to use Spine

| Surface | Spine? |
|---------|--------|
| `scripts/Invoke-WinGetInventoryDemo.ps1` | Optional — prefer when sibling module or Gallery install is available |
| `deploy/intune/*.ps1` stubs | **Never** — keep stubs self-contained |
| CLI text fallback | No — stay lean |

## Resolution order (demo)

1. `$env:WGA_SPINE_MODULE_PATH` — path to `Spine.Automation.psd1` or module folder.
2. Sibling checkout: `../spine-automation/src/Spine.Automation`.
3. Already-installed `Import-Module Spine.Automation` (Gallery / vendored).
4. Else: hand-built `[ordered]` hashtable (same shape) — no failure.

## Emit helpers used

When Spine loads successfully:

- `New-SpineProbeEnvelope` / `Write-SpineProbeEnvelope`
- Optional `Assert-SpineProbeEnvelope` in tests

Pin sibling module version in product CHANGELOG when behaviour depends on a
newer Spine release (current Spine tag for envelopes: **v0.1.1**).

## Local smoke

```powershell
# Without forcing a path (sibling ../spine-automation resolves when present)
pwsh -NoProfile -File .\scripts\Invoke-WinGetInventoryDemo.ps1 -AgentSummary

# Force sibling path
$env:WGA_SPINE_MODULE_PATH = '..\spine-automation\src\Spine.Automation'
pwsh -NoProfile -File .\scripts\Invoke-WinGetInventoryDemo.ps1 -Json
```

JSON should still validate as a standard probe envelope either way. Expect
`data.spineUsed: true` when Spine loaded.

**Verified (2026-07-17):** User context — `-AgentSummary` reported `spine=True`;
explicit `WGA_SPINE_MODULE_PATH` + `-Json` returned envelope with
`spineUsed: true`, 5 packages.
