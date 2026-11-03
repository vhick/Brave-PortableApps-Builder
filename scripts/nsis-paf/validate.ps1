param([Parameter(Mandatory)][string]$Version)
. "$PSScriptRoot/common.ps1"
Assert ($Version -match '^\d+\.\d+\.\d+$') 'Invalid version'
$root=(Resolve-Path .).Path
$stage=Join-Path $root 'work/nsis-paf/extracted/BravePortable'
Assert-Staging $stage
$out=Join-Path $root "dist/BravePortable_${Version}_brave-r7_custom-nsis-r1_Win64.paf.exe"
Assert-PE $out
$seven=Get-7Zip
& $seven t -y $out | Out-Host
Assert ($LASTEXITCODE -eq 0) 'NSIS installer archive integrity test failed'
$check=Join-Path $root 'work/nsis-paf/inspect-installer'
New-Item -ItemType Directory -Force $check | Out-Null
& $seven x -y "-o$check" $out | Out-Host
Assert ($LASTEXITCODE -eq 0) '7-Zip could not inspect the independent NSIS installer payload'
foreach($file in @('BravePortable.exe','brave.exe','appinfo.ini','appicon.ico')) {
  $found=@(Get-ChildItem -LiteralPath $check -Recurse -File -Filter $file)
  Assert ($found.Count -eq 1) "NSIS embedded payload expected one $file, found $($found.Count)"
  $expected= switch ($file) {
    'BravePortable.exe' { Join-Path $stage 'BravePortable.exe' }
    'brave.exe' { Join-Path $stage 'App/Brave/brave.exe' }
    'appinfo.ini' { Join-Path $stage 'App/AppInfo/appinfo.ini' }
    'appicon.ico' { Join-Path $stage 'App/AppInfo/appicon.ico' }
  }
  $h1=(Get-FileHash $found[0].FullName -Algorithm SHA256).Hash
  $h2=(Get-FileHash $expected -Algorithm SHA256).Hash
  Assert ($h1 -eq $h2) "NSIS embedded $file differs from the validated source payload"
}
# Never ship profile data in the installer: only App, Other, and the root executable.
$archived=@(Get-ChildItem -LiteralPath $check -Recurse -File)
$personal=@($archived | Where-Object { $_.FullName -match '(?i)[\\/]Data[\\/]' })
Assert ($personal.Count -eq 0) 'Installer embeds unexpected Data files'
$sha=(Get-FileHash $out -Algorithm SHA256).Hash.ToLowerInvariant()
"$sha  $(Split-Path $out -Leaf)" | Set-Content -LiteralPath "$out.sha256" -Encoding ascii
Write-Host "Validated independent NSIS PAF installer SHA256: $sha"
