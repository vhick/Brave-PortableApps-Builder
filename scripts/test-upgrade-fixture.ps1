# Fast, real PowerShell regression: the application folder must be absent
# before a FIRST NSIS install. Runs before downloading Brave.
. "$PSScriptRoot/installer-fixture.ps1"
$testBase=Join-Path ([IO.Path]::GetTempPath()) ('brave-installer-fixture-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $testBase | Out-Null
try {
  $f=Initialize-UpgradeInstallTest -RunnerTemp $testBase
  Require (Test-Path -LiteralPath $f.TestRoot -PathType Container) 'Fixture parent missing'
  Require (-not (Test-Path -LiteralPath $f.Destination)) 'Regression: installer destination was precreated'
  Require (Test-Path -LiteralPath $f.Outside -PathType Container) 'Unrelated host folder missing'
  Require ([IO.File]::ReadAllText($f.Marker) -ceq 'unrelated-host-content') 'Host marker modified'
  # Existing disposable fixture can be reinitialized without claiming host files.
  New-Item -ItemType Directory -Force $f.Destination | Out-Null
  [IO.File]::WriteAllText((Join-Path $f.Destination 'test.txt'),'disposable')
  $f2=Initialize-UpgradeInstallTest -RunnerTemp $testBase
  Require (-not (Test-Path -LiteralPath $f2.Destination)) 'Fixture was not reset for first install'
  Require ([IO.File]::ReadAllText($f2.Marker) -ceq 'unrelated-host-content') 'Host marker changed after fixture reset'
  Write-Host 'PASS: NSIS first-install destination is absent; unrelated test host data preserved.'
} finally {
  if (Test-Path -LiteralPath $testBase) { Remove-Item -LiteralPath $testBase -Recurse -Force }
}
