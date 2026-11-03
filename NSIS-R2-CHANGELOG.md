# Custom NSIS add-on r2 — release-check parsing fix

## Log evidence

`logs_112771435254.zip` shows source release preflight passed and the release-existence check aborted with a PowerShell parser error at line 14 before any NSIS steps. The text contained `"New release $Tag: ..."`.

## Corrections

1. Replace `$Tag:` with `${Tag}:` in the check-release diagnostic.
2. Add a parse-only test over all PowerShell scripts at the start of the workflow.
3. Use packaging revision r2 and a distinct release tag, with Brave r7 source unchanged.

## Test coverage and limitations

Local static validation covers YAML, file-layout consistency and the offending interpolation pattern. The parser regression runs on Windows when the workflow starts. Windows NSIS compilation and a successful PAF publication have not yet been observed for r2.
