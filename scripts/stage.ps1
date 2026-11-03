. "$PSScriptRoot/common.ps1"
$up=Get-Content work/upstream.json -Raw|ConvertFrom-Json
$stage=Join-Path (Resolve-Path .) 'work/BravePortable'
New-Item -Type Directory -Force "$stage/App/Brave","$stage/App/AppInfo/Launcher","$stage/App/DefaultData","$stage/Data","$stage/Other/Source"|Out-Null
Get-ChildItem -LiteralPath work/payload -Force|ForEach-Object{Copy-Item -LiteralPath $_.FullName -Destination "$stage/App/Brave" -Recurse -Force}
Assert-PE "$stage/App/Brave/brave.exe"
# Preserve the original Brave branding assets rather than generating substitute artwork.
Add-Type -AssemblyName System.Drawing
$icon=[System.Drawing.Icon]::ExtractAssociatedIcon("$stage/App/Brave/brave.exe")
Require ($null -ne $icon) 'Could not extract original icon from official brave.exe'
$iconFile=[IO.File]::Create("$stage/App/AppInfo/appicon.ico")
try{$icon.Save($iconFile)}finally{$iconFile.Close()}
foreach($size in @(16,32)){
 $bmp=New-Object System.Drawing.Bitmap($size,$size)
 $graphics=[System.Drawing.Graphics]::FromImage($bmp)
 try{
  $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.DrawImage($icon.ToBitmap(),0,0,$size,$size)
  $bmp.Save("$stage/App/AppInfo/appicon_$size.png",[System.Drawing.Imaging.ImageFormat]::Png)
 }finally{$graphics.Dispose();$bmp.Dispose()}
}
$icon.Dispose()
$version="$($up.Version).0"
$ini=@"
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=Brave Portable (Independent Build)
AppID=BravePortableIndependent
Publisher=Brave Software, Inc. (browser); independent packaging
Homepage=https://github.com/brave/brave-browser
Category=Internet
Description=Brave browser with isolated portable profile
Language=Multilingual

[License]
Shareable=false
OpenSource=true
Freeware=true
CommercialUse=false

[Version]
PackageVersion=$version
DisplayVersion=$($up.Version) Portable r4

[Control]
Icons=1
Start=BravePortable.exe
"@
Set-Content -Path "$stage/App/AppInfo/appinfo.ini" -Value $ini -Encoding ascii
@'
[Launch]
ProgramExecutable=Brave\brave.exe
WorkingDirectory=%PAL:AppDir%\Brave

; Informational only. The actual launcher is the independently compiled
; BravePortable.exe, because TraceGuard has application-specific recovery logic.
'@ |Set-Content -Path "$stage/App/AppInfo/Launcher/BravePortable.ini" -Encoding ascii
@'
[MainDirectories]
RemoveAppDirectory=true
RemoveDataDirectory=false
RemoveOtherDirectory=true
'@ |Set-Content -Path "$stage/App/AppInfo/installer.ini" -Encoding ascii
Copy-Item docs/NOTICE.txt "$stage/Other/Source/NOTICE.txt"
Copy-Item work/upstream.json "$stage/Other/Source/upstream.json"
# Embed the authentic Brave icon into the compiled native EXE, as well as the menu.
# This pinned MIT-licensed build-time resource compiler never ships in the package.
$syso='cmd/braveportable/rsrc_windows_amd64.syso'
if(Test-Path $syso){Remove-Item $syso -Force}
& go run github.com/akavel/rsrc@v0.10.2 -arch amd64 -ico "$stage/App/AppInfo/appicon.ico" -o $syso
if($LASTEXITCODE -ne 0 -or -not (Test-Path $syso)){throw 'Could not compile Brave icon resources for native launcher'}
# Compile a native Windows PE launcher without scripts or command-file wrappers.
& go build -trimpath -buildvcs=false -ldflags '-H windowsgui' -o "$stage/BravePortable.exe" ./cmd/braveportable
if($LASTEXITCODE -ne 0){throw 'Go native launcher compilation failed'}
Assert-PE "$stage/BravePortable.exe"
Remove-Item $syso -Force
Write-Host 'PortableApps staging complete.'
