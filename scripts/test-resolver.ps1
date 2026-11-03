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
# Simulate Brave's large release asset list (>100, official Windows x64 ZIP near the end).
$assets=New-Object 'System.Collections.Generic.List[object]'
for($i=0;$i -lt 160;$i++) {
    $assets.Add([pscustomobject]@{ name="other-file-$i.zip"; size=20000000; digest=('sha256:' + ('a' * 64)) })
}
$assets.Add([pscustomobject]@{ name='BraveBrowserSetup.exe'; size=1220000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='brave-v1.98.63-win32-ia32.zip'; size=149000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='brave-v1.98.63-win32-arm64.zip'; size=164000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='BraveBrowserStandaloneSetup.exe'; size=160000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='brave-v1.98.63-win32-x64-symbols.zip'; size=1600000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='brave-origin-v1.98.63-win32-x64.zip'; size=160000000; digest=('sha256:' + ('a' * 64)) })
$assets.Add([pscustomobject]@{ name='brave-v1.98.63-win32-x64.zip'; size=252900000; digest=('sha256:' + ('c' * 64)) })
# Regression for the REAL r2 failure: IRM wrote a 100-item JSON array as
# ONE pipeline object, and @(Invoke-RestMethod ...) miscounted it as 1.
$fullPage=@($assets.ToArray())
$nestedPage=,$fullPage
$expanded=@(Expand-BraveReleaseAssetPage -Page $nestedPage)
Check ($expanded.Count -eq $fullPage.Count) "nested Invoke-RestMethod asset page was not expanded"
Check ($expanded.Count -gt 100) "large page was counted as a single object"
Check ($expanded[-1].name -eq 'brave-v1.98.63-win32-x64.zip') 'asset ordering changed during normalization'
$direct=@(Expand-BraveReleaseAssetPage -Page $fullPage)
Check ($direct.Count -eq $fullPage.Count) 'direct JSON asset array was not enumerated'
$single=@(Expand-BraveReleaseAssetPage -Page $fullPage[-1])
Check ($single.Count -eq 1) 'a single JSON asset object was lost'
$empty=@(Expand-BraveReleaseAssetPage -Page @())
Check ($empty.Count -eq 0) 'empty GitHub asset page should remain empty'
$found=Select-BraveWindowsX64Asset -Assets $expanded -Version '1.98.63'
Check ($null -ne $found) 'x64 browser ZIP asset not selected'
Check ($found.name -eq 'brave-v1.98.63-win32-x64.zip') 'selected wrong architecture or installer'
Check ($null -eq (Select-BraveWindowsX64Asset -Assets @($assets[0],$assets[1]) -Version '1.98.63')) 'unknown asset selected'
Check ($null -eq (Select-BraveWindowsX64Asset -Assets $expanded -Version '1.98.64')) 'wrong version ZIP was selected'
$noZIP=@($expanded | Where-Object { $_.name -cne 'brave-v1.98.63-win32-x64.zip' })
Check ($null -eq (Select-BraveWindowsX64Asset -Assets $noZIP -Version '1.98.63')) 'falling back to EXE/symbols/Brave Origin is forbidden'
$duplicate = @($expanded) + @($found)
$duplicateRejected=$false
try { $null=Select-BraveWindowsX64Asset -Assets $duplicate -Version '1.98.63' } catch { $duplicateRejected=$true }
Check $duplicateRejected 'ambiguous ZIP must be rejected'
Write-Host 'PASS: stable, prerelease, beta/nightly, x64 ZIP, nested/direct/empty pages, 160+ assets'
