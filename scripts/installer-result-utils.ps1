# Classify real NSIS exit codes without conflating successful installs with
# intentionally refused unsafe destinations. This helper is called by the
# actual Windows install test and by fast regression cases before downloads.
. "$PSScriptRoot/common.ps1"
function Assert-InstallerOutcome {
  param(
    [Parameter(Mandatory)][int]$ExitCode,
    [Parameter(Mandatory)][bool]$ExpectSuccess,
    [Parameter(Mandatory)][string]$Destination
  )
  if ($ExpectSuccess) {
    # NSIS documents 0 as normal execution and 2 as a script-driven abort.
    Require ($ExitCode -eq 0) "NSIS expected installation FAILED (exit $ExitCode): $Destination"
  } else {
    # For an unrelated folder, accepting it (exit 0) is a security regression.
    Require ($ExitCode -ne 0) "NSIS incorrectly allowed installation into an unrelated folder (exit 0): $Destination"
  }
}
