. "$PSScriptRoot/release-utils.ps1"
$ErrorActionPreference='Stop'
function Check([bool]$condition,[string]$message) {
    if (-not $condition) { throw "Release resolver regression test failed: $message" }
}
$stable=[pscustomobject]@{ tag_name='v1.98.63'; name='Release v1.98.63 (Chromium 156.0.8078.80)'; draft=$false; prerelease=$false }
$preview=[pscustomobject]@{ tag_name='v1.98.64'; name='Release v1.98.64 (Chromium 156.0.8078.80)'; draft=$false; prerelease=$true }
$nightly=[pscustomobject]@{ tag_name='v1.101.11'; name='Nightly v1.101.11 (Chromium 157)'; draft=$false; prerelease=$false }
$beta=[pscustomobject]@{ tag_name='v1.100.46'; name='Beta v1.100.46'; draft=$false; prerelease=$false }
Check (Test-BraveStableRelease $stable) 'stable release excluded'
Check (-not (Test-BraveStableRelease $preview)) 'preview release accepted'
Check (-not (Test-BraveStableRelease $nightly)) 'nightly release accepted'
Check (-not (Test-BraveStableRelease $beta)) 'beta release accepted'
# Simulate Brave's large release asset list (>100, standalone installer late).
$assets=New-Object 'System.Collections.Generic.List[object]'
for($i=0;$i -lt 160;$i++) {
    $assets.Add([pscustomobject]@{ name="other-file-$i.zip"; size=20000000; digest=('sha256:' + ('a' * 64)) })
}
$assets.Add([pscustomobject]@{ name='BraveBrowserSetup.exe'; size=1220000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='BraveBrowserStandaloneSetup32.exe'; size=149000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='BraveBrowserStandaloneSetupArm64.exe'; size=164000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='BraveBrowserStandaloneSetup.exe'; size=160000000; digest=('sha256:' + ('c' * 64)) })
$found=Select-BraveWindowsX64Asset -Assets $assets.ToArray()
Check ($null -ne $found) 'x64 standalone asset not selected'
Check ($found.name -eq 'BraveBrowserStandaloneSetup.exe') 'selected wrong architecture or installer'
Check ($null -eq (Select-BraveWindowsX64Asset -Assets @($assets[0],$assets[1]))) 'unknown asset selected'
Write-Host 'PASS: stable, prerelease, beta/nightly, explicit Windows x64 asset, 160+ asset scenarios'
