param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][ValidateSet('soldier','ravager','detach','shop','hand-real','hand-fixed')][string]$Case
)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$rootDir = (Get-Item -LiteralPath $PSScriptRoot).Parent.Parent.FullName
$caseDir = Join-Path $rootDir '.godot/stability-20261125'
$subdir = switch ($Case) {
    'detach' { 'action-probe' }
    'shop' { 'shop-probe' }
    'hand-real' { 'hand-probe' }
    'hand-fixed' { 'hand-probe' }
    default { '' }
}
$stem = if ($subdir) { "$subdir/probe" } else { 'end_probe' }
$null = New-Item -ItemType Directory -Force -Path (Join-Path $caseDir $subdir)
foreach ($ext in 'gd','tscn') {
    $src = Join-Path $PSScriptRoot "$stem.$ext"
    $dst = Join-Path $caseDir "$stem.$ext"
    if (Test-Path -LiteralPath $dst) {
        if ((Get-FileHash $dst).Hash -ne (Get-FileHash $src).Hash) { throw "Previously preserved probe differs: $dst" }
    } else { Copy-Item -LiteralPath $src -Destination $dst }
}
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $caseDir 'replay-user'
    $null = New-Item -ItemType Directory -Force -Path $env:APPDATA
    $file = Join-Path $caseDir ("replay-$Case-" + (Get-Date -Format yyyyMMdd-HHmmss-fff) + '.log')
    $limit = switch ($Case) { 'detach' {90}; 'shop' {120}; default {650} }
    $argsForEngine = @('--headless','--path',('"' + $rootDir + '"'),'--quit-after',[string]$limit,'--log-file',('"' + $file + '"'))
    if ($Case -ne 'hand-real') { $argsForEngine += @('--fixed-fps','60') }
    $argsForEngine += @("res://.godot/stability-20261125/$stem.tscn",'--','--balance-seed=17391')
    if ($Case -in 'ravager','soldier') { $argsForEngine += "--probe-enemy=$Case" }
    $process = Start-Process -FilePath $engine -WindowStyle Hidden -ArgumentList $argsForEngine -PassThru
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "30 s timeout: $file" }
    "Engine exit $($process.ExitCode); read the assertions AND engine errors in $file"
    Get-Content -LiteralPath $file
    exit $process.ExitCode
} finally {
    $env:APPDATA = $oldAppData
}
