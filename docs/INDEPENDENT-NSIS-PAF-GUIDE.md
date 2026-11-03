# Brave Portable r7 — Independent NSIS PAF-style installer workflow

## Purpose and exact provenance

This adds a SECOND workflow, `.github/workflows/brave-custom-nsis-paf.yml`, to the previously verified Brave r7 PortableApps builder. The original `.github/workflows/build.yml`, native `BravePortable.exe` source, TraceGuard, source retrieval, and original release are unchanged.

The workflow takes the **already published** r7 release ZIP (`BravePortable_1.98.63_brave-r7_Win64.zip` for the example default tag) from the SAME repository, verifies its published SHA-256 checksum, validates/extracts the package, compiles a new independent Windows installer via `makensis.exe`, tests it, and publishes it to a NEW release tag. No Brave upstream download, no Go launcher compilation, no browser smoke retest, and no Actions artifact uploads.

**This installer is not produced by the unmodified PortableApps.com Installer, and is neither an official PortableApps.com Installer artifact nor certified/endorsed by PortableApps.com.** The `.paf.exe` extension is used to indicate a PortableApps-style install layout, not official provenance. PortableApps.com Format 3.9 specifies the official installer for formally compliant distributions; if strict official Format compliance or distribution under its official tool permissions is required, the genuine installer must still be used. See https://portableapps.com/development/portableapps.com_format.

A custom independent installer may also be subject to third-party branding, source attribution, software redistribution and trademark restrictions. Confirm permission before making a public release. The workflow does not sign its executable and cannot guarantee an antivirus verdict.

## What it produces

Example with the existing r7 source release:

- Source release tag: `portable-v1.98.63-brave-r7`
- Source asset: `BravePortable_1.98.63_brave-r7_Win64.zip`
- New output asset: `BravePortable_1.98.63_brave-r7_custom-nsis-r1_Win64.paf.exe`
- New release tag: `portable-v1.98.63-brave-r7-custom-nsis-paf-r1`

Only the new PAF-style installer and a new `SHA256SUMS.txt` are published to the new release. The original ZIP remains on the untouched r7 release.

## Build sequence

1. Validate source release metadata and filenames before downloading large assets.
2. Check whether the exact new NSIS release tag already exists. Skip if it does; never overwrite it.
3. Locate `makensis.exe`; if missing, install NSIS 3.12.0 using Chocolatey and check the compiler.
4. Build and silently install a tiny **synthetic fixture** using the SAME `.nsi` source. Confirm first installation, upgrade with existing personal data, nested nonempty and entirely empty directories, foreign destination rejection, and locked-executable rejection.
5. Download only the existing r7 ZIP and `SHA256SUMS.txt` from the same GitHub repository. Verify exact SHA-256 and inspect every ZIP member for path traversal, symlinks, unexpected roots and personal Data files.
6. Run `7z t`, extract and validate `BravePortable.exe`, `brave.exe`, `appinfo.ini`, the icon, `upstream.json`, the AppID and matching upstream release version.
7. Compile the community `.paf.exe` directly with `makensis.exe`. It has a 15-minute bounded compiler timeout, output/error logs and explicit failure codes.
8. Check PE structure and NSIS archive integrity; extract the embedded payload for SHA-256 comparisons against the verified source launcher, browser, metadata and icon.
9. Silently install the **actual full community NSIS package** into an isolated disposable directory, validate its contents and compare SHA-256 hashes with the source browser and launcher.
10. Run `vhick/portable-release-publisher@v1.1.1` dry-run, then publish the exact validated file under a new release tag. Automatic pruning remains disabled.
11. Confirm the published installer and `SHA256SUMS.txt` are present.

## Installer safety rules

- The compiled installer embeds **only** the root `BravePortable.exe`, `App` and `Other`. It does not embed `Data`, does not delete or overwrite the existing `Data` directory, and never runs `RMDir /r` on any portable application directory.
- It creates `Data` only if necessary. Existing files and nested empty directories remain untouched.
- It refuses a destination containing unrelated content or a conflicting AppID.
- It uses exclusive-file probes on the existing `BravePortable.exe` and `App\Brave\brave.exe` to reduce the chance of upgrading while running. A locked or inaccessible file aborts. This is best-effort protection, not a process supervisor.
- The executable requires user-level privileges, writes no Windows registry keys, installs no services, adds no system startup entries and does not manipulate other installed browsers.
- It **overlays** the prior `App` and `Other` application files, without cleaning stale files. If you need a major-version migration or incompatible layout cleanup, handle that separately with an application-specific tested migration. Power failure during installation could leave partially replaced application binaries; back up before important upgrades.
- It cannot resolve Windows DPAPI-bound browser passwords/cookies across different user accounts or devices. Those limitations remain those of the r7 launcher and Brave.
- The default directory is `Documents\PortableApps\BravePortable` for standalone use. If launched from a Platform root or its `PortableApps` directory, the installer attempts to detect that layout. A user can select the exact `X:\PortableApps\BravePortable` location manually. Explicit NSIS `/D=` takes precedence.
- The resulting installer supports normal interactive installation. Its **compilation** is fully headless. It also supports NSIS ` /S /D=<full-app-folder>` for tests and automation. That silent switch is specific to our own independent NSIS code, not the official PortableApps.com Installer.

## GitHub Desktop: apply to existing repository

1. Back up your existing source folder if desired; your published r7 ZIP stays safe on GitHub Releases regardless.
2. Extract the provided complete ZIP. Open your existing `Brave-PortableApps-Builder` repository in GitHub Desktop, then choose **Repository -> Show in Explorer**.
3. Copy all files from the extracted kit into that folder, preserving `.github`. This is the full r7 builder plus the new packaging workflow and scripts, not an unrelated project. The original `.github/workflows/build.yml` and launcher/TraceGuard source are carried forward unchanged.
4. In GitHub Desktop, review changed files: only the new `.github/workflows/brave-custom-nsis-paf.yml`, `scripts/nsis-paf/*`, documentation and README should be new or modified. Commit with `Add independent headless Brave NSIS PAF workflow`, then **Push origin**.
5. Open GitHub -> **Actions** -> **Brave PAF-style Installer (community NSIS - reuse verified r7 ZIP)** -> **Run workflow**.
6. Keep `source_tag=portable-v1.98.63-brave-r7` and `publish=true` to produce the independent installer for your existing r7 release. Leave the original **Brave PortableApps** workflow alone.
7. Upon success open **Releases**; find `portable-v1.98.63-brave-r7-custom-nsis-paf-r1` and download the `.paf.exe`. Compare SHA-256 with that release's `SHA256SUMS.txt`.
8. **For an existing portable profile:** make a copy of the original `BravePortable\Data` first and close Brave Portable completely. Run the installer, selecting **the existing** `X:\PortableApps\BravePortable` folder, not the parent `PortableApps` folder. The installer should leave Data intact. Verify your profile after upgrading.
9. **For a new installation:** select `X:\PortableApps\BravePortable` as the destination app folder; then open or refresh the PortableApps Menu and launch Brave Portable. No conventional Brave installation is needed.

## If the workflow fails

- **Preflight fails:** source release tag is not r7 or does not include ZIP + SHA256SUMS.
- **Checksum mismatch:** stop; do not use an unverified release asset.
- **Fixture fails:** do not continue to the full browser; inspect the synthetic install step for NSIS path/permission/lock behavior.
- **NSIS compiler fails:** inspect `work/nsis-paf/makensis-output.log` from the GitHub Actions console output. The workflow prints its tail automatically on success and should print a useful error on failure.
- **PE or payload hashes fail:** treat installer as invalid, do not publish.
- **Existing target release found:** workflow skips safely. To publish a materially different installer, increment the `nsis-r1` revision and tag in scripts/workflow/tests before building again, rather than overwriting a release.
- **Platform does not recognize the installer as official:** this is possible because it is not generated by the official PortableApps.com Installer. You can still install it manually to the correct app folder, or use the already verified r7 ZIP. Do not claim official certification.

## Validation status

This toolkit has been statically checked and bundled in a ZIP. The r7 Brave ZIP has already passed a real GitHub Actions build as shown in the uploaded successful workflow logs. The NEW independent NSIS script, its Windows first-install/upgrade tests, 7-Zip NSIS payload extraction and publication have **not yet run on GitHub Actions** at delivery time. Only a successful workflow run will establish them as working.
