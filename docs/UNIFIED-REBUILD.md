# r9 unified rebuild audit and acceptance evidence

- Previous Brave r7 release resolver, official ZIP extraction, Go launcher, TraceGuard, and DevTools browser smoke code are retained from the previously tested r7 baseline.
- Removed three-workflow split; this repository delivers exactly one `.github/workflows/build.yml`.
- Replaced the previous official-tool PAF attempt and standalone NSIS with `vhick/Portable-Package-Builder@v1.0.0` custom-nsis in the SAME Windows job.
- `vhick/portable-release-publisher@v1.1.1` handles both assets together with dry-run then real publishing. No second release publisher.
- Safe upgrade tests: real custom-NSIS install, reinstall over existing `Data`, old version-numbered App folder cleanup, original application file hash, empty nested directory preservation, and unrelated host directory rejection.
- Upstream app version recorded in `work/upstream.json` with exact Brave release commit and GitHub asset digest.
- User flags preserved: --disable-brave-update, --no-default-browser-check, --disable-logging, --disable-breakpad, --disable-machine-id, --disable-encryption-win. Compatibility of unsupported flags is not asserted.
- Application stage has no saved browser data when packaged.
- Warning: Installer is community NSIS, not official PortableApps.com Installer; Windows antivirus false positives are possible and must not be evaded.

## Local verification versus live Windows verification

The user's actual r8 GitHub Actions run validated Brave browser retrieval, native launcher compilation, live browser startup, ZIP creation, and custom NSIS compilation, but stopped at a Boolean type error in `validate-unified.ps1`. The delivered r9 ZIP passed local Go tests, launcher cross-compilation, and static/YAML checks. The r9 PowerShell guard regression, full installer upgrade behavior, and publishing have NOT yet run in GitHub Actions. Thus r9 is a test candidate, not a verified published build. See `docs/R9-LOG-ANALYSIS.md`.
