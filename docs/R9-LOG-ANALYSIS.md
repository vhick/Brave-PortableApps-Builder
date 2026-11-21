# Brave unified r9 — r8 GitHub Actions log findings and corrections

Source: user's r8 GitHub Actions logs, `logs_121449787794.zip`, generated 2026-11-21 UTC.

## Evidence from the real Windows run

- Stable Brave 1.100.58 was resolved and its official x64 ZIP extracted successfully.
- Go native PortableApps launcher, TraceGuard tests, real browser startup, and ZIP packaging passed.
- ZIP: `BravePortable_1.100.58_brave-r8_Win64.zip`, 255306509 bytes; `7z t`: Everything is Ok.
- Shared `vhick/Portable-Package-Builder@v1.0.0` compiled and validated the independent custom NSIS installer:
  `BravePortable_1.100.58.0_custom-nsis-brave-r8.paf.exe`, 260772842 bytes.
- Workflow failed afterward at `scripts/validate-unified.ps1` line 18:
  `Cannot convert value "System.String" to type "System.Boolean"`.
- Consequently the install/upgrade test and publishing did not run.

## Root cause and scope

`Require` is defined as `function Require([bool]$condition, [string]$message)`. In r8, one call supplied the `Get-FileHash` `.Hash` string instead of a Boolean predicate. Two later scripts were found to have the same latent mistake (`$env:RUNNER_TEMP` and `$env:GH_TOKEN`).

## r9 correction

1. Add `Test-Sha256Hex` and `Test-NonBlank` in `scripts/common.ps1`, both returning Boolean values.
2. Replace the raw-hash check with the tested SHA-256 hexadecimal predicate.
3. Replace the raw environment-variable checks in upgrade testing and publishing confirmation.
4. Execute `scripts/test-unified-guards.ps1` before the large Brave download.
5. Bump builder revision and release/package naming to `r9` without overwriting r8 or r7.
6. Preserve the verified r7-compatible Go launcher, TraceGuard and official Brave ZIP acquisition unchanged.

## Validation status

Local checks can verify Go unit tests, Windows launcher cross-compilation, Python static contracts, YAML parsing, and kit ZIP integrity. Windows PowerShell guard tests, actual NSIS install/upgrade and publication require a live GitHub Actions run. Never infer completed publication from a generated installer alone.
