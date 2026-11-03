# Independent NSIS PAF add-on r2 for the verified Brave r7 builder

r2 fixes a PowerShell parser error in the release check and adds an automatic parse-only syntax test for every builder PowerShell script before network/download/NSIS steps. It uses a separate r2 installer tag and leaves Brave r7 intact.

This add-on adds a SECOND manual workflow to the existing repository. It does not replace the original `.github/workflows/build.yml`, Brave launcher source, or TraceGuard.

**No official PortableApps.com Installer is used here.** The generated `.paf.exe` is an independently compiled NSIS PortableApps-style installer, with no official PortableApps.com certification or endorsement.

## Install add-on using GitHub Desktop

1. Download `Brave-r7-Custom-NSIS-PAF-AddOn-r2.zip` and extract it.
2. In GitHub Desktop open your existing `Brave-PortableApps-Builder` repository and choose **Repository -> Show in Explorer**.
3. Copy the add-on's `.github`, `scripts`, and `docs` directories into the repository, merging folders rather than replacing the whole `scripts` directory. These paths contain new filenames only, preserving your original r7 files.
4. Commit `Fix PowerShell parser and add preflight syntax checks - NSIS r2`, then **Push origin**.
5. Open **GitHub -> Actions -> Brave PAF-style Installer (community NSIS - reuse verified r7 ZIP)** and click **Run workflow**.
6. Keep `source_tag=portable-v1.98.63-brave-r7` and `publish=true` for your verified r7 ZIP. This publishes an independent installer under a different tag without modifying the original r7 release.
7. Find the installer in **GitHub -> Releases**, under `portable-v1.98.63-brave-r7-custom-nsis-paf-r2`.

For more about Data protection, limitations, installation paths, testing and troubleshooting, read `docs/INDEPENDENT-NSIS-PAF-GUIDE.md`.

The first Windows run is required to verify the NSIS compilation and actual installer behavior. Local checks alone do not establish build success.

## Changes versus NSIS add-on r1

- Fixed `scripts/nsis-paf/check-release.ps1`: `${Tag}:` instead of invalid `$Tag:` in a double-quoted string.
- Added `scripts/nsis-paf/test-ps-syntax.ps1`, run immediately after checkout, before release checking.
- Installer file and release tag now use `custom-nsis-r2`/`custom-nsis-paf-r2`, avoiding collisions with a previous attempt.
- Preserves Brave r7 launcher, TraceGuard, and main build workflow unchanged.

**Verification:** This add-on is not yet proven to produce a PAF on GitHub Actions; the new syntax-check step and NSIS build must pass in a real Windows run.
