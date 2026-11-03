Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# WaitForExit handles only this specific launcher PID, unlike Start-Process -Wait,
# which also waits for every descendant. Always give it a finite timeout.
function Wait-DirectLauncher([System.Diagnostics.Process]$Process,[int]$TimeoutSeconds) {
    if($null -eq $Process){throw 'No launcher process supplied'}
    if($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 180){throw 'Smoke timeout must be between 1 and 180 seconds'}
    return [bool]$Process.WaitForExit($TimeoutSeconds * 1000)
}

function Show-SmokeDiagnostics([string]$Stage) {
    $trace=Join-Path $Stage 'Data/TraceGuard'
    foreach($entry in @(@('Launcher log','launcher.log'),@('Browser standard output and errors','smoke-output.txt'))) {
        $path=Join-Path $trace $entry[1]
        Write-Host "==== $($entry[0]) ($path) ===="
        if(Test-Path -LiteralPath $path -PathType Leaf) {
            Get-Content -LiteralPath $path -Tail 100 -ErrorAction Continue | Out-Host
        } else {
            Write-Host '(not generated)'
        }
    }
    $browser=Join-Path $Stage 'App/Brave/brave.exe'
    try {
        $running=@(Get-CimInstance -ClassName Win32_Process -Filter "Name='brave.exe'" -ErrorAction Stop | Where-Object { $_.ExecutablePath -eq $browser })
        Write-Host "Brave processes still running from this staging folder: $($running.Count)"
        foreach($entry in $running) {Write-Host "  PID $($entry.ProcessId): $($entry.CommandLine)"}
    } catch {Write-Warning "Unable to query remaining Brave process metadata: $($_.Exception.Message)"}
}
