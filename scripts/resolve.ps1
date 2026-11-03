param([string]$Version='')
. "$PSScriptRoot/common.ps1"
$headers=@{'User-Agent'='independent-brave-portable-builder';'Accept'='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}
if($env:GITHUB_TOKEN){$headers.Authorization="Bearer $env:GITHUB_TOKEN"}
$api='https://api.github.com/repos/brave/brave-browser'
if($Version){Require ($Version -match '^v?\d+\.\d+\.\d+$') 'Version must be a stable-style release number such as 1.98.63';$t=$Version.TrimStart('v');$releases=@(Invoke-RestMethod -Headers $headers -Uri "$api/releases/tags/v$t" -TimeoutSec 45)}else{
 $releases=@(Invoke-RestMethod -Headers $headers -Uri "$api/releases?per_page=100" -TimeoutSec 45)
}
$stable=@($releases|Where-Object {
 $_.tag_name -match '^v\d+\.\d+\.\d+$' -and -not $_.prerelease -and -not $_.draft -and
 $_.name -match '(?i)^Release\s+v' -and $_.name -notmatch '(?i)nightly|beta|dev|alpha'
}|Sort-Object { [version]($_.tag_name.TrimStart('v')) } -Descending)
Require ($stable.Count -gt 0) 'No stable Brave release found; refuse preview/nightly build.'
$r=$stable[0]
# This official offline installer contains chrome.7z, from which the uninstalled browser is extracted.
$names=@('^BraveBrowserStandaloneSetup(?:_\d+_\d+_\d+_\d+)?\.exe$','^BraveBrowserStandaloneSetup64(?:_\d+_\d+_\d+_\d+)?\.exe$','^brave_installer-x64\.exe$')
$asset=$null
foreach($pattern in $names){$asset=@($r.assets|Where-Object name -Match $pattern|Select-Object -First 1);if($asset.Count -gt 0){$asset=$asset[0];break}}
Require ($null -ne $asset) "Stable $($r.tag_name) does not contain a supported official x64 offline installer asset. No fallback to an unversioned latest URL."
Require ($asset.size -gt 5000000) "Installer asset is unexpectedly small: $($asset.name)"
Require ($asset.digest -match '^sha256:[0-9a-fA-F]{64}$') "No GitHub-published SHA256 asset digest for $($asset.name); refuse unverified binary."
$commit=(Invoke-RestMethod -Headers $headers -Uri "$api/commits/$($r.tag_name)" -TimeoutSec 45).sha
Require ($commit -match '^[a-fA-F0-9]{40}$') 'Upstream commit SHA not obtained.'
New-Item -ItemType Directory -Force -Path work|Out-Null
$out=[ordered]@{Version=$r.tag_name.TrimStart('v');Tag=$r.tag_name;Commit=$commit;AssetName=$asset.name;AssetURL=$asset.browser_download_url;AssetDigest=$asset.digest.Substring(7).ToLowerInvariant();AssetSize=$asset.size;BuilderRevision='r1';ResolvedAt=(Get-Date).ToUniversalTime().ToString('o')}
$out|ConvertTo-Json|Set-Content -Encoding utf8 work/upstream.json
Write-Host "Resolved stable $($r.tag_name), commit $commit, asset $($asset.name)"
if($env:GITHUB_OUTPUT){
 "version=$($out.Version)"|Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
 "tag=portable-v$($out.Version)-brave-r1"|Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
}
