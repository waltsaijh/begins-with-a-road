param([string]$Godot='C:\tools\Godot.exe',[string]$Output='.godot/phase5/regression',[switch]$Rendered,[string[]]$Only=@())
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$cases = if ($Rendered) { @('levels/road_flow_preview','cards/card_shop','relics/input','synergy/input','levels/pause_menu','levels/level_teardown') } else { @('navigation/route_distribution','navigation/multiple_starts','navigation/waypoint_routes','navigation/dead_end_edits','levels/wave_spawn_groups','levels/terrain_endpoints','levels/level_flow','levels/act_spawn_expansion','traffic/integration','combat/tower_restoration','combat/attack_area','combat/combat','enemies/enemy_status','relics/stacking','relics/rewards','relics/mechanisms','synergy/routing','synergy/combat','levels/level_teardown') }
$results=@()
if ($Only.Count -gt 0) { $cases=$Only }
foreach ($case in $cases) {
    $label=$case.Replace('/','-')
    $log=Join-Path $Output ($label+'.log')
    $arguments=@('--path',(Get-Location).Path,("res://tests/$case.tscn"),'--log-file',$log)
    if (-not $Rendered) { $arguments=@('--headless')+$arguments }
    $process=Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $complete=$process.WaitForExit(180000)
    if (-not $complete) { $process.Kill();$process.WaitForExit() }
    $content=Get-Content -LiteralPath $log -Raw
    $errors=@([regex]::Matches($content,'(?m)^SCRIPT ERROR:.*|^ERROR:.*') | ForEach-Object Value)
    $applicationErrors=@($errors | Where-Object { $_ -notmatch 'shader cache' })
    $marker=$content -match '(?im)(CHECK|PASS|failures|checks|assertions|regression)'
    $status=if ($complete -and $process.ExitCode -eq 0 -and $applicationErrors.Count -eq 0 -and $marker) {'Current PASS'} else {'Current FAIL'}
    $results+=@{case=$case;status=$status;exit=$process.ExitCode;completed=$complete;rendered=[bool]$Rendered;errors=$errors;log=$log}
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Output 'results.json')
    Write-Output "$status $case exit=$($process.ExitCode)"
}
