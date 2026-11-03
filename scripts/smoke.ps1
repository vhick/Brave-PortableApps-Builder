. "$PSScriptRoot/common.ps1"
$launcher=Join-Path (Resolve-Path .) 'work/BravePortable/BravePortable.exe'
Assert-PE $launcher
$proc=Start-Process -FilePath $launcher -ArgumentList '--portable-smoke-test' -PassThru -Wait
if($proc.ExitCode -ne 0){
 $file='work/BravePortable/Data/TraceGuard/launcher.log'
 if(Test-Path $file){Get-Content $file -Tail 35|Out-Host}
 throw "Actual headless Brave startup returned $($proc.ExitCode)"
}
$profile='work/BravePortable/Data/profile'
Require (Test-Path $profile) 'Brave did not initialize the portable user-data directory'
New-Item -Type Directory -Force work/smoke-evidence|Out-Null
Copy-Item work/BravePortable/Data/TraceGuard/launcher.log work/smoke-evidence/launcher.log -Force
if(Test-Path work/BravePortable/Data/TraceGuard/smoke-output.txt){Copy-Item work/BravePortable/Data/TraceGuard/smoke-output.txt work/smoke-evidence/browser-output.txt -Force}
# This is a temporary staging directory created entirely within this CI run.
# Never ship test cookies, profile, history, or smoke output in the release.
Remove-Item -LiteralPath 'work/BravePortable/Data' -Recurse -Force
New-Item -Type Directory -Force 'work/BravePortable/Data'|Out-Null
Write-Host 'Windows runtime smoke passed; disposable test profile removed from release staging.'
