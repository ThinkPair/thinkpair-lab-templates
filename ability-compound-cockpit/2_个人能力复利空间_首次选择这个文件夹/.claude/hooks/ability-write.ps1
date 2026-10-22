param(
  [Parameter(Mandatory = $true)][string]$Manifest,
  [Parameter(Mandatory = $true)][ValidateSet('Inspect','Apply')][string]$Mode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

. (Join-Path $PSScriptRoot 'ability-write-core.ps1')

function Write-ResultAndExit {
  param($Value, [int]$Code = 0)
  [Console]::Out.Write(($Value | ConvertTo-Json -Depth 20 -Compress))
  exit $Code
}

try {
  $root = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
  $queueRoot = Join-Path $root '.claude\write-queue'
  $relativeManifest = Normalize-AbilityRelativePath $Manifest
  if ($relativeManifest -notmatch '^\.claude/write-queue/[A-Za-z0-9._-]+\.json$') { throw 'Manifest 只能位于 .claude/write-queue 且使用安全文件名。' }
  $manifestPath = Resolve-AbilityTargetPath $root $relativeManifest
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest 不存在。' }
  $manifestObject = ([IO.File]::ReadAllText($manifestPath, $utf8) | ConvertFrom-Json)

  if ($Mode -eq 'Inspect') {
    foreach ($op in @(Get-AbilityProperty $manifestObject 'operations')) {
      $path = Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path'))
      $action = [string](Get-AbilityProperty $op 'action')
      $content = Resolve-AbilityAutoNowContent $root $path $action ([string](Get-AbilityProperty $op 'content'))
      $op.content = $content
      $hash = Get-AbilitySha256Text $content
      if ($null -eq $op.PSObject.Properties['content_sha256']) { $op | Add-Member -NotePropertyName content_sha256 -NotePropertyValue $hash }
      else { $op.content_sha256 = $hash }
    }
    $previewId = [string](Get-AbilityProperty $manifestObject 'preview_id')
    if ([string]::IsNullOrWhiteSpace($previewId)) {
      $previewId = 'preview-' + [string](Get-AbilityProperty $manifestObject 'batch_id')
      $manifestObject | Add-Member -NotePropertyName preview_id -NotePropertyValue $previewId -Force
    }
    $payloadHash = Get-AbilityPayloadHash $manifestObject
    $manifestObject | Add-Member -NotePropertyName payload_hash -NotePropertyValue $payloadHash -Force
    Write-AbilityJsonFile $manifestPath $manifestObject
    $evaluation = Get-AbilityManifestEvaluation $root $manifestObject
    Write-ResultAndExit ([ordered]@{
      schema_version = 'ability-write.inspect.v1'
      batch_id = $evaluation.BatchId
      command = $evaluation.Command
      risk = $evaluation.Risk
      preview_id = $evaluation.PreviewId
      payload_hash = $evaluation.PayloadHash
      confirmation_reasons = @($evaluation.ConfirmationReasons)
      blocked_reasons = @($evaluation.BlockedReasons)
      next_action = if ($evaluation.Risk -eq 'routine') { '直接调用同一 Manifest 的 Apply；不要再次询问用户。' } elseif ($evaluation.Risk -eq 'confirmation_required') { '只展示摘要、依据、影响、可撤销性、preview_id 与 payload_hash；自然语言确认一次后调用 Apply。' } else { '修正数据事实或批次；不要尝试绕过。' }
    }) 0
  }

  $evaluation = Get-AbilityManifestEvaluation $root $manifestObject
  if ($evaluation.Risk -eq 'blocked') { throw ('批次被硬拦截：' + ($evaluation.BlockedReasons -join '；')) }
  $declaredPayload = [string](Get-AbilityProperty $manifestObject 'payload_hash')
  if ($declaredPayload -ne $evaluation.PayloadHash) { throw 'Manifest 未经 Inspect 封存，或封存后已变化。' }
  $permitPath = [IO.Path]::ChangeExtension($manifestPath, '.permit.json')
  if (-not (Test-Path -LiteralPath $permitPath -PathType Leaf)) { throw '缺少由写回守卫签发的一次性许可。' }
  $permit = ([IO.File]::ReadAllText($permitPath, $utf8) | ConvertFrom-Json)
  if ((Get-AbilityProperty $permit 'schema_version') -ne 'ability-write.permit.v1' -or
      (Get-AbilityProperty $permit 'batch_id') -ne $evaluation.BatchId -or
      (Get-AbilityProperty $permit 'payload_hash') -ne $evaluation.PayloadHash -or
      (Get-AbilityProperty $permit 'risk') -ne $evaluation.Risk) { throw '一次性许可与当前批次不匹配。' }
  $expiry = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string](Get-AbilityProperty $permit 'expires_at'), [ref]$expiry) -or $expiry -lt [DateTimeOffset]::Now) { throw '一次性许可已过期。' }

  [IO.Directory]::CreateDirectory($queueRoot) | Out-Null
  $lockPath = Join-Path $queueRoot ($evaluation.BatchId + '.lock')
  $lock = $null
  try {
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $applied = Invoke-AbilityAtomicApply $root $manifestObject $queueRoot
    $result = [ordered]@{
      schema_version = 'ability-write.result.v1'
      batch_id = $evaluation.BatchId
      command = $evaluation.Command
      risk = $evaluation.Risk
      payload_hash = $evaluation.PayloadHash
      status = $applied.Status
      changed_files = $applied.Changed
      target_paths = @((Get-AbilityProperty $manifestObject 'operations') | ForEach-Object { Normalize-AbilityRelativePath ([string](Get-AbilityProperty $_ 'path')) })
      applied_at = [DateTimeOffset]::Now.ToString('o')
    }
    $resultDir = Join-Path $queueRoot 'results'
    Write-AbilityJsonFile (Join-Path $resultDir ($evaluation.BatchId + '.result.json')) $result
  } finally {
    if ($null -ne $lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
  }
  Remove-Item -LiteralPath $permitPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
  Write-ResultAndExit $result 0
} catch {
  Write-ResultAndExit ([ordered]@{ schema_version='ability-write.error.v1'; status='blocked'; reason=$_.Exception.Message }) 1
}
