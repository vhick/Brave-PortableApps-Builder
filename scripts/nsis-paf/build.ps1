param([Parameter(Mandatory)][string]$Version)
. "$PSScriptRoot/common.ps1"
Assert ($Version -match '^\d+\.\d+\.\d+$') 'Invalid package version'
$root=(Resolve-Path .).Path
$work=Join-Path $root 'work/nsis-paf'
$stage=Join-Path $work 'extracted/BravePortable'
Assert-Staging $stage
$manifest=Get-Content -LiteralPath (Join-Path $work 'source-manifest.json') -Raw|ConvertFrom-Json
Assert ($manifest.version -eq $Version) 'Source version and compilation request differ'
New-Item -ItemType Directory -Force (Join-Path $root 'dist') | Out-Null
$out=Join-Path $root "dist/BravePortable_${Version}_brave-r7_custom-nsis-r1_Win64.paf.exe"
Assert (-not (Test-Path -LiteralPath $out)) 'Installer already exists; do not overwrite outputs'
$nsis=Get-Makensis
Write-Host "NSIS compiler: $nsis"
& $nsis /VERSION | Out-Host
$script=Join-Path $PSScriptRoot 'BravePortable-Community-Installer.nsi'
$log=Join-Path $work 'makensis-output.log'
Invoke-Bounded -Exe $nsis -Arguments @('/V3',"/DAPP_VERSION=$Version","/DSOURCE_DIR=$stage","/DOUTPUT_PATH=$out",$script) -Log $log -Seconds 900
Get-Content -LiteralPath $log -Tail 120 | Out-Host
Assert-PE $out
Write-Host "Independent NSIS PAF-style package compiled: $out"
