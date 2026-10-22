$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

. (Join-Path $PSScriptRoot 'ability-write-core.ps1')

function Write-Decision {
  param([ValidateSet('allow','deny')][string]$Decision, [string]$Reason)
  $output = @{ hookSpecificOutput = @{ hookEventName='PreToolUse'; permissionDecision=$Decision; permissionDecisionReason=$Reason } }
  [Console]::Out.Write(($output | ConvertTo-Json -Depth 6 -Compress))
  exit 0
}

try {
  $raw = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
  if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Hook 输入为空。' }
  $inputData = $raw | ConvertFrom-Json
  $toolName = [string](Get-AbilityProperty $inputData 'tool_name')
  $toolInput = Get-AbilityProperty $inputData 'tool_input'
  $root = [IO.Path]::GetFullPath([string](Get-AbilityProperty $inputData 'cwd')).TrimEnd('\','/')
  $queueRoot = Join-Path $root '.claude\write-queue'

  if ($toolName -in @('MultiEdit','NotebookEdit')) { Write-Decision deny '批量编辑与笔记本编辑被禁用；能力数据只经确定性写入器提交。' }

  if ($toolName -in @('Edit','Write')) {
    if ($toolName -ne 'Write') { Write-Decision deny '正式数据不能直接 Edit；请提交 ability-write.v1 批次。' }
    $rawPath = [string](Get-AbilityProperty $toolInput 'file_path')
    if ([string]::IsNullOrWhiteSpace($rawPath)) { throw 'Write 缺少 file_path。' }
    $target = if ([IO.Path]::IsPathRooted($rawPath)) { [IO.Path]::GetFullPath($rawPath) } else { [IO.Path]::GetFullPath((Join-Path $root $rawPath)) }
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { Write-Decision deny '目标越出当前能力空间。' }
    $relative = $target.Substring($prefix.Length).Replace('\','/')
    if ($relative -notmatch '^\.claude/write-queue/[A-Za-z0-9._-]+\.json$' -or $relative -match '\.(?:permit|result)\.json$') { Write-Decision deny 'Write 只允许创建一次性的 ability-write.v1 队列清单；正式数据由写入器完成。' }
    if (Test-Path -LiteralPath $target) { Write-Decision deny '写入清单封存前不可覆盖；请使用新的 batch_id。' }
    $content = [string](Get-AbilityProperty $toolInput 'content')
    try { $manifest = $content | ConvertFrom-Json } catch { Write-Decision deny '队列清单不是合法 JSON。' }
    $evaluation = Get-AbilityManifestEvaluation $root $manifest -AllowAutoHash
    if ($evaluation.Risk -eq 'blocked') { Write-Decision deny ('清单未通过数据安全校验：' + ($evaluation.BlockedReasons -join '；')) }
    Write-Decision allow ('已接收写入清单；风险级别由写入器判定为 ' + $evaluation.Risk + '。')
  }

  if ($toolName -notin @('Bash','Shell','PowerShell')) { Write-Decision deny '该写能力工具不在许可范围。' }
  $commandText = [string](Get-AbilityProperty $toolInput 'command')
  $writerCall = Test-AbilityWriterCommand $commandText
  if ($null -eq $writerCall) { Write-Decision deny '任意 Shell 已禁用。唯一允许的命令是固定参数的 ability-write.ps1 Inspect/Apply。' }
  $manifestPath = Resolve-AbilityTargetPath $root $writerCall.ManifestPath
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { Write-Decision deny '写入清单不存在。' }
  if ($writerCall.Mode -eq 'Inspect') { Write-Decision allow '允许确定性写入器封存内容哈希并检查风险；此步骤不修改正式数据。' }

  try { $manifest = ([IO.File]::ReadAllText($manifestPath, $utf8) | ConvertFrom-Json) } catch { Write-Decision deny '写入清单不可解析。' }
  $evaluation = Get-AbilityManifestEvaluation $root $manifest
  if ($evaluation.Risk -eq 'blocked') { Write-Decision deny ('批次被硬拦截：' + ($evaluation.BlockedReasons -join '；')) }
  if ((Get-AbilityProperty $manifest 'payload_hash') -ne $evaluation.PayloadHash -or [string]::IsNullOrWhiteSpace($evaluation.PayloadHash)) { Write-Decision deny '清单尚未 Inspect 封存，或内容已在封存后变化。' }

  $confirmedVia = 'routine-auto'
  if ($evaluation.Risk -eq 'confirmation_required') {
    $pendingCount = 0
    if (Test-Path -LiteralPath $queueRoot) {
      foreach ($file in Get-ChildItem -LiteralPath $queueRoot -File -Filter '*.json') {
        if ($file.Name -match '\.(?:permit|result)\.json$') { continue }
        try {
          $candidate = ([IO.File]::ReadAllText($file.FullName, $utf8) | ConvertFrom-Json)
          $candidateEval = Get-AbilityManifestEvaluation $root $candidate
          if ($candidateEval.Risk -eq 'confirmation_required' -and -not [string]::IsNullOrWhiteSpace($candidateEval.PayloadHash)) { $pendingCount++ }
        } catch { }
      }
    }
    $transcriptPath = [string](Get-AbilityProperty $inputData 'transcript_path')
    if (-not (Test-AbilityTranscriptConfirmation $transcriptPath $evaluation.PreviewId $evaluation.PayloadHash $pendingCount)) {
      Write-Decision deny ('本批次需要一次自然语言确认。请只说明改什么、依据、影响、是否可撤销/出库，并展示 preview_id=' + $evaluation.PreviewId + ' 与 payload_hash=' + $evaluation.PayloadHash + '；无需全文预览或固定口令。')
    }
    $confirmedVia = 'natural-language-hash-bound'
  }

  $permitPath = [IO.Path]::ChangeExtension($manifestPath, '.permit.json')
  $permit = [ordered]@{
    schema_version = 'ability-write.permit.v1'
    batch_id = $evaluation.BatchId
    risk = $evaluation.Risk
    preview_id = $evaluation.PreviewId
    payload_hash = $evaluation.PayloadHash
    confirmed_via = $confirmedVia
    granted_at = [DateTimeOffset]::Now.ToString('o')
    expires_at = [DateTimeOffset]::Now.AddHours(2).ToString('o')
  }
  Write-AbilityJsonFile $permitPath $permit
  Write-Decision allow ('一次性许可已签发：' + $evaluation.Risk + ' / ' + $evaluation.BatchId)
} catch {
  Write-Decision deny ('写回守卫无法验证本次操作：' + $_.Exception.Message)
}
