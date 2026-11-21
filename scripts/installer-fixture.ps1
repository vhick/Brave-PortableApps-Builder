# Disposable first-install test fixture for the shared NSIS engine.
# NSIS v1.0.0 treats an existing empty AppNamePortable folder as
# potentially occupied. The *parent* may exist, but the destination
# itself MUST NOT be created before launching the installer.
. "$PSScriptRoot/common.ps1"
function Initialize-UpgradeInstallTest {
  param([Parameter(Mandatory)][string]$RunnerTemp)
  Require (Test-NonBlank -value $RunnerTemp) 'Disposable test parent is required'
  Require (Test-Path -LiteralPath $RunnerTemp -PathType Container) 'Test parent does not exist'
  $testRoot=Join-Path $RunnerTemp 'BraveUnifiedInstallerTest'
  $dest=Join-Path $testRoot 'BravePortable'
  $outside=Join-Path $testRoot 'Unrelated'
  if(Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
  # Deliberately DO NOT create $dest: the installer must create it itself.
  New-Item -ItemType Directory -Force $testRoot,$outside | Out-Null
  $marker=Join-Path $outside 'KEEP_THIS_HOST_FILE.txt'
  [IO.File]::WriteAllText($marker,'unrelated-host-content')
  Require (-not (Test-Path -LiteralPath $dest)) 'First-install destination must not be pre-created'
  Require ([IO.File]::ReadAllText($marker) -ceq 'unrelated-host-content') 'Unrelated host marker not initialized'
  return [pscustomobject]@{TestRoot=$testRoot; Destination=$dest; Outside=$outside; Marker=$marker}
}
