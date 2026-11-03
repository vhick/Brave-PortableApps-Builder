# Brave PortableApps Builder r1

Independent, on-demand GitHub Actions builder for **official stable Brave Windows x64** binaries. Creates a ready-to-extract `BravePortable` ZIP and tries to build an authentic PortableApps.com Installer `.paf.exe`, using verified official tooling. Compiles a real `BravePortable.exe` GUI launcher with Brave's official icon, an isolated `Data\profile`, and conservative TraceGuard data recovery.

> **Status:** Builder source and portable recovery unit tests have been checked locally, and the launcher cross-compiles to a real Windows PE. **No live Windows Actions/PAF/Brave launch or release-publisher run has been completed at delivery.** This is a first revision, not an already confirmed working release. Expect possible upstream installer layout or CI adjustments; inspect logs before using it for valuable accounts.

## What it generates

| Requested output | Workflow behavior |
|---|---|
| `BravePortable_VERSION_brave-r1_Win64.zip` | Default. Contains `BravePortable/BravePortable.exe` + original Brave binaries + required PortableApps menu files. |
| `BravePortable_VERSION_brave-r1_Win64.paf.exe` | Attempted by default using SHA-verified **unmodified official PortableApps.com Installer 3.9.22**. Only published if PE/archive/payload validation passes. |
| SHA-256 hashes | Calculated during building. The existing release publisher also performs its own checksumming. |
| Browser source compilation | **No.** Brave/Chromium source build exceeds the intended GitHub Free workflow budget; the source-tagged original vendor binaries are SHA-256 verified and extracted. Only the portable launcher is compiled. |

No unofficial renamed ZIP, installer substitution, CMD wrapper, or generated placeholder icon is used. Generated files remain in GitHub Releases; no `actions/upload-artifact` storage, no scheduled runs, and no Git LFS.

## Key controls

The manual GitHub Actions workflow accepts:

- **version:** blank means the highest actual stable `Release vX.Y.Z` among recent GitHub releases. Preview, Beta, Nightly, Dev and drafts are rejected.
- **attempt_paf:** `true` default. Attempts genuine official PAF packaging.
- **require_paf:** `false` default. When `true`, a failed official-tool installer causes the workflow to fail. When `false`, it keeps the valid ZIP.
- **publish:** `true` default. Runs `vhick/portable-release-publisher@v1.1.1` in preview/dry-run and then publishing mode.

Publisher controls: uses `files`, `tag`, `release-title`, `tag-prefix`, `keep-releases`, `prune` and `dry-run` as declared by verified `action.yml`. Tags are `portable-vX.Y.Z-brave-r1`. If the tag already has a release, the workflow skips expensive steps rather than overwriting assets. It retains the release publisher's default of three recent releases **only if pruning is enabled**, but this builder sets `prune: false`, so NO automatic deletion occurs. Manual releases remain unaffected. Public repositories publish public releases and private repositories publish private releases; visibility is never modified.

## GitHub Desktop: beginner setup

1. Download the **builder ZIP** attached to the chat response. Extract it somewhere convenient on your Windows PC.
2. Start **GitHub Desktop**, choose **File → New repository**. For example, enter `Brave-PortableApps-Builder`. Choose your normal GitHub repositories folder. Create the repository. Do not fork the Brave browser repository.
3. Open the new repository location using **Repository → Show in Explorer**. Copy **the contents inside the builder ZIP** into this folder. At the top level you should see `README.md`, `go.mod`, `cmd`, `internal`, `scripts`, `docs`, `.github`, `.gitignore`. Enable *Show hidden items* in Windows Explorer if `.github` and `.gitignore` are hidden. Keep `.github/workflows/build.yml` inside `.github`.
4. Return to GitHub Desktop. It should show new/changed source files. Enter summary `Add Brave PortableApps Builder r1`, then click **Commit to main**.
5. Click **Publish repository**. Pick **Private** by default while verifying the build and evaluating Brave branding/redistribution permissions. Uncheck **Keep this code private** only if you have decided public distribution is appropriate. This setting affects release visibility too.
6. Open the repository on GitHub in a browser. Navigate to **Settings → Actions → General → Workflow permissions**. Make sure the workflow can obtain **Read and write permissions** when publishing releases. In an organization, organization policy may override this setting.
7. Select **Actions** and enable workflows if GitHub prompts you. Click **Brave PortableApps (official Brave stable + native EXE launcher)** → **Run workflow**. Leave version blank for latest stable. Keep `attempt_paf=true`, `require_paf=false`. Keep `publish=true` after deciding your repository's visibility is acceptable. Click **Run workflow**.
8. Review each step. If the workflow succeeds, go to your builder repository's **Releases** (not Brave's upstream Releases). Download the generated ZIP, and the `.paf.exe` if it was successfully generated.
9. For a verified PAF, open PortableApps Platform and choose **Apps → Install a New App**, then choose the `.paf.exe`. Select the **parent PortableApps directory**, e.g. `E:\PortableApps`, not an already named `BravePortable` subfolder.
10. For the ZIP, unzip it so that the final launcher is exactly `E:\PortableApps\BravePortable\BravePortable.exe`. Do not create a second nested `BravePortable` folder. Restart or refresh the PortableApps Menu; launch **Brave Portable (Independent Build)**.
11. After closing Brave, inspect `E:\PortableApps\BravePortable\Data\profile` and `Data\TraceGuard` as described below. The profile must stay inside the portable folder. See **Manual Windows acceptance** below before relying on this for important data.

### Safe upgrade

**Back up the entire `BravePortable\Data` folder before upgrading**, including browser profile, wallet-related state and TraceGuard. Close the browser. For a true PAF, select the existing PortableApps parent directory and let the installer upgrade while preserving `Data` (`RemoveDataDirectory=false`). For a ZIP upgrade, manually replace `BravePortable.exe`, `App`, and `Other` only; **keep the existing `Data` folder untouched**. Do not copy a blank `Data` over your current Data. Never merge another Brave installation's profile into this one without separate migration checks.

### Where stored data goes

| Portable location | Purpose |
|---|---|
| `Data\profile` | Main browser profile, extensions, history, bookmarks, preferences and supporting caches |
| `Data\TraceGuard\Owned\LocalAppData`, `RoamingAppData`, `ProgramData` | Verified launcher-owned external files and directories; **empty directory trees are preserved** |
| `Data\TraceGuard\Quarantine` | Copies of new files/empty directories inside pre-existing host BraveSoftware folders. Existing host data is not moved, and these items are not automatically claimed as portable-owned |
| `Data\TraceGuard\CrashRecovery` | Non-destructive copies after a previous interrupted run |
| `Data\TraceGuard\manifest.json` | Relative locations for owned external directories/files |
| `Data\TraceGuard\launcher.log` | Cleanup, conflicts and launch errors |

The provided six additional flags are passed, but `--disable-encryption-win` and `--disable-machine-id` cannot be assumed functional in **unmodified official Brave**. Windows-protected secrets may be tied to the originating Windows user. See `docs/PORTABILITY-AUDIT.md`.

## Security and licensing

Official Brave code is under MPL 2.0, but this does **not** grant Brave trademark/brand rights. The standalone official installer and branded assets may require distribution review. Keep releases private until you are satisfied with licensing and permissions. This independent packaging is neither endorsed by Brave Software nor approved by PortableApps.com. The native launcher does not bypass profile encryption, disable antivirus, elevate, or modify registry entries.

The PortableApps.com Installer is SHA-256 verified against its official SourceForge project digest for **3.9.22** before use. If a newer stable official installer is released, update both its version and published SHA in `scripts/paf.ps1`. Do not replace it with an unknown downloaded executable.

## Troubleshooting

| Failure | What to check |
|---|---|
| `No stable Brave release found` | GitHub rate limiting, filtering and API availability; `version` must be an actual official stable tag |
| `No GitHub-published SHA256` | GitHub release assets are missing verified `digest`; fail closed rather than trusting a guessed checksum |
| `No supported official x64 offline installer` | The selected release's asset names changed. Examine official GitHub release metadata. Do not use unversioned current installer |
| `chrome.7z` not found | Upstream changed its Windows installer structure. Extraction must be adjusted only after examining a verified vendor asset |
| Browser smoke test fails | Check `work/BravePortable/Data/TraceGuard/launcher.log` from job log before cleanup; renderer/GPU/headless restrictions may differ by runner |
| PAF fails, ZIP succeeds | Check the official tool step and `work/paf-compiler.log`; optional mode allows ZIP-only publication. Verify current PAF tool version and CLI behavior |
| `Resource compiler` fails | `github.com/akavel/rsrc@v0.10.2` could not be downloaded/built, or official icon extraction failed; do not silently use a placeholder |
| Publisher fails | Inspect job `contents: write`, release tag conflicts, default `GITHUB_TOKEN` permissions, immutable tags and `v1.1.1` availability |
| Host folder already exists | TraceGuard intentionally copies suspected new entries to `Quarantine`, leaving host files alone. No automatic deletion or overwriting of local Brave data |
| Secrets fail after drive/computer switch | Browser DPAPI, OS account and newer app-bound protections; flags from the Portapps patched Chromium ecosystem do not remove these protections in official Brave |

## Manual Windows acceptance (must be done with disposable test profile)

- Check ZIP and any PAF with 7-Zip. Validate `BravePortable.exe` has the actual Brave icon; open Brave from PortableApps Menu.
- Check `brave://version` reports a profile path inside `BravePortable\Data\profile`.
- Add a bookmark, install a harmless extension and create a second browser profile; close, reopen, confirm persistence.
- With a dedicated clean Windows testing account/VM, check `AppData`, `LocalAppData`, `ProgramData` before/after. Verify newly created external files, nonempty nested directories, and empty nested directories under approved roots get copied to `Data\TraceGuard` and local pre-existing data remains intact.
- Simulate interrupt/crash: terminate the disposable test browser on the test VM only, relaunch, check `CrashRecovery` for non-destructive copies.
- Move `BravePortable` to a new folder/drive letter while closed, reopen and inspect bookmarks/settings. Repeat for a second Windows user and specifically test passwords/cookies; expect possible DPAPI failures.
- Test updating over an existing Data directory using the real PAF in PortableApps Platform and separately using ZIP file replacement.
- Do not claim that a manual test has passed until you perform and record it.

## Developer layout

```
.github/workflows/build.yml     one manual, single-job source-to-release workflow
cmd/braveportable/             genuine Go/Windows GUI PE launcher
internal/traceguard/          filesystem capture, empty directories, crash recovery, unit tests
scripts/resolve.ps1           stable release + commit + SHA256 asset metadata
scripts/download-extract.ps1  official Brave download and chrome.7z extraction
scripts/stage.ps1             PortableApps metadata, authentic icon, compiled EXE
scripts/smoke.ps1             actual headless Brave startup test on Windows runner
scripts/package.ps1           ZIP and SHA256
scripts/paf.ps1               unmodified, SHA-verified official-tool PAF build attempt
scripts/validate.ps1          metadata, PE, 7-Zip, embedded-payload checks
docs/PORTABILITY-AUDIT.md     complete scoped portability analysis
docs/NOTICE.txt              provenance/trademark/license notices
```

### Maintainer notes

- Revisions must increment the `r1` package/tag revision in all relevant files before rebuilding the same upstream version; existing releases intentionally block destructive overwrites.
- `actions/checkout@v4`, `actions/setup-go@v5`, `vhick/portable-release-publisher@v1.1.1` are version-tagged dependencies. SHA pinning of upstream actions is recommended once their exact commits have been independently verified.
- Source digest pinning protects browser assets. SHA256 pinning protects the official PAF tool. The build-time resource generator uses a pinned tagged Go module; its module checksum is verified by Go's module infrastructure.
- For guaranteed source compilation or absolute unknown-path attribution, a substantially different build environment, Windows instrumentation plan and separate testing project are needed; this release does not make those claims.
