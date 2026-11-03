# Small pre-flight regression tests of the bounded direct-PID wait. These can
# execute on standard Windows GitHub runners before the large Brave download.
. "$PSScriptRoot/smoke-utils.ps1"
$cmd=Join-Path $env:SystemRoot 'System32/cmd.exe'
if(-not (Test-Path -LiteralPath $cmd)){throw 'Windows command interpreter unavailable'}
$p=$null
try {
    $p=Start-Process -FilePath $cmd -ArgumentList @('/d','/c','exit 0') -PassThru
    if(-not (Wait-DirectLauncher -Process $p -TimeoutSeconds 5)){throw 'Short-lived process did not exit'}
    $p.Refresh()
    if($p.ExitCode -ne 0){throw 'Direct wait did not preserve exit code'}
} finally {if($p){$p.Dispose()}}
$invalidRejected=$false
try {Wait-DirectLauncher -Process $null -TimeoutSeconds 1|Out-Null} catch {$invalidRejected=$true}
if(-not $invalidRejected){throw 'Null-process guard did not run'}
$timeoutRejected=$false
try {Wait-DirectLauncher -Process ([System.Diagnostics.Process]::GetCurrentProcess()) -TimeoutSeconds 0|Out-Null} catch {$timeoutRejected=$true}
if(-not $timeoutRejected){throw 'Invalid timeout guard did not run'}
Write-Host 'PASS: bounded direct PID wait, exit-code check and invalid-input guards'
