# Independent NSIS PAF add-on for the verified Brave r7 builder

This add-on adds a SECOND manual workflow to the existing repository. It does not replace the original `.github/workflows/build.yml`, Brave launcher source, or TraceGuard.

**No official PortableApps.com Installer is used here.** The generated `.paf.exe` is an independently compiled NSIS PortableApps-style installer, with no official PortableApps.com certification or endorsement.

## Install add-on using GitHub Desktop

1. Download `Brave-r7-Custom-NSIS-PAF-AddOn-r1.zip` and extract it.
2. In GitHub Desktop open your existing `Brave-PortableApps-Builder` repository and choose **Repository -> Show in Explorer**.
3. Copy the add-on's `.github`, `scripts`, and `docs` directories into the repository, merging folders rather than replacing the whole `scripts` directory. These paths contain new filenames only, preserving your original r7 files.
4. Commit `Add independent headless NSIS PAF workflow`, then **Push origin**.
5. Open **GitHub -> Actions -> Brave PAF-style Installer (community NSIS - reuse verified r7 ZIP)** and click **Run workflow**.
6. Keep `source_tag=portable-v1.98.63-brave-r7` and `publish=true` for your verified r7 ZIP. This publishes an independent installer under a different tag without modifying the original r7 release.
7. Find the installer in **GitHub -> Releases**, under `portable-v1.98.63-brave-r7-custom-nsis-paf-r1`.

For more about Data protection, limitations, installation paths, testing and troubleshooting, read `docs/INDEPENDENT-NSIS-PAF-GUIDE.md`.

The first Windows run is required to verify the NSIS compilation and actual installer behavior. Local checks alone do not establish build success.
