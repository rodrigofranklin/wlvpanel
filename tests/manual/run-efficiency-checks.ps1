#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('before','after')][string]$Phase = 'before',
  [int]$Port = 38134
)
$ErrorActionPreference = 'Stop'
$taskCampaign = $env:WLV_CAMPAIGN_ROOT
if (-not $taskCampaign -or -not (Test-Path -LiteralPath (Join-Path $taskCampaign '.campaign.json'))) { throw 'Managed campaign required.' }
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach ($taskName in @('TEMP','TMP','TMPDIR')) {
  if ([IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable($taskName)) -ne [IO.Path]::GetFullPath((Join-Path $taskCampaign 'scratch'))) { throw 'Temporary directories must belong to the campaign.' }
}
if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) { throw 'Test port is occupied.' }
$env:WLVPANEL_PORT = [string]$Port
$env:WLV_PERF_VARIANT = $Phase
Remove-Item Env:WLVPANEL_COUNTRY_HEADER -ErrorAction SilentlyContinue
$taskServer = $null
try {
  $taskServer = Start-Process -FilePath (Get-Command Rscript.exe).Source -ArgumentList '--vanilla','scripts/run-local-panel.R' -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskCampaign 'logs/server.out.log') -RedirectStandardError (Join-Path $taskCampaign 'logs/server.err.log')
  $taskDeadline = [DateTime]::UtcNow.AddSeconds(90)
  do {
    if ($taskServer.HasExited) { throw 'Test server exited during startup.' }
    try { $taskReady = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/" -TimeoutSec 2).StatusCode -eq 200 } catch { $taskReady = $false }
    if (-not $taskReady) { Start-Sleep -Milliseconds 250 }
  } until ($taskReady -or [DateTime]::UtcNow -gt $taskDeadline)
  if (-not $taskReady) { throw 'Test server failed to start.' }
  [IO.File]::WriteAllText((Join-Path $taskCampaign 'results/server-ready.txt'), [string]$taskServer.Id, [Text.UTF8Encoding]::new($false))
  Write-Output "EFFICIENCY_SERVER_READY $Phase $($taskServer.Id)"
  $taskChecks = @('measure-user-performance.cjs','measure-client-work.cjs','measure-language-delivery.cjs','check-efficiency-equivalence.cjs')
  foreach ($taskCheck in $taskChecks) {
    $taskLog = Join-Path $taskCampaign ('logs/' + $taskCheck + '.log')
    & node (Join-Path $PSScriptRoot $taskCheck) *> $taskLog
    if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $taskLog -Encoding UTF8 -Tail 25; throw "Check failed: $taskCheck" }
    Write-Output "EFFICIENCY_CHECK_PASSED $Phase $taskCheck"
  }
} finally {
  if ($taskServer -and -not $taskServer.HasExited) { Stop-Process -Id $taskServer.Id }
}
