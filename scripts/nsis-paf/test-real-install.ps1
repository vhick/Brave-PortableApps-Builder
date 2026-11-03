# Installs the actual compiled community NSIS package into an isolated CI folder.
# This checks the real installer executable, without launching Brave or touching
# an existing user profile. Small-fixture upgrade and Data tests run separately.
param([Parameter(Mandatory)][string]$Version)
. "$PSScriptRoot/common.ps1"
Assert ($Version -match '^\d+\.\d+\.\d+$') 'Invalid version'
$root=(Resolve-Path .).Path
$work=Join-Path $root 'work/nsis-paf'
$source=Join-Path $work 'extracted/BravePortable'
$target=Join-Path $work 'real-install/BravePortable'
$installer=Join-Path $root "dist/BravePortable_${Version}_brave-r7_custom-nsis-r2_Win64.paf.exe"
Assert-Staging $source
Assert-PE $installer
Assert (-not (Test-Path -LiteralPath $target)) 'Disposable test installation target already exists; refusing to reuse it'
New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new($installer)
[void]$psi.ArgumentList.Add('/S')
[void]$psi.ArgumentList.Add("/D=$target")
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$p=[Diagnostics.Process]::Start($psi)
try {
    if(-not $p.WaitForExit(180000)) {
        try { $p.Kill($true) } catch {}
        throw 'Real community NSIS installer did not complete within 180 seconds'
    }
    Assert ($p.ExitCode -eq 0) "Real installer returned exit code $($p.ExitCode)"
} finally { $p.Dispose() }
Assert-Staging $target
foreach($rel in @('BravePortable.exe','App/Brave/brave.exe','App/AppInfo/appinfo.ini','Other/Source/upstream.json')) {
    $a=(Get-FileHash -LiteralPath (Join-Path $source $rel) -Algorithm SHA256).Hash
    $b=(Get-FileHash -LiteralPath (Join-Path $target $rel) -Algorithm SHA256).Hash
    Assert ($a -eq $b) "Installed file differs from verified source ZIP: $rel"
}
Assert (Test-Path -LiteralPath (Join-Path $target 'Data') -PathType Container) 'Installer did not create Data directory'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $target 'Data') -Force -Recurse -File).Count -eq 0) 'Installer seeded unexpected Data files'
Write-Host 'Real community NSIS installer silently installed original Brave and launcher with SHA256-identical payload; Data is empty.'
