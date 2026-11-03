# Native BravePortable.exe integration test on the disposable CI profile.
# Verify real Brave startup via Chromium DevTools and request Browser.close.
# No external sites, third-party browser drivers, or silent installer execution.
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
    Write-Host 'Launching disposable Brave with loopback DevTools readiness check (max 85 seconds).'
    $proc=Start-Process -FilePath $launcher -ArgumentList '--portable-smoke-test' -WorkingDirectory $stage -PassThru
    Require ($null -ne $proc) 'Failed to create BravePortable.exe process'
    Write-Host "Portable launcher PID: $($proc.Id)"
    $ready=Wait-BraveDevTools -Profile $profile -Launcher $proc -TimeoutSeconds 85
    Write-Host "Verified live browser: $($ready.Browser); DevTools protocol $($ready.Protocol)"
    Write-Host 'Requesting normal browser shutdown with DevTools Browser.close.'
    Close-BraveViaDevTools -BrowserUri $ready.Endpoint.BrowserUri
    # The Go launcher then waits for only matching portable children and runs
    # TraceGuard cleanup. It must finish normally, not be forcefully killed.
    if(-not (Wait-DirectLauncher -Process $proc -TimeoutSeconds 70)) {
        throw 'Launcher did not exit after DevTools Browser.close; preservation cleanup not verified'
    }
    $proc.Refresh()
    Require ($proc.ExitCode -eq 0) "Portable Brave launcher returned exit code $($proc.ExitCode)"
    Require (Test-Path -LiteralPath $profile -PathType Container) 'Portable profile directory was not created'
    Require (Test-Path -LiteralPath (Join-Path $profile 'Local State') -PathType Leaf) 'Brave did not initialize its Local State in the portable profile'
    $logPath=Join-Path $trace 'launcher.log'
    Require ((Test-Path -LiteralPath $logPath -PathType Leaf) -and
        ((Get-Content -LiteralPath $logPath -Raw).Contains('Brave session ended normally'))) 'TraceGuard cleanup did not complete normally'
    $success=$true
} finally {
    Show-SmokeDiagnostics -Stage $stage
    if($null -ne $proc) {$proc.Dispose()}
}
if(-not $success){throw 'Brave DevTools smoke test failed'}
# Preserve evidence outside the package; never ship the disposable CI profile.
New-Item -ItemType Directory -Force $evidence | Out-Null
Copy-Item -LiteralPath (Join-Path $trace 'launcher.log') -Destination (Join-Path $evidence 'launcher.log') -Force
$stderrPath=Join-Path $trace 'smoke-output.txt'
if(Test-Path -LiteralPath $stderrPath -PathType Leaf){
    Copy-Item -LiteralPath $stderrPath -Destination (Join-Path $evidence 'browser-output.txt') -Force
}
Remove-Item -LiteralPath (Join-Path $stage 'Data') -Recurse -Force
New-Item -ItemType Directory -Force (Join-Path $stage 'Data') | Out-Null
Write-Host 'Real Brave startup, DevTools handshake, normal shutdown and TraceGuard cleanup PASSED; test Data removed from staging.'
