$taskName   = "kk-TorontoParksLayer"
$projectDir = $PSScriptRoot
$logFile    = "$projectDir\logs\scheduler.log"

if (-not (Test-Path "$projectDir\logs")) {
    New-Item -ItemType Directory -Path "$projectDir\logs" | Out-Null
}

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c cd /d `"$projectDir`" && python run.py update >> `"$logFile`" 2>&1"

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
# Restart on failure. 'update' exits 75 as soon as it sees no usable link
# instead of blocking on one (the ExecutionTimeLimit would kill a long wait
# anyway), so three tries half an hour apart turn a dead link at 08:15 into a
# run by 09:45 rather than a lost day. A dead resolver cost this task a week
# on 2026-07-27, when it ran weekly.
#
# It also exits 70 when no Overpass mirror answered and the gap page had to fall
# back to cached OSM. That publishes first, so the retry costs a rebuild and not
# the tiles; without it, two 504s in Aug 2026 left the page a fortnight stale
# with the task reporting success both times.
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force

Write-Host "Scheduled '$taskName' to run daily at 08:15."
Write-Host "Log: $logFile"
