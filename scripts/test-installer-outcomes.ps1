# Fast regression before Brave download: validate installer outcome logic.
# The r10 test incorrectly ran the unrelated-destination assertion when
# a valid first installation returned NSIS exit code 0.
. "$PSScriptRoot/installer-result-utils.ps1"
function Expect-Rejection {
  param([Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Case,
        [Parameter(Mandatory)][string]$ExpectedMessage)
  $rejected=$false
  try { & $Action } catch {
    if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
      throw "Regression: $Case threw the WRONG error: $($_.Exception.Message)"
    }
    $rejected=$true
  }
  Require $rejected "Regression: $Case should have been rejected"
}
$install='C:\Disposable\BravePortable'
$unrelated='C:\Disposable\OtherApplication'
Assert-InstallerOutcome -ExitCode 0 -ExpectSuccess $true -Destination $install
Assert-InstallerOutcome -ExitCode 2 -ExpectSuccess $false -Destination $unrelated
Assert-InstallerOutcome -ExitCode 1 -ExpectSuccess $false -Destination $unrelated
Expect-Rejection -Action { Assert-InstallerOutcome -ExitCode 2 -ExpectSuccess $true -Destination $install } -Case 'first install returned NSIS script abort' -ExpectedMessage 'NSIS expected installation FAILED'
Expect-Rejection -Action { Assert-InstallerOutcome -ExitCode 1 -ExpectSuccess $true -Destination $install } -Case 'first install aborted by user' -ExpectedMessage 'NSIS expected installation FAILED'
Expect-Rejection -Action { Assert-InstallerOutcome -ExitCode 0 -ExpectSuccess $false -Destination $unrelated } -Case 'installer wrote into unrelated folder' -ExpectedMessage 'NSIS incorrectly allowed installation'
Write-Host 'PASS: exit 0 succeeds only for permitted installs; nonzero succeeds only when unrelated destination was rejected.'
