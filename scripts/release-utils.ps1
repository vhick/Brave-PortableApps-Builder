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

# The uninstalled official Windows x64 distribution is the primary and ONLY
# supported input. Never select update installers, 32-bit, ARM64, symbols,
# Brave Origin, or similarly named checksum files.
function Select-BraveWindowsX64Asset {
    param([Parameter(Mandatory)][object[]]$Assets,
          [Parameter(Mandatory)][string]$Version)
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid stable version: $Version" }
    $expected = "brave-v$Version-win32-x64.zip"
    $candidates = @($Assets | Where-Object { $_.name -ceq $expected })
    if ($candidates.Count -gt 1) { throw "Ambiguous official browser ZIP assets named $expected" }
    if ($candidates.Count -eq 1) { return $candidates[0] }
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
