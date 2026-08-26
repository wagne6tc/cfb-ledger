# =============================================================================
# latest_hash.ps1 :: Print the newest row_hash as a ready-to-post line, and put
# it on the clipboard.
#
# Post this publicly each week. The chain proves the cards are internally
# consistent; it cannot stop the whole history being rewritten and force-pushed.
# What stops that is other people having seen an earlier hash. Only the LATEST
# hash needs posting -- every row folds in the one before it, so the newest hash
# commits to the entire history behind it.
#
#   powershell -ExecutionPolicy Bypass -File latest_hash.ps1
# =============================================================================

$Root  = $PSScriptRoot
$Chain = Join-Path $Root "chain.csv"
if (-not (Test-Path $Chain)) { Write-Host "no chain.csv yet"; exit 1 }

$rows = @(Import-Csv $Chain)
if ($rows.Count -eq 0) { Write-Host "chain.csv is empty"; exit 1 }
$r = $rows[-1]

$line = "CFB Model - $($r.week_id) predictions locked $($r.generated_utc) UTC - ledger row_hash $($r.row_hash)"

Write-Host ""
Write-Host "  week      $($r.week_id)"
Write-Host "  locked    $($r.generated_utc) UTC"
Write-Host "  row_hash  $($r.row_hash)"
Write-Host ""
Write-Host "  ---- paste this ----"
Write-Host "  $line"
Write-Host ""

try {
    Set-Clipboard -Value $line
    Write-Host "  (copied to clipboard)"
} catch {
    Write-Host "  (clipboard unavailable -- copy the line above by hand)"
}
Write-Host ""
