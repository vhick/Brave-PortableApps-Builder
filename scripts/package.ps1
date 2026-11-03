. "$PSScriptRoot/common.ps1"
$up=Get-Content work/upstream.json -Raw|ConvertFrom-Json
New-Item -Type Directory -Force dist|Out-Null
$name="BravePortable_$($up.Version)_brave-r2_Win64.zip"
$zip=Join-Path (Resolve-Path dist) $name
if(Test-Path $zip){Remove-Item -LiteralPath $zip -Force}
$seven=SevenZip
Push-Location work
try{& $seven a '-tzip' '-mx=5' $zip 'BravePortable'|Out-Host;if($LASTEXITCODE -ne 0){throw 'ZIP packaging failed'}}finally{Pop-Location}
Invoke-ArchiveTest $zip
Get-FileHash $zip -Algorithm SHA256|ForEach-Object {"$($_.Hash.ToLowerInvariant())  $name"}|Set-Content -Path "$zip.sha256" -Encoding ascii
Write-Host "PortableApps ZIP produced: $zip"
