# Real Windows installer tests with a tiny synthetic BravePortable-shaped payload.
# Verifies first install, nonempty Data, nested empty Data folders, upgrade,
# unrelated destination rejection, and refusal to overwrite a locked executable.
. "$PSScriptRoot/common.ps1"
$root=(Resolve-Path .).Path
$base=Join-Path $root 'work/nsis-fixture-test'
New-Item -ItemType Directory -Force $base | Out-Null
$stage=Join-Path $base 'BravePortable'
foreach($part in @('App/Brave','App/AppInfo','Other/Source')) { New-Item -ItemType Directory -Force (Join-Path $stage $part) | Out-Null }
$exe=Join-Path $env:WINDIR 'System32/notepad.exe'
Assert (Test-Path -LiteralPath $exe) 'Fixture needs built-in Windows notepad.exe'
Copy-Item $exe (Join-Path $stage 'BravePortable.exe')
Copy-Item $exe (Join-Path $stage 'App/Brave/brave.exe')
'[Details]' + "`n" + 'AppID=BravePortableIndependent' + "`n[Control]`nStart=BravePortable.exe" | Set-Content -LiteralPath (Join-Path $stage 'App/AppInfo/appinfo.ini') -Encoding ascii
'{}' | Set-Content -LiteralPath (Join-Path $stage 'Other/Source/upstream.json') -Encoding ascii
Add-Type -AssemblyName System.Drawing
$icon=[Drawing.Icon]::ExtractAssociatedIcon($exe)
$f=[IO.File]::Create((Join-Path $stage 'App/AppInfo/appicon.ico'))
try { $icon.Save($f) } finally { $f.Dispose(); $icon.Dispose() }
$marker=Join-Path $stage 'App/Brave/fixture-version.txt'
$installer=Join-Path $base 'fixture-install.paf.exe'
$nsis=Get-Makensis
$script=Join-Path $PSScriptRoot 'BravePortable-Community-Installer.nsi'
function Compile-Fixture([string]$content) {
  $content | Set-Content -LiteralPath $marker -Encoding ascii
  if(Test-Path $installer) { Remove-Item -LiteralPath $installer -Force }
  Invoke-Bounded -Exe $nsis -Arguments @('/V3','/DAPP_VERSION=1.98.63',"/DSOURCE_DIR=$stage","/DOUTPUT_PATH=$installer",$script) -Log (Join-Path $base 'compile-fixture.log') -Seconds 120
  Assert-PE $installer
}
function Install-Fixture([string]$dest,[bool]$shouldSucceed) {
  $log=Join-Path $base 'fixture-install-result.txt'
  $psi=[Diagnostics.ProcessStartInfo]::new($installer)
  [void]$psi.ArgumentList.Add('/S')
  [void]$psi.ArgumentList.Add("/D=$dest")
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $p=[Diagnostics.Process]::Start($psi)
  try {
    if(-not $p.WaitForExit(45000)) {
      try{$p.Kill($true)}catch{}
      throw 'Synthetic installer timed out (possible blocking prompt)'
    }
    "exit=$($p.ExitCode); destination=$dest; expectedSuccess=$shouldSucceed" | Add-Content -LiteralPath $log
    if($shouldSucceed) { Assert ($p.ExitCode -eq 0) "Silent install unexpectedly failed, exit $($p.ExitCode)" }
    else { Assert ($p.ExitCode -ne 0) 'Unsafe destination must be rejected with a nonzero exit code' }
  } finally { $p.Dispose() }
}
$target=Join-Path $base 'installed/BravePortable'
Compile-Fixture 'first'
Install-Fixture $target $true
Assert ((Get-Content (Join-Path $target 'App/Brave/fixture-version.txt') -Raw).Trim() -eq 'first') 'First install missing application marker'
$data=Join-Path $target 'Data'
New-Item -ItemType Directory -Force (Join-Path $data 'profile'),(Join-Path $data 'TraceGuard/Saved/Nested'),(Join-Path $data 'Empty/Nested/Tree')|Out-Null
$personal=Join-Path $data 'profile/personal.json'
'{"important":"keep unchanged"}'|Set-Content $personal -Encoding utf8
'{"log":"retain"}'|Set-Content (Join-Path $data 'TraceGuard/Saved/Nested/state.json') -Encoding utf8
$beforeHash=(Get-FileHash $personal -Algorithm SHA256).Hash
Compile-Fixture 'second'
Install-Fixture $target $true
Assert ((Get-Content (Join-Path $target 'App/Brave/fixture-version.txt') -Raw).Trim() -eq 'second') 'Upgrade did not replace application files'
Assert ((Get-FileHash $personal -Algorithm SHA256).Hash -eq $beforeHash) 'Upgrade changed existing Data content'
Assert (Test-Path (Join-Path $data 'TraceGuard/Saved/Nested/state.json')) 'Upgrade deleted nested Data content'
Assert (Test-Path (Join-Path $data 'Empty/Nested/Tree') -PathType Container) 'Upgrade deleted empty Data hierarchy'
$foreign=Join-Path $base 'foreign/BravePortable'
New-Item -ItemType Directory -Force (Join-Path $foreign 'App/AppInfo') | Out-Null
"[Details]`nAppID=AnotherApp`n" | Set-Content (Join-Path $foreign 'App/AppInfo/appinfo.ini') -Encoding ascii
Install-Fixture $foreign $false
Assert (-not (Test-Path (Join-Path $foreign 'BravePortable.exe'))) 'Installer modified unrelated application folder'
$nonempty=Join-Path $base 'unrelated/BravePortable'
New-Item -ItemType Directory -Force (Join-Path $nonempty 'Data') | Out-Null
'stop' | Set-Content (Join-Path $nonempty 'Data/sentinel.txt')
Install-Fixture $nonempty $false
Assert ((Get-Content (Join-Path $nonempty 'Data/sentinel.txt') -Raw).Trim() -eq 'stop') 'Unrelated Data folder modified'
$locked=Join-Path $target 'App/Brave/brave.exe'
$handle=[IO.File]::Open($locked,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try { Install-Fixture $target $false } finally { $handle.Dispose() }
Assert ((Get-FileHash $personal -Algorithm SHA256).Hash -eq $beforeHash) 'Locked upgrade modified Data'
Write-Host 'Synthetic Windows NSIS install/upgrade/empty Data/host protection/file-lock tests PASSED'
