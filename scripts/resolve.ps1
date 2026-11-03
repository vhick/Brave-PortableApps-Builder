param([string]$Version='')
. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/release-utils.ps1"

$headers=@{
    'User-Agent'='independent-brave-portable-builder'
    'Accept'='application/vnd.github+json'
    'X-GitHub-Api-Version'='2022-11-28'
}
if ($env:GITHUB_TOKEN) { $headers.Authorization="Bearer $env:GITHUB_TOKEN" }
$api='https://api.github.com/repos/brave/brave-browser'

if ($Version) {
    Require ($Version -match '^v?\d+\.\d+\.\d+$') 'Version must be a stable-style number such as 1.98.63'
    $requested=$Version.TrimStart('v')
    Write-Host "Resolving explicitly requested official Brave tag v$requested"
    $release=Invoke-RestMethod -Headers $headers -Uri "$api/releases/tags/v$requested" -TimeoutSec 45
} else {
    # Do not use /releases?per_page=100 as a stable detector. Brave generates
    # so many nightly/beta releases that a fixed first page can have no stable.
    Write-Host 'Resolving official latest non-prerelease Brave from /releases/latest'
    $release=Invoke-RestMethod -Headers $headers -Uri "$api/releases/latest" -TimeoutSec 45
}
Require (Test-BraveStableRelease -Release $release) "Selected $($release.tag_name) ($($release.name)) is NOT an official stable Brave release. Refusing preview/beta/nightly."
Require ($release.id -gt 0) 'GitHub response does not identify a release ID'
Write-Host "Validated official stable channel: $($release.name) ($($release.tag_name))"

# A Brave release can contain > 200 assets, far more than a typical API page.
# The release-detail response is NOT assumed to contain a complete assets list.
$assets=@()
$maxPages=8
$finished=$false
for($page=1;$page -le $maxPages;$page++) {
    $url="$api/releases/$($release.id)/assets?per_page=100&page=$page"
    # Do not wrap the cmdlet invocation directly in @(...). GitHub returns a
    # JSON array which Invoke-RestMethod can emit as a SINGLE nested Object[].
    # The dedicated expansion helper handles both shapes safely.
    $rawPage=Invoke-RestMethod -Headers $headers -Uri $url -TimeoutSec 45
    $batch=@(Expand-BraveReleaseAssetPage -Page $rawPage)
    if ($batch.Count -eq 0) { break }
    foreach ($entry in $batch) {
        if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['name'] -or
            $null -eq $entry.PSObject.Properties['id']) {
            throw "Invalid GitHub release asset metadata on page $page; refusing to treat a nested JSON array as one asset"
        }
    }
    $assets += $batch
    Write-Host "Read asset page ${page}: $($batch.Count) entries (total $($assets.Count))"
    if ($batch.Count -lt 100) { $finished=$true; break }
}
Require ($finished) "Release asset listing exceeded $maxPages pages; refusing an incomplete search"
Require ($assets.Count -gt 0) "No release assets returned for $($release.tag_name)"
# The requested Windows binary can be at page two or later. Do not choose
# another architecture or download a web installer as a fallback.
$asset=Select-BraveWindowsX64Asset -Assets $assets -Version ($release.tag_name.TrimStart('v'))
if ($null -eq $asset) {
    $names=@($assets | Where-Object { $_.name -match '(?i)win32-x64|BraveBrowser.*Setup' } | ForEach-Object { $_.name })
    throw "Official stable $($release.tag_name) has no exact stable Windows x64 browser ZIP across $($assets.Count) discovered assets. Candidates: $($names -join ', ')"
}
Require ($asset.size -gt 5000000) "Official browser ZIP unexpectedly small: $($asset.name)"
Require ($asset.digest -match '^sha256:[a-fA-F0-9]{64}$') "GitHub did not publish a SHA256 digest for $($asset.name); refusing unverified binary"
Require ($asset.browser_download_url -match '^https://github\.com/brave/brave-browser/releases/download/') 'Untrusted Brave download URL'

$commit=(Invoke-RestMethod -Headers $headers -Uri "$api/commits/$($release.tag_name)" -TimeoutSec 45).sha
Require ($commit -match '^[a-fA-F0-9]{40}$') 'Upstream release tag commit SHA was not returned'
New-Item -ItemType Directory -Force -Path work | Out-Null
$out=[ordered]@{
    Version=$release.tag_name.TrimStart('v')
    Tag=$release.tag_name
    Commit=$commit
    AssetName=$asset.name
    AssetURL=$asset.browser_download_url
    AssetDigest=$asset.digest.Substring(7).ToLowerInvariant()
    AssetSize=$asset.size
    AssetCount=$assets.Count
    BuilderRevision='r7'
    ResolvedAt=(Get-Date).ToUniversalTime().ToString('o')
}
$out | ConvertTo-Json | Set-Content -Encoding utf8 work/upstream.json
Write-Host "Resolved stable $($release.tag_name), commit $commit; verified ZIP asset metadata: $($asset.name) ($($asset.size) bytes)"
if ($env:GITHUB_OUTPUT) {
    "version=$($out.Version)" | Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
    "tag=portable-v$($out.Version)-brave-r7" | Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
}
