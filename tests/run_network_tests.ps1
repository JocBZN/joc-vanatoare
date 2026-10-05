param([Parameter(Mandatory=$true)][string]$GodotExecutable,[ValidateSet('forest','swamp')][string]$Map='forest')
$ErrorActionPreference = 'Stop'
$taskProjectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskEnginePath = (Resolve-Path -LiteralPath $GodotExecutable).Path
$taskRunPath = Join-Path $PSScriptRoot ('results/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $taskRunPath -Force | Out-Null
Set-Content -LiteralPath (Join-Path (Split-Path $taskRunPath -Parent) '.gdignore') -Value ''
$taskPreviousSettings = $env:HUNT_SETTINGS_PATH
$taskPreviousMap = $env:HUNT_TEST_MAP
$env:HUNT_TEST_MAP = $Map
$taskProcesses = @()
try {
    foreach ($taskRole in @('host','client1','client2','client3','extra')) {
        $env:HUNT_SETTINGS_PATH = Join-Path $taskRunPath ($taskRole + '_settings.cfg')
        $taskArguments = @('--headless','--max-fps','60','--path',('"' + $taskProjectPath + '"'),'--log-file',('"' + (Join-Path $taskRunPath ($taskRole + '_engine.log')) + '"'),'--script','res://tests/network_peer.gd','--quit-after','12000','--',$taskRole,('"' + $taskRunPath + '"'))
        $taskProcesses += Start-Process -FilePath $taskEnginePath -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRunPath ($taskRole + '.log')) -RedirectStandardError (Join-Path $taskRunPath ($taskRole + '_err.log'))
    }
    $taskFailed = $false
    foreach ($taskProcess in $taskProcesses) {
        $taskProcess.WaitForExit()
        if ($taskProcess.ExitCode -ne 0) { $taskFailed = $true }
    }
    foreach ($taskRole in @('host','client1','client2','client3','extra')) {
        $taskReportPath = Join-Path $taskRunPath ($taskRole + '.json')
        if (-not (Test-Path -LiteralPath $taskReportPath)) { $taskFailed = $true; continue }
        $taskReport = Get-Content -LiteralPath $taskReportPath -Raw | ConvertFrom-Json
        Write-Output ("{0}: {1} checks, {2} failures" -f $taskRole,$taskReport.checks,$taskReport.failures)
        if ($taskReport.failures -ne 0) { $taskFailed = $true }
        if (Select-String -LiteralPath (Join-Path $taskRunPath ($taskRole + '_err.log')) -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { $taskFailed = $true }
    }
    Write-Output ('Reports: ' + $taskRunPath)
    if ($taskFailed) { exit 1 }
} finally {
    $env:HUNT_SETTINGS_PATH = $taskPreviousSettings
    $env:HUNT_TEST_MAP = $taskPreviousMap
}
