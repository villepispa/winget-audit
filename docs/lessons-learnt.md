# WinGet.Audit — lessons learnt

**Period:** 2026-07-17 → 2026-07-18 (bootstrap through first GitHub publish)  
**Repo:** https://github.com/villepispa/winget-audit  
**Scope:** Lab-verified product work (`WGA-001`–`WGA-011`); live estate pilot
(`WGA-010`) still open.

This note captures decisions that surprised us, what to repeat, and what to avoid.
It complements the charter ([product-brief.md](product-brief.md)), not a second
brief.

---

## 1. Charter that held

| Decision | Why it paid off |
|----------|-----------------|
| Inventory / detect / log — **not** a competing updater | Kept scope clear vs EAC |
| Module-primary (Plane A); CLI parse **fallback** only | Avoided pitching another text→object OSS module |
| ≤50 KB Intune stubs + size gate | Forced thin packaging from day one |
| Orthogonal detection states (presence vs update-available) | Matched how SCCM/Intune operators actually ask questions |

---

## 2. Architecture: two planes

**Plane A** — `Microsoft.WinGet.Client` on **pwsh 7+**.  
**Plane B** — resolved WindowsApps `winget.exe` + PS 5.1 text parse (no fleet pwsh).

### Lessons

1. **PATH / App Execution Alias is not a SYSTEM strategy.** Under SYSTEM, resolve
   DesktopAppInstaller’s full path (glob → Appx InstallLocation →, for non-SYSTEM
   only, LocalAppData alias). Documented in [system-matrix.md](system-matrix.md).
2. **Admin `Install-Module` ≠ SYSTEM module.** Plane A under SYSTEM needs the
   module installed **as SYSTEM** (`-BootstrapModule` / Ensure stub). Lab burned
   a cycle discovering this.
3. **User vs SYSTEM package views diverge.** Same Id can be `InstalledCurrent` for
   User and `InstalledUpdateAvailable` for SYSTEM (lab WAR 1.5). Presence detect
   can still be compliant while UpToDate fails — design stubs with **one question
   per script**.
4. **SCCM user-collection ≠ SYSTEM ACL.** User detection may not read
   `Program Files\WindowsApps`; LocalAppData `WindowsApps\winget.exe` is a valid
   tertiary resolve for **non-SYSTEM** only (WGA-008).

---

## 3. Detection semantics (WGA-007)

Operators need two orthogonal answers:

| Question | State examples | Intune stub |
|----------|----------------|-------------|
| Is it installed? | `NotInstalled` / installed* | Present → exit 0 if installed |
| Is it current? | `InstalledCurrent` / `InstalledUpdateAvailable` | Current → exit 0 only if current |

### Lessons

1. **Do not collapse “detect” into a single winget switch or exit code.** CLI flags
   alone are insufficient for SCCM/Intune policy design.
2. Spec first ([detection-semantics.md](detection-semantics.md)), then classifier +
   thin stubs — reduced rework when wiring env vars (`WGA_AUDIT_ROOT` /
   `WGA_PACKAGE_ID`).
3. Lab pilot (WGA-009) with a real Id + a fake Id proved exit codes before a live
   estate assignment (WGA-010).

---

## 4. Dual-host PowerShell (WGA-004)

1. **`Get-WinGetPackage` is pwsh-only.** Windows PowerShell 5.1 is a valid *entry*
   (Intune), not the inventory host — hop to pwsh.
2. **Never name a local `$psEdition`.** It aliases / collides with automatic
   `$PSEdition`. Use `$hostEdition` (or similar); JSON property `psEdition` is fine.
3. **PsExec children need `-ExecutionPolicy Bypass`.** SYSTEM Restricted blocks
   `-File` otherwise.
4. **Avoid PowerShell automatic variable names** in scripts (`$args` → `$pwshArgs`).

---

## 5. winget CLI text plane (WGA-005 / WGA-006)

1. **Vendor parser as fallback, not the product pitch** (WGA-002). Keep
   `#Requires 5.1` and ASCII-safe cleanup.
2. **Prove version behaviour with A/B before removing hacks.** On App Installer
   **1.29.280**, redirected `list` needed **no** ellipsis/mojibake strip; cleanup
   became `-LegacyCellCleanup` (opt-in). Prefer evidence over release-note hope.
3. Prefer `--no-progress` and `--sort id` with **degrade** for older builds;
   experimental `listDetails` stayed experimental.
4. **Script-level `[CmdletBinding()] param()` + aliases** on a dot-sourced parser
   caused advanced-script parse errors — hoist helpers; keep the file a simple
   function library.
5. Lab fixtures: prefer packages that always exist (e.g. WindowsAppRuntime) over
   optional apps for live smoke.

---

## 6. Intune / EAC packaging

1. **Stub size gate early** (`Test-IntuneStubSize` + CI) prevents accidental fat
   uploads.
2. Pattern: **env + fixed deploy path** for detect stubs; keep product logic under
   `scripts/`, stubs under `deploy/intune/`.
3. **EAC owns update** for catalog apps; remediations are for gaps — keep
   [eac-migration.md](eac-migration.md) short and honest.
4. Optional Spine is envelope-only — never embed in 50 KB stubs.

---

## 7. Lab vs publish hygiene

1. Keep **machine paths** in gitignored `docs/lab-host.md`; ship
   [lab-host.example.md](lab-host.example.md).
2. Keep **ad-hoc A/B drafts** under `scripts/_drafts/` (gitignored) so host roots
   never hit GitHub.
3. Scrub Proton / PsExec / hostname strings from committed docs before first push
   (WGA-011).
4. Ignore product `.cursor/` in the public tree; VM JSON stays local.

---

## 8. OSS publish (WGA-011)

1. **Delegate remote create/push to Stream** once the tree is clean — parent agents
   waste time on `gh auth login` device-code timeouts.
2. First push with `.github/workflows/` may need GitHub OAuth **`workflow`** scope
   on HTTPS; **SSH** (MyOSS `authType`) was the reliable fallback.
3. Author identity: one-shot `git -c user.name=… -c user.email=…` — never rewrite
   global git config from an agent.
4. Draft Stream doc gaps for greenfield GitHub lived in the private Cursor
   config workspace and were applied on 2026-07-18. Reusable SYSTEM/Intune
   lessons were distilled into the dual-host guide § 11.

---

## 9. Process / AI-assisted delivery

What worked:

- Product-local issue IDs (`WGA-*`) + Verified only with smoke evidence
- Short product-local plans for multi-file slices
- AAI rows at phase boundaries ([ai-assistance-log.md](ai-assistance-log.md))
- Operator-pasted SYSTEM / PsExec output when the agent session lacked elevation

What to improve next cycle:

- Close the gap to **live** Intune/SCCM assignment (WGA-010) before claiming fleet
  readiness
- Prefer Stream earlier for any GitHub remote work
- Keep release-note chasing behind a filed issue + lab A/B (WGA-006 pattern)

---

## 10. Open follow-ups

| ID | Lesson to validate |
|----|--------------------|
| **WGA-010** | Lab Present/Current exits survive real device/collection + reporting |
| Estate scale | Multi-package policies, pins, non-catalog remediations |
| Plane A under constrained images | How often fleet actually has pwsh vs Plane B only |

---

## See also

| Doc | Role |
|-----|------|
| [product-brief.md](product-brief.md) | Charter / non-goals |
| [system-matrix.md](system-matrix.md) | User / SYSTEM / resolve paths |
| [detection-semantics.md](detection-semantics.md) | Presence vs UpToDate |
| [pilot-intune-detect.md](pilot-intune-detect.md) | Stub pilot + WGA-010 checklist |
| [issues.md](issues.md) | `WGA-*` register |
| [CHANGELOG.md](../CHANGELOG.md) | Shipped deltas |
| [ai-assistance-log.md](ai-assistance-log.md) | AI phase disclosure |

**Cross-project distill** (Cursor config workspace): dual-host guide § 11
(SYSTEM / Gallery / PATH / detect stubs) and PowerShell coding skill — sourced
from this note after first GitHub publish.
