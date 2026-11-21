# Run ONLY in disposable $env:RUNNER_TEMP. NSIS /S and /D semantics were validated
# by Universal Portable Package Builder's own synthetic installation self-test.
. "$PSScriptRoot/common.ps1"
$root=(Resolve-Path .).Path
$stage=Join-Path $root 'work/BravePortable'
$paf= @(Get-ChildItem -LiteralPath (Join-Path $root 'dist') -File -Filter '*.paf.exe')
Require ($paf.Count -eq 1) 'Expected exactly one NSIS executable to test'
Require ($env:INSTALLER_FILE -and ([IO.Path]::GetFullPath($env:INSTALLER_FILE) -ieq $paf[0].FullName)) 'Wrong installer selected for upgrade test'
Require (Test-NonBlank -value $env:RUNNER_TEMP) 'Disposable RUNNER_TEMP required'
$testRoot=Join-Path $env:RUNNER_TEMP 'BraveUnifiedInstallerTest'
$dest=Join-Path $testRoot 'BravePortable'
$outside=Join-Path $testRoot 'Unrelated'
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Force -Recurse }
New-Item -ItemType Directory -Force $dest,$outside | Out-Null
$marker=Join-Path $outside 'KEEP_THIS_HOST_FILE.txt'
[IO.File]::WriteAllText($marker,'unrelated-host-content')
function Invoke-Installer([string]$Destination,[bool]$ExpectSuccess) {
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$paf[0].FullName
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  [void]$psi.ArgumentList.Add('/S')
  [void]$psi.ArgumentList.Add("/D=$Destination") # NSIS /D must be last
  $process=[Diagnostics.Process]::new()
  $process.StartInfo=$psi
  try {
    Require ($process.Start()) 'Unable to start NSIS install test'
    if (-not $process.WaitForExit(600000)) {
      try { $process.Kill($true); $process.WaitForExit(5000) | Out-Null } catch {}
      throw 'NSIS install test exceeded 600 seconds'
    }
    if($ExpectSuccess){Require ($process.ExitCode -eq 0) "NSIS installation failed with exit code $($process.ExitCode)"}
    else{Require ($process.ExitCode -ne 0) 'NSIS incorrectly allowed installation into an unrelated folder'}
    Write-Host "NSIS exit code $($process.ExitCode) for disposable destination $Destination"
  } finally { $process.Dispose() }
}
# First install and exact browser hash comparison.
Invoke-Installer $dest $true
Require (Test-Path -LiteralPath (Join-Path $dest 'App/Brave/brave.exe') -PathType Leaf) 'NSIS did not install Brave'
Require ((Get-FileHash (Join-Path $dest 'App/Brave/brave.exe') -Algorithm SHA256).Hash -eq (Get-FileHash (Join-Path $stage 'App/Brave/brave.exe') -Algorithm SHA256).Hash) 'NSIS installed a different Brave binary than ZIP staging'
Require ((Get-FileHash (Join-Path $dest 'BravePortable.exe') -Algorithm SHA256).Hash -eq (Get-FileHash (Join-Path $stage 'BravePortable.exe') -Algorithm SHA256).Hash) 'NSIS installed a different launcher than ZIP staging'
# Synthetic old Brave version-numbered directory to detect upgrade accumulation.
$obsolete=Join-Path $dest 'App/Brave/0.0.0.0'
New-Item -ItemType Directory -Force $obsolete | Out-Null
[IO.File]::WriteAllText((Join-Path $obsolete 'OLD_BINARY.txt'),'must-be-removed')
$dataFile=Join-Path $dest 'Data/profile/User Data/Default/Bookmarks'
New-Item -ItemType Directory -Force (Split-Path $dataFile -Parent) | Out-Null
[IO.File]::WriteAllText($dataFile,'unique-user-profile-keep-intact')
$emptyTree=Join-Path $dest 'Data/TraceGuard/empty/nested/tree'
New-Item -ItemType Directory -Force $emptyTree | Out-Null
# Repeat installation into same directory, preserving Data and replacing App/Other.
Invoke-Installer $dest $true
Require (-not (Test-Path -LiteralPath $obsolete)) 'Old numbered browser binaries accumulated after upgrade'
Require ([IO.File]::ReadAllText($dataFile) -ceq 'unique-user-profile-keep-intact') 'Existing portable profile modified during upgrade'
Require (Test-Path -LiteralPath $emptyTree -PathType Container) 'Nested empty portable Data directory lost on upgrade'
Require (-not (Test-Path -LiteralPath (Join-Path $dest '.__UPB_Backup'))) 'Old App backup left after successful upgrade'
Require (-not (Test-Path -LiteralPath (Join-Path $dest '.__UPB_Stage'))) 'Installation stage left after successful upgrade'
Require ([IO.File]::ReadAllText($marker) -ceq 'unrelated-host-content') 'Unrelated host file changed'
# A mismatched destination must fail without writing application files.
Invoke-Installer $outside $false
Require ([IO.File]::ReadAllText($marker) -ceq 'unrelated-host-content') 'Installer overwrote unrelated destination content'
Require (-not (Test-Path -LiteralPath (Join-Path $outside 'App'))) 'Installer put program files in unrelated destination'
Write-Host 'PASS: full Brave installer first install, byte matching, upgrade removes obsolete numbered version, Data/empty folders preserved, unrelated destination refused.'
# No user Data is touched. This is a GitHub-hosted disposable test location only.
