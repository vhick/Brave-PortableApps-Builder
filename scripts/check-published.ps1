# Publisher v1.1.1 must publish ZIP and independent NSIS PAF, not just one.
. "$PSScriptRoot/common.ps1"
Require (Test-NonBlank -value $env:GH_TOKEN) 'Missing token for published release verification'
Require ($env:RELEASE_TAG -match '^portable-v\d+\.\d+\.\d+-brave-r9$') 'Unexpected release tag'
$raw = & gh release view $env:RELEASE_TAG --repo $env:GITHUB_REPOSITORY --json assets --jq '.assets[].name' 2>&1
if ($LASTEXITCODE -ne 0) { throw "Could not inspect published release: $($raw -join ' ')" }
$names=@($raw | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
Require (@($names | Where-Object { $_ -match '(?i)\.zip$' }).Count -eq 1) 'Published release missing exactly one ZIP'
Require (@($names | Where-Object { $_ -match '(?i)\.paf\.exe$' }).Count -eq 1) 'Published release missing exactly one PAF-style NSIS installer'
Write-Host "Confirmed ONE release with BOTH assets: $($names -join '; ')"
