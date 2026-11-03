. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/zip-utils.ps1"
$up=Get-Content work/upstream.json -Raw | ConvertFrom-Json
Require ($up.AssetName -ceq "brave-v$($up.Version)-win32-x64.zip") "Unsafe or unexpected Brave release asset: $($up.AssetName)"
Require ($up.AssetURL -match '^https://github\.com/brave/brave-browser/releases/download/') 'Brave ZIP source must be official GitHub release'
$root=(Resolve-Path .).Path
$work=Join-Path $root 'work'
$target=Join-Path $work $up.AssetName
New-Item -ItemType Directory -Force -Path $work | Out-Null
# Curl follows only HTTPS redirects, retries bounded failures and refuses non-2xx.
& curl.exe --fail --location --proto '=https' --proto-redir '=https' --retry 3 --retry-delay 4 --connect-timeout 25 --max-time 1200 --output $target $up.AssetURL
if($LASTEXITCODE -ne 0){throw 'Official Brave Windows ZIP download failed'}
Require ((Get-Item -LiteralPath $target).Length -eq $up.AssetSize) 'Brave ZIP download size differs from official GitHub metadata'
$actual=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
Require ($actual -eq $up.AssetDigest) "Official Brave ZIP SHA256 mismatch: expected $($up.AssetDigest) received $actual"
$seven=SevenZip
# Test the ZIP itself rather than treating an updater EXE as an archive.
Invoke-ArchiveTest $target
$extract=Join-Path $work 'extracted-brave-zip'
$payload=Join-Path $work 'payload'
if(Test-Path -LiteralPath $extract){Remove-Item -LiteralPath $extract -Recurse -Force}
if(Test-Path -LiteralPath $payload){Remove-Item -LiteralPath $payload -Recurse -Force}
New-Item -ItemType Directory -Force -Path $extract,$payload | Out-Null
& $seven x '-y' "-o$extract" $target | Out-Host
if($LASTEXITCODE -ne 0){throw 'Failed to extract official Brave Windows x64 ZIP'}
$browserDir=Find-BravePayloadDirectory -ExtractRoot $extract
Assert-PE (Join-Path $browserDir 'brave.exe')
# Copy all immediate siblings (including Chromium resource directories and files),
# not just brave.exe. This preserves the directory layout required by Brave.
Get-ChildItem -LiteralPath $browserDir -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $payload -Recurse -Force
}
Assert-PE (Join-Path $payload 'brave.exe')
Require (@(Get-ChildItem -LiteralPath $payload -Force).Count -ge 2) 'Browser ZIP payload contains only brave.exe; required resources appear missing'
$after=(Get-FileHash -LiteralPath (Join-Path $payload 'brave.exe') -Algorithm SHA256).Hash
$before=(Get-FileHash -LiteralPath (Join-Path $browserDir 'brave.exe') -Algorithm SHA256).Hash
Require ($before -eq $after) 'Extracted Brave executable changed during payload copy'
Write-Host "Official uninstalled Brave Windows x64 ZIP verified/extracted: $($up.AssetName)"
Write-Host "Detected native Brave executable at $browserDir; resources copied into $payload"
