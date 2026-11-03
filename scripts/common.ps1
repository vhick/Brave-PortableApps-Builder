Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Require([bool]$condition,[string]$message){if(-not $condition){throw $message}}
function SevenZip {
 $paths=@('C:\Program Files\7-Zip\7z.exe','C:\Program Files (x86)\7-Zip\7z.exe')
 foreach($p in $paths){if(Test-Path -LiteralPath $p){return $p}}
 $c=Get-Command 7z.exe -ErrorAction SilentlyContinue | Select-Object -First 1
 if($c){return $c.Source}
 throw '7-Zip not found; runner must have official 7-Zip installed.'
}
function Assert-PE([string]$path){
 Require (Test-Path -LiteralPath $path -PathType Leaf) "Missing PE executable: $path"
 $s=[IO.File]::OpenRead($path);try{
  $b=New-Object byte[] 64;Require ($s.Read($b,0,64) -eq 64) "Short executable: $path"
  Require ($b[0] -eq 77 -and $b[1] -eq 90) "Not MZ: $path"
  $off=[BitConverter]::ToInt32($b,60)
  Require ($off -gt 0 -and $off -lt $s.Length-4) "Invalid PE offset: $path"
  $s.Position=$off;$b=New-Object byte[] 4;[void]$s.Read($b,0,4)
  Require ($b[0] -eq 80 -and $b[1] -eq 69 -and $b[2] -eq 0 -and $b[3] -eq 0) "Invalid PE signature: $path"
 }finally{$s.Dispose()}
}
function Invoke-ArchiveTest([string]$path){$seven=SevenZip; & $seven t '-y' $path | Out-Host;if($LASTEXITCODE -ne 0){throw "7z integrity test failed: $path"}}
