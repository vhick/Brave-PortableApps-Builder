# Brave unified r10 — actual r9 GitHub Actions failure and correction

Source inspected: user-uploaded `logs_121457211995.zip`, November 21, 2026 UTC.

## Confirmed by GitHub Actions log
- Stable Brave v1.100.58 resolved.
- Official Brave x64 ZIP download, SHA-256 validation, extraction and native launcher compilation passed.
- Brave runtime smoke test and TraceGuard checks passed.
- Portable ZIP created and verified: `BravePortable_1.100.58_brave-r9_Win64.zip` (255,306,404 bytes).
- Shared `vhick/Portable-Package-Builder@v1.0.0` compiled an independent NSIS installer:
  `BravePortable_1.100.58.0_custom-nsis-brave-r9.paf.exe` (260,772,836 bytes).
- 7-Zip checks passed for both packages and SHA-256 values were calculated.
- First actual NSIS installation test failed with exit code 2; release publishing not reached.

## Diagnosis and scope
- `scripts/test-unified-upgrade.ps1` pre-created an empty target `RUNNER_TEMP/BraveUnifiedInstallerTest/BravePortable`.
- The shared v1.0.0 NSIS source has `IfFileExists "$INSTDIR\*.*" 0 verify_locks` and then aborts if the destination appears occupied. The NSIS wiki explicitly states this wildcard cannot distinguish whether a directory is empty.
- Exit code 2 means the NSIS installer script initiated an abort. The log does not include an internal installer reason, so this exact branch remains a high-confidence diagnosis, not independently logged proof.
- r10 changes the caller's synthetic first-install test only: create the parent and unrelated marker, but not the actual application destination. It deliberately does not disable the shared installer's host-protection guard.
- A new fast PowerShell fixture regression executes before the large Brave download and checks that condition.

## Follow-up recommended for the shared universal engine
A separate, versioned Universal Portable Package Builder release should explicitly and safely distinguish an empty destination from a destination with unrelated files, and test this in its own synthetic CI. Do not rewrite or move the published v1.0.0 tag. r10 stays pinned to v1.0.0.

## Verification
Local Go, Windows PE cross-compile, YAML/static/ZIP checks can be performed outside GitHub. Actual NSIS installation, upgrades and GitHub publishing require a Windows runner; they are not claimed as successful for r10 until executed.
