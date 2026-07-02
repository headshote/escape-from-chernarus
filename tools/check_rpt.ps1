param(
    [string]$RptPath = "",
    [int]$TailLines = 4000
)

$ErrorActionPreference = "Stop"

if (-not $RptPath) {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA "Arma 3"),
        (Join-Path $env:LOCALAPPDATA "Arma 3 - Other Profiles")
    ) | Where-Object { Test-Path $_ }

    $latest = $roots |
        ForEach-Object { Get-ChildItem -Path $_ -Filter "*.rpt" -File -Recurse -ErrorAction SilentlyContinue } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        Write-Host "[WARN] No Arma 3 RPT found under LOCALAPPDATA."
        exit 2
    }
    $RptPath = $latest.FullName
}

if (-not (Test-Path $RptPath)) {
    Write-Error "RPT not found: $RptPath"
}

$lines = Get-Content -Path $RptPath -Tail $TailLines
$checks = [ordered]@{
    "script_errors"      = "Error in expression|Error position:|Undefined variable|Generic error in expression"
    "watchdog_recovery"  = "\[CO\]\[WATCHDOG\]"
    "qa_failures"        = "\[CO\]\[QA\] FAIL"
    "missing_sound"      = "Cannot load sound|Sound: Error|missing-sound"
}

$failed = $false
Write-Host "[CO][RPT] Checking $RptPath (tail $TailLines lines)"
foreach ($name in $checks.Keys) {
    $matches = $lines | Select-String -Pattern $checks[$name]
    $count = @($matches).Count
    if ($count -gt 0) {
        $failed = $true
        Write-Host "[FAIL] $name : $count"
        $matches | Select-Object -First 8 | ForEach-Object {
            Write-Host ("  L{0}: {1}" -f $_.LineNumber, $_.Line.Trim())
        }
    } else {
        Write-Host "[OK] $name : 0"
    }
}

$qaPass = @($lines | Select-String -Pattern "\[CO\]\[QA\] PASS").Count
$qaSummary = $lines | Select-String -Pattern "\[CO\]\[QA\] SUMMARY" | Select-Object -Last 1
Write-Host "[INFO] qa_pass_lines : $qaPass"
if ($qaSummary) {
    Write-Host "[INFO] latest_summary : $($qaSummary.Line.Trim())"
}

if ($failed) { exit 1 }
exit 0
