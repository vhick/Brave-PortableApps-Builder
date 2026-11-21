# Both outputs are mandatory: this step must fail before the publisher if one is missing.
. "$PSScriptRoot/common.ps1"
$up = Get-Content -LiteralPath work/upstream.json -Raw | ConvertFrom-Json
Require ($up.BuilderRevision -ceq 'r10') 'Incorrect builder revision'
$root = (Resolve-Path .).Path
$stage = Join-Path $root 'work/BravePortable'
$dist = Join-Path $root 'dist'
$zip = @(Get-ChildItem -LiteralPath $dist -File -Filter '*.zip')
$pafs = @(Get-ChildItem -LiteralPath $dist -File -Filter '*.paf.exe')
Require ($zip.Count -eq 1) "Expected exactly ONE PortableApps ZIP; got $($zip.Count)"
Require ($pafs.Count -eq 1) "Expected exactly ONE independent NSIS .paf.exe; got $($pafs.Count)"
Require ($zip[0].Name -ceq "BravePortable_$($up.Version)_brave-r10_Win64.zip") 'Unexpected ZIP name/version'
Require ($pafs[0].Name -ceq "BravePortable_$($up.Version).0_custom-nsis-brave-r10.paf.exe") 'Unexpected installer name/version/engine'
Require ($env:APP_ID -ceq 'BravePortableIndependent') 'Unexpected AppID from shared packager'
Require ($env:APP_VERSION -ceq "$($up.Version).0") 'Unexpected app version from shared packager'
Require ([IO.Path]::GetFullPath($env:INSTALLER_FILE) -ieq $pafs[0].FullName) 'Publisher candidate differs from universal packager output'
Require ((Get-FileHash -LiteralPath $pafs[0].FullName -Algorithm SHA256).Hash -ieq $env:INSTALLER_SHA256) 'Universal packager PAF checksum mismatch'
Require (Test-Sha256Hex -value ((Get-FileHash -LiteralPath $zip[0].FullName -Algorithm SHA256).Hash)) 'ZIP hash missing or invalid'
Assert-PE (Join-Path $stage 'BravePortable.exe')
Assert-PE (Join-Path $stage 'App/Brave/brave.exe')
Assert-PE $pafs[0].FullName
Invoke-ArchiveTest $zip[0].FullName
Invoke-ArchiveTest $pafs[0].FullName
$zipManifest = Join-Path $dist ($zip[0].Name + '.sha256')
Require (Test-Path -LiteralPath $zipManifest -PathType Leaf) 'ZIP sidecar hash missing'
$zipHash=(Get-FileHash -LiteralPath $zip[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
Require ((Get-Content -LiteralPath $zipManifest -Raw).Contains($zipHash)) 'ZIP sidecar digest mismatch'
$pafManifest= $pafs[0].FullName + '.sha256'
Require (Test-Path -LiteralPath $pafManifest -PathType Leaf) 'NSIS installer sidecar hash missing'
$pafHash=(Get-FileHash -LiteralPath $pafs[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
Require ((Get-Content -LiteralPath $pafManifest -Raw).Contains($pafHash)) 'PAF sidecar digest mismatch'
# Never include live browser profile, cookies, or any runtime state in the distributed ZIP.
$data=Join-Path $stage 'Data'
Require (Test-Path -LiteralPath $data -PathType Container) 'Missing portable Data directory'
Require (@(Get-ChildItem -LiteralPath $data -Force -Recurse).Count -eq 0) 'Disposable smoke-test Data leaked into package staging'
$ini=Get-Content -LiteralPath (Join-Path $stage 'App/AppInfo/appinfo.ini') -Raw
Require ($ini -match 'AppID=BravePortableIndependent') 'Unexpected AppID in staged metadata'
Require ($ini -match 'Start=BravePortable\.exe') 'Incorrect PortableApps launcher entry'
Write-Host "PASS: Official Brave $($up.Version), one validated ZIP, one independent NSIS installer; profile Data empty."
Write-Host "ZIP SHA256: $zipHash"
Write-Host "PAF SHA256: $pafHash"
