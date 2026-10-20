param([Parameter(Mandatory = $true)][string]$Godot,
    [string]$Scene = 'res://tests/enemies/enemies.tscn',
    [string]$OutputDirectory = '.godot/enemy_web')
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskProject = Join-Path $taskRoot 'project.godot'
$taskPresets = Join-Path $taskRoot 'export_presets.cfg'
$taskProjectBytes = [IO.File]::ReadAllBytes($taskProject)
$taskPresetBytes = [IO.File]::ReadAllBytes($taskPresets)
$taskOutput = Join-Path $taskRoot $OutputDirectory
New-Item -ItemType Directory -Force -Path $taskOutput | Out-Null
try {
    $taskConfig = [IO.File]::ReadAllText($taskProject).Replace('run/main_scene="res://scenes/level.tscn"', ('run/main_scene="'+$Scene+'"'))
    if (-not $taskConfig.Contains('run/main_scene="'+$Scene+'"')) { throw 'Unexpected main scene; export aborted' }
    $taskExport = [IO.File]::ReadAllText($taskPresets).Replace('tests/*,', '')
    [IO.File]::WriteAllText($taskProject, $taskConfig)
    [IO.File]::WriteAllText($taskPresets, $taskExport)
    $taskArguments = @('--headless', '--path', ('"'+$taskRoot+'"'), '--export-release', 'Web', ('"'+(Join-Path $taskOutput 'index.html')+'"'))
    $taskProcess = Start-Process -FilePath $Godot -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRoot '.godot/test_export.out') -RedirectStandardError (Join-Path $taskRoot '.godot/test_export.err')
    $taskHandle = $taskProcess.Handle
    if (-not $taskProcess.WaitForExit(300000)) { $taskProcess.Kill(); throw 'Test export exceeded 5 minutes' }
    if ($taskProcess.ExitCode -ne 0) { throw ('Test export failed: '+$taskProcess.ExitCode) }
    Write-Output ('Exported '+$taskOutput)
} finally {
    [IO.File]::WriteAllBytes($taskProject, $taskProjectBytes)
    [IO.File]::WriteAllBytes($taskPresets, $taskPresetBytes)
}
