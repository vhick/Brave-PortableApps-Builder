# Brave PortableApps — Unified Builder r11 (ZIP + independent NSIS PAF)

This independent builder produces **both** ready-to-extract `BravePortable_...zip` and a **custom NSIS-built** `.paf.exe` installer **in ONE Windows GitHub Actions workflow**, from ONE validated staging folder, without downloading Brave twice or recompiling the launcher twice.

- Actual upstream application: https://github.com/brave/brave-browser
- Source binaries: official stable `brave-v<VERSION>-win32-x64.zip`, with size and vendor-provided GitHub SHA-256 verified.
- Package builder: https://github.com/vhick/Portable-Package-Builder at **v1.0.0**, `custom-nsis` engine.
- Publisher: https://github.com/vhick/portable-release-publisher at **v1.1.1** (dry run then publish).
- This is **not** an installer produced by the official PortableApps.com Installer. The `.paf.exe` filename is used for a community PortableApps-style installer; do not claim PortableApps.com endorsement/certification.
- Browser is retrieved from Brave's official stable release **binaries**, not compiled from Chromium source. The native Go PortableApps launcher is compiled by the workflow from its own source.

## ONE workflow

File: `.github/workflows/build.yml` — GitHub Actions **Brave PortableApps - Unified ZIP and NSIS PAF**.

1. Run local unit/static tests and stable-release resolver regression tests.
2. Resolve current stable Brave release and SHA-256-protected uninstalled x64 browser ZIP (or specify stable version).
3. Check for the existing `portable-v<VERSION>-brave-r11` release. If found, **skip safely** without rewriting it.
4. Download, checksum-verify and unpack official Brave ZIP.
5. Stage `work/BravePortable` and compile a real `BravePortable.exe` using Go with Brave's official icon.
6. Launch actual Brave in a disposable CI profile; verify DevTools readiness, shutdown and TraceGuard cleanup. Remove all CI-created test data from staging.
7. Generate and validate a ready-to-extract ZIP from this stage.
8. Call **Universal Portable Package Builder v1.0.0** in the same job to compile **custom-nsis** installer from this exact same staged folder.
9. Require **both** ZIP and NSIS installer; verify their PE/archive signatures and SHA-256 digests. No optional ZIP-only success.
10. Install the full NSIS package into a temporary CI directory, perform an upgrade, verify obsolete version-numbered directories vanish, preserve profile files and empty folders in Data, reject an unrelated destination.
11. Use Universal Release Publisher v1.1.1: dry run, then publish **both assets** together in the **Brave builder repository**. Pruning remains disabled.

The default workflow run is **manual only**; it does not incur scheduled builds. There is no additional packaging job or `actions/upload-artifact` step.

## GitHub Desktop: replace your existing repo without breaking history

1. **Back up or commit any local changes** in your current `vhick/Brave-PortableApps-Builder` GitHub Desktop repository before making changes.
2. Download and unzip the complete r11 kit.
3. Open GitHub Desktop -> select `Brave-PortableApps-Builder` -> Repository -> Show in Explorer.
4. Inside your repository delete these **three OLD workflow files** if they exist (do **not** delete `.github` itself):
   - `.github/workflows/build.yml` (will be replaced by the new single file)
   - `.github/workflows/brave-custom-nsis-paf.yml`
   - `.github/workflows/build-paf-from-release.yml`
5. Delete only the **obsolete, standalone packaging code** if it exists:
   - `scripts/paf.ps1`
   - `scripts/nsis-paf` (entire legacy subfolder)
   - Old add-on-only docs `ADDON-INSTRUCTIONS.md`, `NSIS-R2-CHANGELOG.md` and `docs/INDEPENDENT-NSIS-PAF-GUIDE.md`.
6. Copy **all** extracted r11 kit files into the existing repository (including the hidden `.github` folder), replacing matching files. Do not replace the `.git` folder, and do not delete unrelated custom files without review.
7. In GitHub Desktop confirm there is **only one file in `.github/workflows`: `build.yml`**. Review changes. Commit summary: `Fix NSIS fresh-install test destination - r11`. Click Commit to main, then Push origin.
8. Open https://github.com/vhick/Brave-PortableApps-Builder/actions -> `Brave PortableApps - Unified ZIP and NSIS PAF` -> `Run workflow`.
9. Leave `version` blank for latest stable, set `publish=true`, click Run workflow.
10. When green, open **Releases** of the Brave builder and confirm two assets: one `.zip`, one `.paf.exe`, plus publisher-generated checksums.

**You do not need to create a GitHub release tag manually.** The shared publisher publishes the unique new r11 tag. Old r7 releases remain untouched.

## Runtime portability

The stable r7 native Go launcher was retained without application-code rewrites. Brave launches with a `--user-data-dir` pointing inside `BravePortable/Data/profile`, six requested additional flags, and conservative TraceGuard monitoring/recovery in `Data/TraceGuard`. Windows account-bound encryption can limit cookies/password portability; flags alone do not ensure cross-user/account decryption. Some Windows traces may remain. No admin rights or registry integration is requested by the launcher.

The shared NSIS installer replaces managed `App`, `Other`, and launcher binaries on upgrade and keeps `Data` intact. The workflow tests that a **synthetic old numbered Brave folder is removed** during installation and that profile files and nested empty directories remain. The installer does not move arbitrary files from shared host locations; that remains the application-specific TraceGuard scope.

**Important:** Back up `Data` before a real upgrade. Do not install over a running Brave browser. User-added content inside `App` or `Other` may be removed during a managed-directory upgrade. Keep custom user content under `Data` when supported.

## Existing releases and update frequency

Each upstream version and builder revision gets a tag `portable-v<VERSION>-brave-r11`. If that tag already exists, the workflow skips building rather than overwriting. To rebuild the *same* Brave version after a code fix, create a new builder revision and release tag; do **not** rewrite immutable r11 tags. Version selection checks Brave's stable channel; nightly/beta assets and wrong architecture are refused.

## Limitations

- Actual r10 Windows Actions confirmed Brave startup, ZIP and NSIS PAF compilation, and package integrity. The installer test itself incorrectly flagged NSIS exit code 0. r11 corrects the test; a live Windows run is still needed to verify installation/upgrade and publishing.
- Custom NSIS is *not* the official PortableApps.com Installer. Its `.paf.exe` extension is not evidence of official provenance.
- NSIS false-positive detections are possible. Do not disable antivirus protection; use vendor review and release hashes.
- Brave Windows encryption may bind secrets to the local Windows account despite an otherwise portable profile.
- Upstream binary redistribution may have browser branding/licensing constraints. Project uses noncommercial/independent metadata but users must review actual Brave redistribution terms before public releases.
- Package Builder v1.0.0 and Release Publisher v1.1.1 are pinned to their published tags; update intentionally after testing.
- Failure during Windows setup may preserve a `.__UPB_Backup` directory for recovery. Never remove it without inspecting its contents.

See `docs/PORTABILITY-AUDIT.md` for application-specific trace limitations. New r11 notes: `docs/R11-LOG-ANALYSIS.md`. Earlier findings: `docs/R9-LOG-ANALYSIS.md`.

## r11 correction: distinguish successful NSIS installations from intentional rejections

The r10 GitHub Actions log confirms that Brave binaries, ZIP, and custom NSIS PAF were built and validated. The final installer test then produced `NSIS incorrectly allowed installation into an unrelated folder`. That message came from an incorrect `else` in the *test*: an expected install returning exit code `0` was wrongly evaluated as if it were a deliberately rejected install.

r11 adds `scripts/installer-result-utils.ps1` and `scripts/test-installer-outcomes.ps1`. The new early PowerShell test covers permitted success (`0`), rejected unrelated folders (nonzero), unexpectedly failed installs, and unexpectedly allowed unrelated installs. The actual first-install and upgrade checks still verify binary hashes, obsolete Brave version cleanup, user profile preservation, empty directories and unchanged unrelated host markers.

The independent `vhick/Portable-Package-Builder@v1.0.0` and existing working Go launcher/TraceGuard are unchanged. **A real Windows run is still required** to confirm installation, upgrade testing, and publication. See `docs/R11-LOG-ANALYSIS.md`.
