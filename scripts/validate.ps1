param([switch]$CheckPAF)
. "$PSScriptRoot/common.ps1"
$up=Get-Content work/upstream.json -Raw|ConvertFrom-Json
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
if($CheckPAF){
 $paf=@(Get-ChildItem dist -Filter '*.paf.exe' -File)
 Require ($paf.Count -eq 1) "Expected one official PAF, found $($paf.Count)"
 Assert-PE $paf[0].FullName
 Invoke-ArchiveTest $paf[0].FullName
 $tmp=Join-Path (Resolve-Path .) 'work/check-paf'
 New-Item -ItemType Directory -Force $tmp|Out-Null
 & $seven x '-y' "-o$tmp" $paf[0].FullName |Out-Null
 if($LASTEXITCODE -ne 0){throw 'Failed to extract official installer for payload comparison'}
 $braves=@(Get-ChildItem $tmp -Recurse -File -Filter brave.exe)
 $launchers=@(Get-ChildItem $tmp -Recurse -File -Filter BravePortable.exe)
 Require ($braves.Count -eq 1 -and $launchers.Count -eq 1) 'PAF embedded payload does not contain exactly one of each Brave executable'
 foreach($pair in @(@($braves[0].FullName,"$stage/App/Brave/brave.exe"),@($launchers[0].FullName,"$stage/BravePortable.exe"))){
  Require ((Get-FileHash $pair[0] -Algorithm SHA256).Hash -eq (Get-FileHash $pair[1] -Algorithm SHA256).Hash) 'PAF embedded executable differs from validated staging'
 }
}
Write-Host 'Static package validation passed.'
