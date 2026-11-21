. "$PSScriptRoot/common.ps1"
$up=Get-Content work/upstream.json -Raw|ConvertFrom-Json
Require ($up.AssetName -ceq "brave-v$($up.Version)-win32-x64.zip") 'Staged browser does not originate from the exact official stable Windows x64 ZIP asset'
Require ($up.BuilderRevision -ceq 'r11') 'Unexpected builder revision in upstream metadata'

$stage=Join-Path (Resolve-Path .) 'work/BravePortable'
$info=Join-Path $stage 'App/AppInfo/appinfo.ini'
Require (Test-Path $info) 'Missing AppInfo metadata'
Require ((Get-Content $info -Raw) -match 'Start=BravePortable\.exe') 'PortableApps menu launcher missing'
Require ((Get-Content $info -Raw) -match 'RemoveDataDirectory=false' -or (Get-Content "$stage/App/AppInfo/installer.ini" -Raw) -match 'RemoveDataDirectory=false') 'Data preservation is not configured'
foreach($p in @('App/AppInfo/appicon.ico','App/AppInfo/appicon_16.png','App/AppInfo/appicon_32.png','App/AppInfo/Launcher/BravePortable.ini')){Require (Test-Path (Join-Path $stage $p)) "Missing $p"}
Assert-PE "$stage/BravePortable.exe"
Assert-PE "$stage/App/Brave/brave.exe"
$zip=@(Get-ChildItem dist -Filter 'BravePortable_*.zip' -File)
Require ($zip.Count -eq 1) "Expected exactly one Brave Portable ZIP, found $($zip.Count)"
Invoke-ArchiveTest $zip[0].FullName
$seven=SevenZip
$listing=(& $seven l -slt $zip[0].FullName) -join "`n"
Require ($listing.Contains('BravePortable\BravePortable.exe') -or $listing.Contains('BravePortable/BravePortable.exe')) 'ZIP missing root launcher'
Require ($listing.Contains('BravePortable\App\Brave\brave.exe') -or $listing.Contains('BravePortable/App/Brave/brave.exe')) 'ZIP missing Brave binary'
Write-Host 'PortableApps ZIP and staged application static validation passed.'
