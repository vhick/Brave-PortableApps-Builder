param(
  [Parameter(Mandatory)][string]$SourceTag,
  [string]$Repository=$env:GITHUB_REPOSITORY
)
. "$PSScriptRoot/common.ps1"
Assert ($Repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'Invalid repository name'
Assert ($SourceTag -match '^portable-v(?<v>[0-9]+\.[0-9]+\.[0-9]+)-brave-r7$') 'Source release must be a verified Brave r7 release (portable-vX.Y.Z-brave-r7)'
$version=$Matches.v
$workspace=(Resolve-Path .).Path
$work=Join-Path $workspace 'work/nsis-paf'
$download=Join-Path $work 'download'
$extract=Join-Path $work 'extracted'
New-Item -ItemType Directory -Force $download,$extract | Out-Null
$zipName="BravePortable_${version}_brave-r7_Win64.zip"
Write-Host "Downloading existing validated builder release $SourceTag from $Repository"
# Important: download via the current repository, never from Brave upstream or untrusted URLs.
& gh release view $SourceTag --repo $Repository --json tagName,isDraft,isPrerelease --jq '{tagName, isDraft, isPrerelease}' | Out-Host
Assert ($LASTEXITCODE -eq 0) 'Cannot read source release metadata'
& gh release download $SourceTag --repo $Repository --pattern $zipName --pattern 'SHA256SUMS.txt' --dir $download
Assert ($LASTEXITCODE -eq 0) 'Cannot download source ZIP and publisher checksums'
$zip=Join-Path $download $zipName
$sumsFile=Join-Path $download 'SHA256SUMS.txt'
Assert (Test-Path -LiteralPath $zip -PathType Leaf) "Missing expected source release ZIP: $zipName"
Assert (Test-Path -LiteralPath $sumsFile -PathType Leaf) 'Missing publisher-generated SHA256SUMS.txt'
$lines=@(Get-Content -LiteralPath $sumsFile)
$matchesFound=@($lines | Where-Object { $_ -match ("(?i)^[0-9a-f]{64}\s+\*?" + [regex]::Escape($zipName) + '$') })
Assert ($matchesFound.Count -eq 1) 'Source checksum file does not contain exactly one checksum for ZIP'
$expected=($matchesFound[0] -split '\s+')[0].ToLowerInvariant()
$actual=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
Assert ($actual -eq $expected) "Source ZIP SHA256 mismatch: expected $expected got $actual"
Write-Host "Verified source release ZIP: $zipName SHA256=$actual"
Test-ZipEntries -ZipFile $zip
$seven=Get-7Zip
& $seven t -y $zip | Out-Host
Assert ($LASTEXITCODE -eq 0) 'Source ZIP archive integrity failed'
& $seven x -y "-o$extract" $zip | Out-Host
Assert ($LASTEXITCODE -eq 0) 'Source ZIP extraction failed'
$stage=Join-Path $extract 'BravePortable'
Assert-Staging $stage
$provenance=Get-Content -LiteralPath (Join-Path $stage 'Other/Source/upstream.json') -Raw | ConvertFrom-Json
Assert ([string]$provenance.Version -eq $version) 'Upstream version in packaged metadata differs from release tag'
Assert ([string]$provenance.BuilderRevision -eq 'r7') 'This workflow only consumes the verified Brave r7 application baseline'
$state=[ordered]@{ source_tag=$SourceTag; source_repository=$Repository; version=$version; source_zip=$zipName; source_zip_sha256=$actual; builder_revision='r7'; packaging_engine='independent-NSIS'; packaging_revision='nsis-r2' }
$state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'source-manifest.json') -Encoding utf8
if($env:GITHUB_OUTPUT) {
  "version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
  "release_tag=portable-v${version}-brave-r7-custom-nsis-paf-r2" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
Write-Host 'Source package verified, staged, and ready for independent NSIS compilation'
