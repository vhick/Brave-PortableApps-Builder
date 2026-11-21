"""Cheap platform-neutral regression checks; no Brave download needed."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
workflows = list((ROOT/'.github/workflows').glob('*.yml')) + list((ROOT/'.github/workflows').glob('*.yaml'))
assert len(workflows) == 1, f'Expected exactly one workflow, found {workflows}'
wf=workflows[0].read_text(encoding='utf-8')
for required in ['workflow_dispatch:', 'windows-2022', 'scripts/resolve.ps1', 'scripts/test-unified-guards.ps1', 'scripts/test-upgrade-fixture.ps1', 'scripts/test-installer-outcomes.ps1', 'scripts/download-extract.ps1', 'scripts/stage.ps1', 'scripts/smoke.ps1', 'scripts/package.ps1', 'scripts/validate.ps1',
                 'vhick/Portable-Package-Builder@v1.0.0', 'vhick/portable-release-publisher@v1.1.1', 'engine: custom-nsis', 'source-dir: work/BravePortable',
                 'dist/*.zip;dist/*.paf.exe', 'scripts/test-unified-upgrade.ps1', 'dry-run: \'true\'', 'dry-run: \'false\'']:
    assert required in wf, f'Missing core integration step: {required}'
for forbidden in ['actions/upload-artifact', 'scripts/paf.ps1', 'brave-custom-nsis-paf.yml', 'build-paf-from-release.yml']:
    assert forbidden not in wf, f'Obsolete/unsupported integration remains: {forbidden}'
assert wf.count('vhick/Portable-Package-Builder@v1.0.0') == 1
assert wf.count('vhick/portable-release-publisher@v1.1.1') == 2
assert (ROOT/'scripts/resolve.ps1').read_text().count("BuilderRevision='r11'") == 1
assert 'brave-r11' in (ROOT/'scripts/package.ps1').read_text()
assert 'brave-r11' in (ROOT/'scripts/check-release.ps1').read_text()
assert 'portable-v1.98.63-brave-r11' in (ROOT/'scripts/test-release-check.ps1').read_text()
assert 'brave-r11' in (ROOT/'scripts/validate-unified.ps1').read_text()
assert 'Get-ChildItem' in (ROOT/'scripts/test-unified-upgrade.ps1').read_text() or 'OLD_BINARY' in (ROOT/'scripts/test-unified-upgrade.ps1').read_text()
assert not (ROOT/'scripts/paf.ps1').exists()
assert not (ROOT/'scripts/nsis-paf').exists()
print('PASS: single workflow, one shared packager, both mandatory outputs, publisher dry-run/live, no legacy PAF builders.')

# Regression: r8 failed only after successful Brave and NSIS compilation by
# passing Get-FileHash.Hash (string) as the [bool] Require argument. Its next
# steps had the same bug for RUNNER_TEMP and GH_TOKEN.
common=(ROOT/'scripts/common.ps1').read_text(encoding='utf-8')
final=(ROOT/'scripts/validate-unified.ps1').read_text(encoding='utf-8')
upgrade=(ROOT/'scripts/test-unified-upgrade.ps1').read_text(encoding='utf-8')
published=(ROOT/'scripts/check-published.ps1').read_text(encoding='utf-8')
assert 'function Test-Sha256Hex' in common and 'function Test-NonBlank' in common
assert 'Require (Test-Sha256Hex -value' in final
assert 'Require ((Get-FileHash -LiteralPath $zip[0].FullName -Algorithm SHA256).Hash)' not in final
assert 'Require (Test-NonBlank -value $env:RUNNER_TEMP)' in upgrade
assert 'Require (Test-NonBlank -value $env:GH_TOKEN)' in published
assert "run: ./scripts/test-unified-guards.ps1" in wf
assert not re.search(r'Require\s*\(\$env:\w+\)', final+upgrade+published)
print('PASS: fixed Boolean argument handling in final validation, upgrade test, and publisher verification.')

# r9 NSIS exit code 2: the first-install destination was created prematurely.
# The shared NSIS v1.0.0 rejects present destinations using a wildcard check,
# including empty directories on some NSIS implementations.
upgrade_fixture=(ROOT/'scripts/installer-fixture.ps1').read_text(encoding='utf-8')
assert 'New-Item -ItemType Directory -Force $testRoot,$outside' in upgrade_fixture
assert 'New-Item -ItemType Directory -Force $dest' not in upgrade_fixture
assert 'Require (-not (Test-Path -LiteralPath $dest))' in upgrade_fixture
assert 'Initialize-UpgradeInstallTest -RunnerTemp $env:RUNNER_TEMP' in upgrade
assert 'scripts/test-upgrade-fixture.ps1' in wf
print('PASS: first installer destination is absent; unrelated host marker remains.')

# Release/tag and metadata consistency: previous r11 draft caught stale r9
# in validation and release titles, which otherwise fails after downloading.
for path in ['scripts/validate.ps1','scripts/validate-unified.ps1']:
    value=(ROOT/path).read_text(encoding='utf-8')
    assert "BuilderRevision -ceq 'r11'" in value, f'Bad revision guard in {path}'
assert 'Portable r11' in (ROOT/'scripts/stage.ps1').read_text(encoding='utf-8')
assert 'independent NSIS PAF (r11)' in wf
assert 'independent NSIS PAF (r9)' not in wf
print('PASS: staging, revision metadata, release titles and validation agree on r11.')

# r10 produced both packages but the installer test incorrectly classified
# exit code 0 as an unrelated-destination failure. Ensure branches are
# exclusive and both outcomes have pre-download Windows regression tests.
helper=(ROOT/'scripts/installer-result-utils.ps1').read_text(encoding='utf-8')
installer_test=(ROOT/'scripts/test-unified-upgrade.ps1').read_text(encoding='utf-8')
unit=(ROOT/'scripts/test-installer-outcomes.ps1').read_text(encoding='utf-8')
assert 'if ($ExpectSuccess)' in helper and '} else {' in helper
assert 'Require ($ExitCode -eq 0)' in helper
assert 'Require ($ExitCode -ne 0)' in helper
assert 'Assert-InstallerOutcome -ExitCode $exitCode -ExpectSuccess $ExpectSuccess' in installer_test
assert 'if($ExpectSuccess -and $process.ExitCode -ne 0)' not in installer_test
assert 'Assert-InstallerOutcome -ExitCode 0 -ExpectSuccess $true' in unit
assert 'Assert-InstallerOutcome -ExitCode 2 -ExpectSuccess $false' in unit
assert 'Assert-InstallerOutcome -ExitCode 0 -ExpectSuccess $false' in unit
assert 'run: ./scripts/test-installer-outcomes.ps1' in wf
print('PASS: installer result regression tests classify exit 0 correctly and fail unsafe installs.')

assert "brave-r11$" in (ROOT/"scripts/check-published.ps1").read_text(encoding="utf-8")
print("PASS: published-release tag verification agrees with r11.")
