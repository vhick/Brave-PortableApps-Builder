param(
  [Parameter(Mandatory)][string]$SourceTag,
  [string]$Repository=$env:GITHUB_REPOSITORY
)
. "$PSScriptRoot/common.ps1"
Assert ($Repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'Invalid repository'
Assert ($SourceTag -match '^portable-v(?<v>\d+\.\d+\.\d+)-brave-r7$') 'Select a verified Brave r7 release tag only'
$version=$Matches.v
$asset="BravePortable_${version}_brave-r7_Win64.zip"
$recordText=(& gh release view $SourceTag --repo $Repository --json tagName,isDraft,isPrerelease,assets)
Assert ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($recordText)) 'Unable to read requested source release'
$record=($recordText -join "`n") | ConvertFrom-Json
Assert ($record.tagName -ceq $SourceTag -and -not $record.isDraft -and -not $record.isPrerelease) 'Source release is not a published stable tag'
$assets=@($record.assets | ForEach-Object { $_.name })
Assert ($assets -contains $asset) "Source release missing validated ZIP $asset"
Assert ($assets -contains 'SHA256SUMS.txt') 'Source release missing publisher checksum asset'
$tag="portable-v${version}-brave-r7-custom-nsis-paf-r1"
"version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"release_tag=$tag" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
Write-Host "Verified source release has required assets; source=$SourceTag, target=$tag"
