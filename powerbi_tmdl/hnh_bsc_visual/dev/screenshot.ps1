# Bundle the harness with esbuild, then screenshot each view with headless Edge into dev/out/, at the size the report
# gives the visual: the content box 1860 x 870 (overview, board, owner, comparison) and 1920 x 996 (KPI detail).
# Then print the geometry the report's native visuals rely on (pillar cards, board slots, detail panels).
$ErrorActionPreference = 'Stop'
$dev = $PSScriptRoot
$proj = Split-Path $dev -Parent
$out = Join-Path $dev 'out'
New-Item -ItemType Directory -Force $out | Out-Null
# The stylesheet is plain CSS apart from // line comments, which Less strips and a browser does not.
(Get-Content (Join-Path $proj 'style\visual.less')) | Where-Object { $_ -notmatch '^\s*//' } | Set-Content (Join-Path $out 'visual.css') -Encoding UTF8
Push-Location $proj
try {
    & npx esbuild dev/harness.ts --bundle --outfile=dev/out/harness.js --loader:.less=empty --target=es2022 --log-level=warning
    if ($LASTEXITCODE -ne 0) { throw 'esbuild failed' }
} finally { Pop-Location }
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$page = 'file:///' + ((Join-Path $dev 'harness.html') -replace '\\', '/')
# The headless window draws its page 24 px narrower and 92 px shorter than --window-size; the harness also pins the
# visual's box with w= and h=, so a different allowance only adds a white margin.
$box = @(1860, 870)
$detailBox = @(1920, 996)
$shots = [ordered]@{
    'overview'             = @('mode=overview', $box)
    'overview-scores'      = @('mode=overview-scores', $box)
    'board'                = @('mode=board&pillar=Financial', $box)
    'board-select'         = @('mode=board&pillar=Financial&select=F1-01', $box)
    'board-ip'             = @('mode=board&pillar=Internal%20Process', $box)
    'detail'               = @('mode=detail', $detailBox)
    'owner'                = @('mode=owner', $box)
    'owner-ontarget-all'   = @('mode=owner-ontarget-all', $box)
    'owner-owned-pick'     = @('mode=owner-owned-pick', $box)
    'comparison'           = @('mode=comparison', $box)
    'comparison-pillar'    = @('mode=comparison-pillar', $box)
    'comparison-objective' = @('mode=comparison-objective', $box)
}
# Edge returns before its headless child finishes and logs noise on stderr: run each capture to completion in its own
# profile, with stderr in a log file.
$edgeProfile = Join-Path $out 'edge-profile'
$log = Join-Path $out 'edge.log'
function Invoke-Edge([string[]] $Arguments, [string] $StdOut) {
    $common = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--virtual-time-budget=4000', "--user-data-dir=`"$edgeProfile`"")
    $p = @{ FilePath = $edge; ArgumentList = $common + $Arguments; Wait = $true; NoNewWindow = $true; RedirectStandardError = $log }
    if ($StdOut) { $p.RedirectStandardOutput = $StdOut }
    Start-Process @p
}
function Get-Shot([string] $name) {
    $query, $size = $shots[$name]
    return @("${query}&w=$($size[0])&h=$($size[1])", "$($size[0] + 24),$($size[1] + 92)")
}
foreach ($name in $shots.Keys) {
    $query, $size = Get-Shot $name
    $png = Join-Path $out "$name.png"
    Invoke-Edge @("--screenshot=`"$png`"", "--window-size=$size", "`"${page}?$query`"")
}
$domFile = Join-Path $out 'dom.html'
foreach ($name in 'overview', 'board', 'detail') {
    $query, $size = Get-Shot $name
    Invoke-Edge @('--dump-dom', "--window-size=$size", "`"${page}?$query`"") $domFile
    $dom = Get-Content $domFile -Raw
    if ($dom -match 'data-geometry="([^"]*)"') { Write-Output ("{0}: {1}" -f $name, ($Matches[1] -replace '&quot;', '"')) }
    else { Write-Output "${name}: no geometry" }
}
Get-ChildItem $out -Filter *.png | Select-Object Name, Length
