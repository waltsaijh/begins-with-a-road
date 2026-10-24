param([string]$Manifest,[string]$Godot='C:\tools\Godot.exe')
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
$jobs=Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
foreach($job in $jobs) {
    $directory=Join-Path $root ('.godot/phase5/'+$job.id)
    New-Item -ItemType Directory -Force $directory | Out-Null
    $log=Join-Path $directory 'execution.log'
    $arguments=@('--headless','--path',$root,'res://tests/balance/full_run.tscn','--log-file',$log,'--',('--output=res://.godot/phase5/'+$job.id))+@($job.args)
    $job | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'invocation.json')
    $process=Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $complete=$process.WaitForExit(1800000)
    if(-not $complete) { $process.Kill(); $process.WaitForExit() }
    $content=Get-Content -LiteralPath $log -Raw
    $pass=$complete -and $process.ExitCode -eq 0 -and $content.Contains('FULL_RUN_LAB ') -and $content -notmatch '(?m)^SCRIPT ERROR:|^ERROR:'
    @{id=$job.id;complete=$complete;exit=$process.ExitCode;status=$(if($pass){'Current PASS'}else{'Current FAIL'});arguments=$arguments} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'execution.json')
    Write-Output ($job.id+': '+$(if($pass){'complete'}else{'FAILED'}))
}
