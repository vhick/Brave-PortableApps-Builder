. "$PSScriptRoot/release-check-utils.ps1"
$ErrorActionPreference='Stop'
function Check([bool]$ok,[string]$message) {if(-not $ok){throw "Release check regression failed: $message"}}
function MustThrow([scriptblock]$test,[string]$message) {
    $caught=$false
    try {& $test | Out-Null} catch {$caught=$true}
    if(-not $caught){throw "Release check regression failed: $message"}
}
$tag='portable-v1.98.63-brave-r4'
$release=[pscustomobject]@{tag_name=$tag;id=42}
Check ((Test-PortableReleaseStatus -StatusCode 200 -Response $release -ExpectedTag $tag) -eq $true) '200 for the matching tag must skip'
Check ((Test-PortableReleaseStatus -StatusCode 404 -Response $null -ExpectedTag $tag) -eq $false) '404 must allow build'
foreach($status in @(400,401,403,408,409,422,429,500,502,503)) {
    MustThrow {Test-PortableReleaseStatus -StatusCode $status -Response $null -ExpectedTag $tag} "HTTP $status was treated as absent"
}
MustThrow {Test-PortableReleaseStatus -StatusCode 200 -Response $null -ExpectedTag $tag} '200 with missing metadata was accepted'
MustThrow {Test-PortableReleaseStatus -StatusCode 200 -Response ([pscustomobject]@{tag_name='other'}) -ExpectedTag $tag} 'wrong existing release was accepted'
MustThrow {Test-PortableReleaseStatus -StatusCode 200 -Response ([pscustomobject]@{id=42}) -ExpectedTag $tag} 'response without tag_name was accepted'
Write-Host 'PASS: published release 200, missing release 404, mismatch and HTTP error rejection'
