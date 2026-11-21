# r11 unified rebuild audit and acceptance evidence

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

The actual r8 run validated Brave retrieval, launcher, startup, ZIP and NSIS compilation but stopped at a Boolean validation error. r9 passed that validation but its installer test encountered exit code 2 because it had pre-created the installation destination. r10 corrected that fixture and both packages again passed integrity verification; its **test logic** then incorrectly rejected successful NSIS exit code 0 as though it were a write into an unrelated folder.

## r11 actual log-based delta

r11 keeps the r10 first-install fixture unchanged and separates two result checks: an expected first install/upgrade must return 0, while an intentional install into an unrelated destination must return nonzero. A dedicated pre-download PowerShell regression tests both outcomes, plus unexpected failures. The actual Windows installer test still checks installed browser/launcher hashes, removes old versioned binaries, preserves `Data` and empty directory trees, and refuses unrelated host folders.

The release-publishing tag verifier now accepts `brave-r11`, avoiding an unrelated final-step failure after successful installation tests. Native launcher/TraceGuard, shared Universal Package Builder v1.0.0 and Universal Release Publisher v1.1.1 remain unchanged. See `docs/R11-LOG-ANALYSIS.md`.

Local Go tests, Windows cross-compilation, YAML and static regression checks do not establish a successful Windows PAF install or publication. Run the Windows workflow to verify both.
