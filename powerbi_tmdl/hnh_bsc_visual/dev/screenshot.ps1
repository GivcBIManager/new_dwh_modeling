# Bundle the harness with esbuild, then screenshot each mode (and the prototype) with headless Edge into dev/out/.
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
foreach ($mode in 'overview', 'overview-scores', 'board', 'owner', 'comparison') {
    $png = Join-Path $out "$mode.png"
    & $edge --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=4000 "--screenshot=$png" --window-size=1920,904 ($page + '?mode=' + $mode)
    Start-Sleep -Milliseconds 800
}
foreach ($mode in 'overview', 'board') {
    $png = Join-Path $out "$mode-1280x720.png"
    & $edge --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=4000 "--screenshot=$png" --window-size=1280,720 ($page + '?mode=' + $mode)
    Start-Sleep -Milliseconds 800
}
$proto = Join-Path (Split-Path (Split-Path $proj -Parent) -Parent) 'docs\superpowers\specs\assets\2026-10-20-bsc-visual-prototype.html'
if (Test-Path $proto) {
    $purl = 'file:///' + ($proto -replace '\\', '/')
    foreach ($mode in 'overview', 'board') {
        $png = Join-Path $out "prototype-$mode.png"
        & $edge --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=4000 "--screenshot=$png" --window-size=1920,904 ($purl + '?mode=' + $mode)
        Start-Sleep -Milliseconds 800
    }
}
Get-ChildItem $out -Filter *.png | Select-Object Name, Length
