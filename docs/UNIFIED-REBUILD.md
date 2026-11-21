# r10 unified rebuild audit and acceptance evidence

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

The actual r8 GitHub Actions run validated Brave retrieval, launcher, startup, ZIP and NSIS compilation but stopped at a Boolean validation error. The next r9 run passed the Boolean guards and successfully built and validated both ZIP and PAF, then failed on first NSIS installation with exit code 2. r10 addresses premature creation of the empty installation directory. See `docs/R10-LOG-ANALYSIS.md`.

## r10 actual log-based delta

r9 built and validated both outputs, but installation test failed with NSIS exit 2. The script pre-created the supposedly fresh application destination, which can be mistaken for an occupied folder by shared NSIS v1.0.0. r10 creates the test parent and unrelated marker only, leaves the application destination absent, adds a cheap fixture regression test, and retains unchanged runtime launcher/TraceGuard. Complete Windows installation and publish remain unverified pending Actions. See docs/R10-LOG-ANALYSIS.md.
