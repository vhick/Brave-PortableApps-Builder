. "$PSScriptRoot/common.ps1"
$up=Get-Content work/upstream.json -Raw|ConvertFrom-Json
$target=Join-Path (Resolve-Path work) 'brave-official-installer.exe'
$headers=@{'User-Agent'='independent-brave-portable-builder';'Accept'='application/octet-stream'}
# curl is used for robust GitHub release-asset redirects, not silent installation.
& curl.exe --fail --location --retry 3 --retry-delay 4 --connect-timeout 25 --max-time 1200 --output $target $up.AssetURL
if($LASTEXITCODE -ne 0){throw 'Official Brave download failed'}
Require ((Get-Item $target).Length -eq $up.AssetSize) 'Official Brave asset size differs from GitHub release metadata.'
$sha=(Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
Require ($sha -eq $up.AssetDigest) "Brave official installer SHA256 mismatch: expected $($up.AssetDigest) got $sha"
Assert-PE $target
$seven=SevenZip
New-Item -Type Directory -Force work/extract-out,work/browser | Out-Null
& $seven x '-y' "-owork/extract-out" $target |Out-Host
if($LASTEXITCODE -ne 0){throw 'Failed to inspect official Brave package with 7-Zip'}
$chrome=@(Get-ChildItem work/extract-out -Recurse -File -Filter chrome.7z)
Require ($chrome.Count -eq 1) "Expected exactly one chrome.7z inside official installer, got $($chrome.Count). Refuse to guess."
& $seven x '-y' "-owork/browser" $chrome[0].FullName |Out-Host
if($LASTEXITCODE -ne 0){throw 'Could not extract browser payload chrome.7z'}
$braves=@(Get-ChildItem work/browser -Recurse -File -Filter brave.exe)
Require ($braves.Count -eq 1) "Expected exactly one brave.exe in official payload; found $($braves.Count)"
Assert-PE $braves[0].FullName
$browserDir=$braves[0].Directory.FullName
# The build copies the exact executable directory and its auxiliary libraries.
New-Item -ItemType Directory -Force work/payload|Out-Null
Get-ChildItem -LiteralPath $browserDir -Force | ForEach-Object {
 Copy-Item -LiteralPath $_.FullName -Destination work/payload -Recurse -Force
}
Require (Test-Path work/payload/brave.exe) 'Payload copy did not retain brave.exe'
Assert-PE 'work/payload/brave.exe'
Write-Host "Official Brave payload extracted: $($braves[0].FullName)"
