Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# WaitForExit handles only this specific launcher PID, unlike Start-Process -Wait,
# which also waits for every descendant. Always give it a finite timeout.
function Wait-DirectLauncher([System.Diagnostics.Process]$Process,[int]$TimeoutSeconds) {
    if($null -eq $Process){throw 'No launcher process supplied'}
    if($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 180){throw 'Smoke timeout must be between 1 and 180 seconds'}
    return [bool]$Process.WaitForExit($TimeoutSeconds * 1000)
}


# Chromium writes this two-line file in the explicit --user-data-dir when
# --remote-debugging-port=0 is used. Accept ONLY loopback endpoints belonging
# to this disposable profile. We never connect to another user's browser.
function Read-BraveDevToolsPort([string]$Profile) {
    $file = Join-Path $Profile 'DevToolsActivePort'
    if(-not (Test-Path -LiteralPath $file -PathType Leaf)) {return $null}
    try {
        $lines = @(Get-Content -LiteralPath $file -ErrorAction Stop)
        if($lines.Count -lt 2) {return $null}
        [int]$port = 0
        if(-not [int]::TryParse(([string]$lines[0]).Trim(),[ref]$port)) {return $null}
        if($port -lt 1 -or $port -gt 65535) {return $null}
        $path=([string]$lines[1]).Trim()
        if($path -notmatch '^/devtools/browser/[A-Za-z0-9-]+$') {return $null}
        return [pscustomobject]@{
            Port=$port
            VersionUri="http://127.0.0.1:$port/json/version"
            BrowserUri="ws://127.0.0.1:$port$path"
        }
    } catch { return $null }
}

function Wait-BraveDevTools([string]$Profile,[System.Diagnostics.Process]$Launcher,[int]$TimeoutSeconds=85) {
    if($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 100){throw 'Invalid DevTools readiness timeout'}
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lastError='DevToolsActivePort was not created'
    while([DateTime]::UtcNow -lt $deadline) {
        $Launcher.Refresh()
        if($Launcher.HasExited){throw "Brave launcher exited before DevTools readiness; exit code $($Launcher.ExitCode)"}
        $endpoint=Read-BraveDevToolsPort -Profile $Profile
        if($null -ne $endpoint) {
            try {
                # -NoProxy and 127.0.0.1 prevent requests leaving the runner.
                $version=Invoke-RestMethod -Uri $endpoint.VersionUri -NoProxy -TimeoutSec 2 -ErrorAction Stop
                $browserName=[string]($version.Browser)
                $protocolVersion=[string]($version.'Protocol-Version')
                $reportedSocket=[string]($version.webSocketDebuggerUrl)
                if(-not [string]::IsNullOrWhiteSpace($browserName) -and
                   -not [string]::IsNullOrWhiteSpace($protocolVersion) -and
                   ($reportedSocket -match '^ws://(127\.0\.0\.1|localhost):[0-9]+/devtools/browser/')) {
                    return [pscustomobject]@{Endpoint=$endpoint; Browser=$browserName; Protocol=$protocolVersion}
                }
                $lastError='DevTools endpoint returned incomplete browser metadata'
            } catch {
                $lastError=$_.Exception.Message
            }
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Brave did not expose a usable loopback DevTools endpoint in $TimeoutSeconds seconds. Last diagnostic: $lastError"
}

function Close-BraveViaDevTools([string]$BrowserUri) {
    # DevTools Browser.close performs a normal browser shutdown, allowing our
    # launcher to wait for child processes and capture external storage.
    if($BrowserUri -notmatch '^ws://127\.0\.0\.1:[0-9]+/devtools/browser/[A-Za-z0-9-]+$') {
        throw 'Refusing non-local or invalid browser debugging endpoint'
    }
    $ws=[System.Net.WebSockets.ClientWebSocket]::new()
    $cts=[System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(10))
    try {
        $ws.ConnectAsync([Uri]$BrowserUri,$cts.Token).GetAwaiter().GetResult()
        $bytes=[System.Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Browser.close"}')
        $payload=[ArraySegment[byte]]::new($bytes)
        $ws.SendAsync($payload,[System.Net.WebSockets.WebSocketMessageType]::Text,$true,$cts.Token).GetAwaiter().GetResult()
    } finally {
        $ws.Dispose()
        $cts.Dispose()
    }
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
    $profile=Join-Path $Stage 'Data/profile'
    Write-Host "Profile folder exists: $(Test-Path -LiteralPath $profile -PathType Container)"
    $port=Read-BraveDevToolsPort -Profile $profile
    if($null -ne $port) {Write-Host "DevToolsActivePort: $($port.Port) (disposable loopback test)"}
    $localState=Join-Path $profile 'Local State'
    Write-Host "Local State exists: $(Test-Path -LiteralPath $localState -PathType Leaf)"
    $debugFile=Join-Path $profile 'chrome_debug.log'
    if(Test-Path -LiteralPath $debugFile -PathType Leaf) {
        Write-Host '==== Browser chrome_debug.log (last 80 lines) ===='
        Get-Content -LiteralPath $debugFile -Tail 80 -ErrorAction Continue | Out-Host
    }
    try {
        $running=@(Get-CimInstance -ClassName Win32_Process -Filter "Name='brave.exe'" -ErrorAction Stop | Where-Object { $_.ExecutablePath -eq $browser })
        Write-Host "Brave processes still running from this staging folder: $($running.Count)"
        foreach($entry in $running) {Write-Host "  PID $($entry.ProcessId): $($entry.CommandLine)"}
    } catch {Write-Warning "Unable to query remaining Brave process metadata: $($_.Exception.Message)"}
}
