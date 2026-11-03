# Shared, pure checks for Brave stable releases and Windows x64 release assets.
# Kept separate from network access so CI can regression-test release selection.
Set-StrictMode -Version Latest

function Test-BraveStableRelease {
    param([Parameter(Mandatory)] [object]$Release)
    if ($Release.prerelease -or $Release.draft) { return $false }
    if (-not ($Release.tag_name -match '^v\d+\.\d+\.\d+$')) { return $false }
    # Brave names its channels Release/Beta/Nightly. Do not trust the tag alone:
    # a prerelease can still have a normal-looking numeric tag.
    if (-not ($Release.name -match '(?i)^Release\s+v\d+\.\d+\.\d+(?:\s|\(|$)')) { return $false }
    if ($Release.name -match '(?i)nightly|beta|dev|alpha|preview|canary') { return $false }
    return $true
}

function Select-BraveWindowsX64Asset {
    param([Parameter(Mandatory)] [object[]]$Assets)
    # Exactly match the upstream's x64 offline installers; avoid the tiny web
    # bootstrapper, 32-bit, ARM64, and the silent installer variants.
    foreach ($pattern in @(
        '^BraveBrowserStandaloneSetup\.exe$',
        '^BraveBrowserStandaloneSetup_\d+_\d+_\d+_\d+\.exe$',
        '^BraveBrowserStandaloneSetup64(?:_\d+_\d+_\d+_\d+)?\.exe$',
        '^brave_installer-x64\.exe$'
    )) {
        $matchingAssets = @($Assets | Where-Object { $_.name -match $pattern })
        if ($matchingAssets.Count -eq 1) { return $matchingAssets[0] }
        if ($matchingAssets.Count -gt 1) { throw "Ambiguous x64 offline Brave assets matching $pattern" }
    }
    return $null
}


# Invoke-RestMethod can write a JSON array as ONE object into the PowerShell
# pipeline. In that case @(Invoke-RestMethod ...) holds a nested Object[] and
# Count is 1, even when GitHub returned 100 release assets. Normalize both
# the direct and nested forms. This function emits one ASSET per pipeline item.
function Expand-BraveReleaseAssetPage {
    param([AllowNull()][object]$Page)
    if ($null -eq $Page) { return }
    foreach ($entry in @($Page)) {
        if ($null -eq $entry) { continue }
        if ($entry -is [System.Array]) {
            foreach ($asset in $entry) { $asset }
        } else {
            $entry
        }
    }
}
