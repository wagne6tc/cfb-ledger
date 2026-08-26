# =============================================================================
# verify_chain.ps1 :: Recompute the hash chain from the cards on disk and
# compare it against chain.csv.
#
# Independent check -- it trusts nothing in chain.csv except the values it is
# testing. Any card that was edited, added, or removed breaks its own row and
# every row after it.
#
#   powershell -ExecutionPolicy Bypass -File verify_chain.ps1
#
# Exit code 0 = chain intact, 1 = broken (so CI can gate on it).
# =============================================================================

$ErrorActionPreference = "Continue"
$Root  = $PSScriptRoot
$Chain = Join-Path $Root "chain.csv"

function Hash-String([string]$s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

# Hash a week's folder: each file as "<name>:<sha256>", sorted by name, joined
# by LF. Sorting must be ORDINAL -- culture-aware sorting differs between
# machines and would produce a different hash for identical bytes.
function Hash-CardFolder([string]$dir) {
    if (-not (Test-Path $dir)) { return $null }
    $files = Get-ChildItem -Path $dir -File | Sort-Object -Property Name -CaseSensitive
    if (-not $files) { return $null }
    $lines = foreach ($f in $files) {
        $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
        "$($f.Name):$h"
    }
    return Hash-String ($lines -join "`n")
}

if (-not (Test-Path $Chain)) { Write-Host "no chain.csv -- nothing to verify"; exit 0 }

$rows = @(Import-Csv $Chain)
if ($rows.Count -eq 0) { Write-Host "chain.csv is empty -- nothing to verify"; exit 0 }

$prev = "GENESIS"
$bad  = 0
Write-Host ""
Write-Host "seq  week          content   row       status"
Write-Host "---  ------------  --------  --------  ------"

foreach ($r in $rows) {
    $dir      = Join-Path (Join-Path $Root "cards") $r.week_id
    $content  = Hash-CardFolder $dir
    $expected = Hash-String ("{0}|{1}|{2}|{3}|{4}|{5}" -f $r.seq, $r.week_id, $r.generated_utc, $r.model_commit, $content, $prev)

    $status = "OK"
    if ($null -eq $content)                { $status = "CARD MISSING" }
    elseif ($content -ne $r.content_sha256){ $status = "CARD ALTERED" }
    elseif ($prev    -ne $r.prev_hash)     { $status = "CHAIN BROKEN" }
    elseif ($expected -ne $r.row_hash)     { $status = "ROW ALTERED" }
    if ($status -ne "OK") { $bad++ }

    $cShort = if ($content) { $content.Substring(0,8) } else { "--------" }
    Write-Host ("{0,-3}  {1,-12}  {2}  {3}  {4}" -f $r.seq, $r.week_id, $cShort, $r.row_hash.Substring(0,8), $status)

    # Follow the RECORDED hash so one broken row does not mask the rest.
    $prev = $r.row_hash
}

Write-Host ""
if ($bad -eq 0) {
    Write-Host "CHAIN INTACT -- $($rows.Count) week(s) verified."
    Write-Host "latest row_hash: $($rows[-1].row_hash)"
    exit 0
} else {
    Write-Host "CHAIN BROKEN -- $bad of $($rows.Count) row(s) failed."
    exit 1
}
