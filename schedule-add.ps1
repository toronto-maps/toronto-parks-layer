$taskName   = "kk-TorontoParksLayer"
$projectDir = $PSScriptRoot
$logFile    = "$projectDir\logs\scheduler.log"

if (-not (Test-Path "$projectDir\logs")) {
    New-Item -ItemType Directory -Path "$projectDir\logs" | Out-Null
}

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"`"$projectDir\run-scheduled.cmd`" >> `"$logFile`" 2>&1`""

# Daily, for the gap page: it diffs against live OSM, which moves every day. The
# City side moves less (a new Green Spaces file roughly weekly) and a download
# that has not changed is skipped. A run takes about 15 minutes, so from 08:15 it
# is done before any other scheduled tippecanoe build starts. Only its retries
# can overlap one: the streets layer, on the 1st at 09:00.
#
# The live task's action is wrapped by task-beholder's taskrun.exe. Re-running
# this script drops the wrap (re-apply with task-beholder's wrap-tasks.ps1); to
# change only the time, use Set-ScheduledTask -Trigger.
$trigger  = New-ScheduledTaskTrigger -Daily -At "08:15"
# Retries live in run-scheduled.cmd, not here: 'update' exits 75 when it sees no
# usable link, and 70 when no Overpass mirror answered and the gap page fell back
# to cached OSM (published first). The wrapper tries either again up to twice, half
# an hour apart, and the 3-hour limit leaves room for that. RestartCount covers only
# a launch that fails; Task Scheduler never re-runs on an exit code.
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 3) -StartWhenAvailable `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force

Write-Host "Scheduled '$taskName' to run daily at 08:15."
Write-Host "Log: $logFile"
