param([Parameter(Mandatory=$true)][string]$GodotExecutable)
$ErrorActionPreference='Stop'
$taskEngine=(Resolve-Path -LiteralPath $GodotExecutable).Path
$taskProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskRun=Join-Path $PSScriptRoot ('results/headless_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $taskRun -Force | Out-Null
Set-Content -LiteralPath (Join-Path (Split-Path $taskRun -Parent) '.gdignore') -Value ''
$taskOldSettings=$env:HUNT_SETTINGS_PATH
$taskProcesses=@()
try {
    foreach($taskSuite in @('maps_predators','worlds_vehicle','forest','progression','revive_perspective','art_wildlife','swamp')) {
        $env:HUNT_SETTINGS_PATH=Join-Path $taskRun ($taskSuite+'.cfg')
        $taskLog=Join-Path $taskRun ($taskSuite+'.log')
        $taskArgs=@('--headless','--max-fps','60','--path',('"'+$taskProject+'"'),'--log-file',('"'+$taskLog+'"'),'--quit-after','6000','--script',('res://tests/verify_'+$taskSuite+'.gd'))
        $taskProcesses+=@{suite=$taskSuite;log=$taskLog;process=(Start-Process -FilePath $taskEngine -WindowStyle Hidden -ArgumentList $taskArgs -PassThru)}
    }
    $taskFailed=$false
    foreach($taskEntry in $taskProcesses) {
        $taskEntry.process.WaitForExit()
        $taskReport=Get-Content -LiteralPath $taskEntry.log
        $taskResult=$taskReport | Select-String -Pattern '^RESULT'
        Write-Output ($taskEntry.suite+': '+$taskResult)
        if($taskEntry.process.ExitCode -ne 0 -or -not $taskResult -or ($taskReport | Select-String -Pattern '^FAIL|SCRIPT ERROR|^ERROR:')) {$taskFailed=$true}
    }
    Write-Output ('Reports: '+$taskRun)
    if($taskFailed){exit 1}
} finally {$env:HUNT_SETTINGS_PATH=$taskOldSettings}
