# Brave Windows portable audit — independent builder r6 (2026-11-03)

## Evidence, application and build approach

- Brave Windows is a Chromium-based, multiprocess browser with Brave-specific modifications. `brave/brave-browser` carries official releases, issues and build documentation; `brave/brave-core` holds core build logic and patches. Full compilation uses Chromium depot_tools/gclient, GN/Ninja and many dependencies. Upstream describes downloading over 60 GB for source sync. A GitHub-hosted Windows source build is therefore NOT the supported mode of this budget-conscious kit.
- Instead, the kit resolves an official stable release tag and commit; verifies the official uninstalled `brave-v<version>-win32-x64.zip` release asset **size and GitHub SHA256 digest**, tests the ZIP archive, and extracts its complete executable directory. It never installs Brave on the runner and never compiles modified Brave/Chromium code. If upstream asset names/layout/digest change, stop safely rather than substituting random downloads.
- Only the independent Go Windows launcher is compiled. A pinned MIT resource compiler embeds the official icon extracted from `brave.exe`.
- Windows 10+ per official current Brave system requirements, x64 only. The portable launcher does not request elevation.

## Source-supported storage and limitations

| Location / integration | Source or basis | Implementation | Unavoidable limitation |
|---|---|---|---|
| `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data` | Brave support documentation on profile removal and profile paths | `--user-data-dir=<portable>\Data\profile` before first process start | Windows DPAPI ties encrypted secrets to OS account; moving the directory may not make passwords/cookies readable elsewhere |
| `Data\profile\Default`, `Profile 1`, `Local State`, `History`, `Bookmarks`, cookies, caches, extensions | Chromium/Brave profile layout | Automatically inside Data when Brave respects `--user-data-dir` | Some machine/drive-specific absolute settings may require manual repair |
| `%LOCALAPPDATA%\BraveSoftware` | Brave crash reports and other Brave-owned components | TraceGuard snapshots this *narrow ownership scope*, copying new/empty directories and owned files to Data | Existing host BraveSoftware root is NOT moved or deleted; non-attributable differences quarantined |
| `%APPDATA%\BraveSoftware` | Defensive ownership scope, not proof of current Brave writes | Same monitored roots | Other unknown paths cannot be assigned to Brave safely without privileged telemetry |
| `%PROGRAMDATA%\BraveSoftware` | Defensive ownership scope; installed Brave updater services can use system locations | Same monitored roots | Existing system-wide updater services/registry entries are NEVER modified by this launcher |
| Windows user Downloads, desktop, file associations | Browser/system integrations | Leave user-chosen file save destinations and existing browser registrations unchanged | Downloaded user content may be outside Data by choice; browser remains able to register protocols if user initiates it |
| `HKCU` / `HKLM` Brave registration and Windows Update services | Windows installer/service integration; exact keys are build-dependent | No registry key is modified or restored by this kit | No claim of zero registry or OS telemetry traces. Specific keys not audited in running Windows; use ProcMon if required |
| `%TEMP%` / crash logs | Chromium subprocess activity | `--disable-logging`, `--disable-breakpad`; TraceGuard observes known roots | Browser subprocesses, OS caching and temporary files can occur elsewhere. Arbitrary temp sweeping is unsafe and not implemented |

## Exact arguments

The launcher always sets `--user-data-dir=Data\profile` with an absolute resolved path and passes:

```
--disable-brave-update
--no-default-browser-check
--disable-logging
--disable-breakpad
--disable-machine-id
--disable-encryption-win
--no-first-run
```

These match the Portapps Brave reference arguments, plus first-run suppression.
**Important:** Portapps crafted `--disable-machine-id` and `--disable-encryption-win` for its own patched Chromium-based builds. They are *not* demonstrated to work in an unmodified official Brave release. The launcher passes them verbatim but does not claim they disable native Windows DPAPI encryption. Do not use this setup to transport unencrypted credentials or to work around Windows protected secrets.

## TraceGuard ownership and recovery model

1. The launcher takes a named Windows mutex based on its root path; duplicates are rejected.
2. It observes only ownership-scoped `%APPDATA%\BraveSoftware`, `%LOCALAPPDATA%\BraveSoftware`, `%PROGRAMDATA%\BraveSoftware`, never entire shared Windows folders.
3. It snapshots paths (including directories) and records whether each root existed. It restores only previously captured entries that do not conflict with host data.
4. It launches real `brave.exe` with an isolated profile, waits for the launched parent process, then compares observed files/directories. It preserves empty directories, nested directory trees and files with SHA256 checks.
5. If the scoped host root *did not exist at launch*, newly created paths are copied and verified in `Data\TraceGuard\Owned\<Root>\...`. Only individually verified owned files and empty directories are removed. If the host root existed already, newly created entries are **copied only** to `Data\TraceGuard\Quarantine\...` with host content left intact. This conservatism is intentional to protect local Brave installations.
6. `manifest.json` retains owned external paths relative to the scope. On the next start they are restored only if missing. A previous unclean session triggers non-destructive `CrashRecovery` copies, not blind deletion.
7. If an external file is locked, modified while cleaning, unreadable, or cannot be backed up, the launcher leaves it in place and reports the failure in `Data\TraceGuard\launcher.log`.
8. No arbitrary filesystem tracing/ETW, registry redirection, driver/service management, or guaranteed child-process ownership is implemented. These cannot safely be inferred by a user-mode launcher without additional permissions and evidence. Thus the request for automatic attribution of *all unknown paths anywhere on Windows* is **not fully achievable** under the no-admin/no-unrelated-host-modification constraints.

### Portable data locations

- `Data\profile`: Browser settings, sessions, cookies, databases, profiles, local state, extensions, caches.
- `Data\TraceGuard\Owned`: Safely captured app-owned files and empty folders, indexed by original root and relative path.
- `Data\TraceGuard\Quarantine`: Non-destructive copies of changes under host roots which already existed.
- `Data\TraceGuard\CrashRecovery`: Non-destructive copies from a previously interrupted run.
- `Data\TraceGuard\manifest.json`: Owned-path relocation manifest.
- `Data\TraceGuard\launcher.log`: Execution, collision, cleanup, and recovery diagnostics.

### Non-guarantees

- Cross-Windows-account encrypted Brave secrets, app-bound keys, existing installed services, and Brave Rewards/Wallet portability are NOT guaranteed. Back up wallets/keys using the application's supported procedures before moving disks.
- No guarantee that future Brave releases will publish an uninstalled x64 ZIP with the same layout or accept the listed flags.
- No permanent host footprint elimination. OS-level caches, Jump Lists, prefetch, network caches, Windows logs, shortcuts created by users, and system features can leave traces.
- The monitor does not make a hard claim that unrelated writes to a brand-new observed directory are impossible; avoid launching an installed Brave concurrently during trace verification.

## Validation evidence classification

- Unit tests for two files, nested nonempty, empty and deeply nested empty directories, host content preservation, and manifest traversal rejection: actually run successfully in a Linux container at kit authoring time.
- Go launcher cross-compilation to a real 64-bit Windows PE GUI executable: actually run successfully at kit authoring time.
- GitHub Actions Windows startup, actual stable browser ZIP retrieval, official installer download/build, full installer validation and publisher upload: NOT RUN in the author's environment and must be demonstrated in a real GitHub Actions log.
- PortableApps Menu launch and PAF upgrade over a user's Data: requires separate manual Windows acceptance tests.

## Sources

- https://github.com/brave/brave-browser
- https://github.com/brave/brave-core
- https://github.com/brave/brave-browser/wiki/Brave-Browser-Build-Deconstructed-%E2%80%90-overview-of-the-underlying-tools
- https://support.brave.app/hc/en-us/articles/4413256282765-How-do-I-delete-my-data-in-Brave
- https://support.brave.app/hc/en-us/articles/29808985123085-Sensitive-data-storage
- https://github.com/portapps/brave-portable/blob/master/main.go
- https://portableapps.com/manuals/PortableApps.comLauncher/ref/paf/appinfo.html
- https://portableapps.com/manuals/PortableApps.comLauncher/ref/paf/installer.html
- https://sourceforge.net/projects/portableapps/files/PortableApps.com%20Installer/
- https://github.com/vhick/portable-release-publisher/blob/v1.1.1/action.yml
- https://brave.com/terms-of-use/

## r5 direct ZIP correction (2026-11-03)
The uploaded r4 log establishes that the EXE was downloaded, but the updater installer did not contain `chrome.7z` as the builder required. The direct x64 ZIP removes that incorrect installer assumption. Exact-release filename matching rejects 32-bit, ARM, symbols and Brave Origin archives; GitHub-published SHA-256 and 7z archive testing are mandatory. The binary `brave.exe` must be unique and PE-valid. The full sibling resource tree and empty directories are copied intact to `App\Brave`. The browser ZIP still contains official Brave binaries, NOT a compile-from-source output.

## r6 bounded unattended smoke correction — 2026-11-03

The r5 GitHub Actions runner successfully downloaded and extracted the exact official Brave ZIP, and compiled the native launcher. Its `Start-Process -Wait` smoke step timed out after four minutes. PowerShell documents that `-Wait` waits for a process *tree*, not only the launched PID. Also, the launcher displayed an interactive MessageBoxW on error. The log contains no browser output, so one cannot isolate which condition caused the hang. r6 uses a bounded wait on only the directly launched process; smoke-mode errors go to an on-disk log without dialogs; output and failure details are displayed in Actions; and the CI test only terminates its own known launcher PID on timeout.
