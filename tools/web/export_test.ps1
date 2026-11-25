param([Parameter(Mandatory = $true)][string]$Godot,
    [string]$Scene = 'res://tests/enemies/enemies.tscn',
    [string]$OutputDirectory = '.godot/enemy_web')
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = (Get-Command $Godot -CommandType Application).Source
if ($Scene -notmatch '^res://tests/(?:[\w.-]+/)*[\w.-]+\.tscn$' -or
    $Scene.Split('/') -contains '..' -or !(Test-Path -LiteralPath (Join-Path $taskRoot $Scene.Substring(6)) -PathType Leaf)) {
    throw "Unknown test scene: $Scene"
}
$taskOutput = [IO.Path]::GetFullPath((Join-Path $taskRoot $OutputDirectory))
$runs = Join-Path $taskRoot '.godot/web-test-runs'
$run = Join-Path $runs ([guid]::NewGuid().ToString('N'))
$stage = Join-Path $run 'project'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null

function Invoke-StagedGodot([string]$Step, [string[]]$Arguments) {
    $log = Join-Path $run "$Step.log"
    $process = Start-Process -FilePath $engine -WindowStyle Hidden -PassThru -ArgumentList $Arguments -RedirectStandardOutput $log -RedirectStandardError (Join-Path $run "$Step.err")
    if (!$process.WaitForExit(300000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "$Step timed out. See $log"
    }
    if ($process.ExitCode -ne 0) { throw "$Step failed ($($process.ExitCode)). See $log" }
}
try {
    # Copy the working tree, including local edits and native binaries. Never share writable resources or import metadata.
    foreach ($name in 'project.godot','export_presets.cfg','road_graph.gdextension','road_graph.gdextension.uid','icon.svg','icon.svg.import') {
        Copy-Item -LiteralPath (Join-Path $taskRoot $name) -Destination $stage
    }
    foreach ($name in 'assets','scenes','scripts','tests','addons','bin','tools','docs') {
        & robocopy (Join-Path $taskRoot $name) (Join-Path $stage $name) /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD .godot (Join-Path $taskRoot 'tools/assets/blender') | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy of $name failed ($LASTEXITCODE)" }
    }
    $project = Join-Path $stage 'project.godot'
    $presets = Join-Path $stage 'export_presets.cfg'
    $config = [IO.File]::ReadAllText($project)
    $mainScene = [regex]'(?m)^run/main_scene="[^"]*"'
    if (!$mainScene.IsMatch($config)) { throw 'Project has no main scene setting' }
    $config = $mainScene.Replace($config, ('run/main_scene="' + $Scene + '"'))
    $preset = [IO.File]::ReadAllText($presets)
    [IO.File]::WriteAllText($presets, $preset.Replace('tests/*,', ''))
    $common = @('--headless', '--path', ('"' + $stage + '"'))
    # The editor initializes its UI before importing fonts into a fresh project.
    [IO.File]::WriteAllText($project, [regex]::Replace($config, '(?m)^theme/custom_font=.*$', ''))
    Invoke-StagedGodot 'import' ($common + '--import')
    [IO.File]::WriteAllText($project, $config)
    $index = Join-Path $taskOutput 'index.html'
    Invoke-StagedGodot 'export' ($common + @('--export-release', 'Web', ('"' + $index + '"')))
    Write-Output "Exported $index (logs: $run)"
} finally {
    $resolved = (Resolve-Path -LiteralPath $stage).Path
    if ($resolved -eq $stage -and $resolved.StartsWith($runs + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
