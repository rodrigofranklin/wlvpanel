#requires -Version 7.5
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$manager=Join-Path $repo 'scripts/manage-campaigns.ps1'
. (Join-Path $repo 'scripts/campaign-paths.ps1')
$id='storage-selftest-'+[Guid]::NewGuid().ToString('N')
$campaign=& $manager -Action New -Id $id -Purpose 'Panel campaign deletion boundaries'
$root=$campaign.root
$checks=[Collections.Generic.List[string]]::new()
function Reject([scriptblock]$Operation,[string]$Name){
  $rejected=$false
  try{& $Operation > $null}catch{$rejected=$true}
  if(-not $rejected){throw "Expected rejection: $Name"}
  $checks.Add($Name)
}
try{
  Reject {& $manager -Action Clean -Id $id -Apply} 'active campaign'
  Reject {& $manager -Action New -Id '../escape'} 'path traversal'
  Reject {Assert-WlvCampaignOutputPath (Join-Path $repo 'run_logs/forbidden.json')} 'external output'
  $null=Assert-WlvCampaignOutputPath (Join-Path $root 'logs/accepted.json')
  $checks.Add('active output accepted')
  $sentinel=Join-Path $root 'results/sentinel.txt'
  [IO.File]::WriteAllText($sentinel,'preserve through dry run')
  $null=& $manager -Action Complete -Id $id -Preserve
  Reject {& $manager -Action Clean -Id $id -Apply} 'preserved campaign'
  Reject {Assert-WlvCampaignOutputPath (Join-Path $root 'logs/closed.json')} 'closed output'
  # This fixture's preservation flag is reset only after testing refusal.
  $manifestPath=Join-Path $root '.campaign.json'
  $record=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
  if($record.id -cne $id -or $record.purpose -cne 'Panel campaign deletion boundaries'){throw 'Unexpected fixture'}
  $record.preserve=$false
  [IO.File]::WriteAllText($manifestPath,($record | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $null=& $manager -Action Clean -Id $id
  if(-not(Test-Path -LiteralPath $sentinel)){throw 'Dry run deleted a file'}
  $checks.Add('dry run preserved files')
  $worktree=Join-Path $root 'worktrees/fixture'
  & git -C $repo worktree add --detach $worktree HEAD > $null 2>&1
  if($LASTEXITCODE -ne 0){throw 'Fixture worktree creation failed'}
  $file=Join-Path $worktree 'global.R'
  $original=[IO.File]::ReadAllBytes($file)
  [IO.File]::AppendAllText($file,"`n# selftest`n")
  Reject {& $manager -Action Clean -Id $id -Apply} 'dirty worktree'
  [IO.File]::WriteAllBytes($file,$original)
  $null=& $manager -Action Clean -Id $id -Apply
  if(Test-Path -LiteralPath $root){throw 'Campaign was not removed'}
  $checks.Add('clean worktree removed')
  [pscustomobject]@{passed=$true;count=$checks.Count;checks=@($checks.ToArray())} | ConvertTo-Json
}finally{
  if(Test-Path -LiteralPath $root){Write-Warning "Failed fixture retained for inspection: $root"}
}
