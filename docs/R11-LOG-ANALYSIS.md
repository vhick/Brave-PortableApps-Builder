# r11 — NSIS installer test success/failure classification

## What the actual r10 GitHub Actions log demonstrates

From `logs_121459200443.zip`, the November 21, 2026 run:

- Brave stable version `1.100.58` resolved successfully.
- Official Windows x64 ZIP downloaded, SHA-256-verified, and extracted.
- Compiled portable Go launcher and real Brave startup tests passed.
- Brave ZIP and NSIS `.paf.exe` were both generated and 7-Zip verified.
- r10's test script failed with `NSIS incorrectly allowed installation into an unrelated folder`.
- Publishing did not execute.

## Confirmed root cause

`scripts/test-unified-upgrade.ps1` contained:

```powershell
if ($ExpectSuccess -and $process.ExitCode -ne 0) {
  # report expected install error
} else {
  Require ($process.ExitCode -ne 0) 'NSIS incorrectly allowed installation into an unrelated folder'
}
```

For a successful first installation (`ExpectSuccess = true`, `ExitCode = 0`), the `if` condition was false and the `else` incorrectly asserted that the exit code MUST be nonzero. This creates a false alarm even when the installer behaves correctly. **The log alone does not prove the installer accepted an unrelated destination.**

## Correction

- Add the shared `Assert-InstallerOutcome` helper that treats NSIS `0` as success only for an expected install and rejects `0` for a deliberately unrelated folder.
- Log the actual installer exit code and destination before checking it.
- Preserve the disposable first-install destination and existing Data-preservation checks.
- Run six fast PowerShell outcome regressions before downloading Brave.
- Keep the shared Universal Package Builder v1.0.0, launcher, TraceGuard, ZIP packaging and release publisher v1.1.1 unchanged.
- Bump revision to `r11`, so a newly validated release cannot overwrite r10.

## Evidence and limitations

Local regression checks and Go tests can be run on non-Windows hosts; PowerShell tests and an authentic full NSIS install require GitHub Actions windows-2022. Do **not** claim the r11 installer and publisher have passed until the live workflow succeeds.

Reference: https://nsis.sourceforge.io/Docs/AppendixD.html (exit 0 normal, 1 user abort, 2 script abort).
