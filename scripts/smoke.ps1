# Bounded Windows startup test of the real compiled BravePortable.exe.
# Never perform headless tests on a user's real Data or profile directory.
. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/smoke-utils.ps1"
$stage=Join-Path (Resolve-Path .) 'work/BravePortable'
$launcher=Join-Path $stage 'BravePortable.exe'
Assert-PE $launcher
$trace=Join-Path $stage 'Data/TraceGuard'
$profile=Join-Path $stage 'Data/profile'
$evidence=Join-Path (Resolve-Path .) 'work/smoke-evidence'
$proc=$null
$success=$false
try {
    Write-Host 'Launching real BravePortable.exe in disposable headless mode (direct PID wait, max 165 seconds).'
    # Intentionally omit Start-Process -Wait: it waits for all Chromium descendants.
    $proc=Start-Process -FilePath $launcher -ArgumentList '--portable-smoke-test' -WorkingDirectory $stage -PassThru
    Require ($null -ne $proc) 'Failed to create BravePortable.exe process'
    Write-Host "Portable launcher PID: $($proc.Id)"
    if(-not (Wait-DirectLauncher -Process $proc -TimeoutSeconds 165)) {
        # Only terminate OUR known launcher process, never a pre-existing browser.
        try {if(-not $proc.HasExited) {Stop-Process -Id $proc.Id -Force -ErrorAction Stop}} catch {
            Write-Warning "Unable to stop unresponsive smoke launcher PID $($proc.Id): $($_.Exception.Message)"
        }
        throw 'The direct BravePortable.exe launcher did not exit within 165 seconds. Inspect launcher.log and smoke-output.txt below; remaining child processes are not forcefully killed.'
    }
    $proc.Refresh()
    Require ($proc.ExitCode -eq 0) "Portable Brave launcher returned exit code $($proc.ExitCode)"
    Require (Test-Path -LiteralPath $profile -PathType Container) 'Brave did not create its portable user-data directory'
    $browserOutput=Join-Path $trace 'smoke-output.txt'
    Require ((Test-Path -LiteralPath $browserOutput -PathType Leaf) -and ((Get-Item -LiteralPath $browserOutput).Length -gt 0)) 'Headless Brave produced no DOM output; refusing false successful smoke'
    # A successful smoke also proves the launcher completed its own cleanup path.
    $launchLog=Join-Path $trace 'launcher.log'
    Require ((Test-Path -LiteralPath $launchLog) -and ((Get-Content -LiteralPath $launchLog -Raw).Contains('Brave session ended normally'))) 'Launcher did not record successful Brave shutdown and TraceGuard cleanup'
    $success=$true
} finally {
    Show-SmokeDiagnostics -Stage $stage
    if($null -ne $proc) {$proc.Dispose()}
}
if(-not $success){throw 'Brave smoke test failed'}
# Persist CI evidence in the runner working directory, then remove disposable
# profile/logs from package staging so they cannot ship to end users.
New-Item -ItemType Directory -Force $evidence|Out-Null
Copy-Item -LiteralPath (Join-Path $trace 'launcher.log') -Destination (Join-Path $evidence 'launcher.log') -Force
Copy-Item -LiteralPath (Join-Path $trace 'smoke-output.txt') -Destination (Join-Path $evidence 'browser-output.txt') -Force
Remove-Item -LiteralPath (Join-Path $stage 'Data') -Recurse -Force
New-Item -ItemType Directory -Force (Join-Path $stage 'Data')|Out-Null
Write-Host 'Windows runtime smoke passed; disposable test profile removed from release staging.'
