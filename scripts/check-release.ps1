param([Parameter(Mandatory)][string]$Tag)
. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/release-check-utils.ps1"

Require ($Tag -match '^portable-v[0-9]+\.[0-9]+\.[0-9]+-brave-r6$') "Unexpected release tag: $Tag"
Require (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) 'GITHUB_TOKEN is required to check private/public builder releases.'
Require ($env:GITHUB_REPOSITORY -match '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') 'Invalid GITHUB_REPOSITORY in runner environment.'
Require (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) 'GITHUB_OUTPUT is required to communicate the skip decision.'

$headers=@{
    'Accept'='application/vnd.github+json'
    'User-Agent'='independent-brave-portable-builder'
    'X-GitHub-Api-Version'='2022-11-28'
    'Authorization'="Bearer $env:GITHUB_TOKEN"
}
$escapedTag=[uri]::EscapeDataString($Tag)
$url="https://api.github.com/repos/$($env:GITHUB_REPOSITORY)/releases/tags/$escapedTag"
$statusCode=0
# Do not use `gh release view`: its expected exit code 1 on a nonexistent tag
# can make GitHub Actions' PowerShell wrapper fail despite being handled.
# Invoke-RestMethod -SkipHttpErrorCheck exposes HTTP 404 without throwing.
# Transport errors still throw; we must not mistake them for missing releases.
$response=Invoke-RestMethod -Method Get -Uri $url -Headers $headers `
    -TimeoutSec 30 -SkipHttpErrorCheck -StatusCodeVariable statusCode
$exists=Test-PortableReleaseStatus -StatusCode $statusCode -Response $response -ExpectedTag $Tag
if($exists){
    Write-Host "Release $Tag already exists in this repository; skipping rebuild without overwriting assets."
    'skip=true' | Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
}else{
    Write-Host "No published release for $Tag (HTTP 404); starting first-time build."
    'skip=false' | Out-File -Append -Encoding utf8 $env:GITHUB_OUTPUT
}
exit 0
