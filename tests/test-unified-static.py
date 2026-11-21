"""Cheap platform-neutral regression checks; no Brave download needed."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
workflows = list((ROOT/'.github/workflows').glob('*.yml')) + list((ROOT/'.github/workflows').glob('*.yaml'))
assert len(workflows) == 1, f'Expected exactly one workflow, found {workflows}'
wf=workflows[0].read_text(encoding='utf-8')
for required in ['workflow_dispatch:', 'windows-2022', 'scripts/resolve.ps1', 'scripts/test-unified-guards.ps1', 'scripts/download-extract.ps1', 'scripts/stage.ps1', 'scripts/smoke.ps1', 'scripts/package.ps1', 'scripts/validate.ps1',
                 'vhick/Portable-Package-Builder@v1.0.0', 'vhick/portable-release-publisher@v1.1.1', 'engine: custom-nsis', 'source-dir: work/BravePortable',
                 'dist/*.zip;dist/*.paf.exe', 'scripts/test-unified-upgrade.ps1', 'dry-run: \'true\'', 'dry-run: \'false\'']:
    assert required in wf, f'Missing core integration step: {required}'
for forbidden in ['actions/upload-artifact', 'scripts/paf.ps1', 'brave-custom-nsis-paf.yml', 'build-paf-from-release.yml']:
    assert forbidden not in wf, f'Obsolete/unsupported integration remains: {forbidden}'
assert wf.count('vhick/Portable-Package-Builder@v1.0.0') == 1
assert wf.count('vhick/portable-release-publisher@v1.1.1') == 2
assert (ROOT/'scripts/resolve.ps1').read_text().count("BuilderRevision='r9'") == 1
assert 'brave-r9' in (ROOT/'scripts/package.ps1').read_text()
assert 'brave-r9' in (ROOT/'scripts/check-release.ps1').read_text()
assert 'portable-v1.98.63-brave-r9' in (ROOT/'scripts/test-release-check.ps1').read_text()
assert 'brave-r9' in (ROOT/'scripts/validate-unified.ps1').read_text()
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
