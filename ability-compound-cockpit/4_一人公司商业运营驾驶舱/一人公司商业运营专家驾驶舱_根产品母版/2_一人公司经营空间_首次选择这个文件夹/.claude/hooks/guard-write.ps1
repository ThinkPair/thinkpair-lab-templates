$ErrorActionPreference = 'Stop'

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Write-Decision {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('allow', 'deny')][string]$Decision,
    [Parameter(Mandatory = $true)][string]$Reason
  )

  $output = @{
    hookSpecificOutput = @{
      hookEventName = 'PreToolUse'
      permissionDecision = $Decision
      permissionDecisionReason = $Reason
    }
  }
  [Console]::Out.Write(($output | ConvertTo-Json -Depth 5 -Compress))
  exit 0
}

function Get-MessageText {
  param($Content)

  if ($null -eq $Content) { return '' }
  if ($Content -is [string]) { return $Content }

  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($block in @($Content)) {
    if ($block -is [string]) {
      $parts.Add($block)
      continue
    }
    if ($null -ne $block -and $block.type -eq 'text' -and $null -ne $block.text) {
      $parts.Add([string]$block.text)
    }
  }
  return ($parts -join "`n")
}

function Get-ConversationEvidence {
  param([Parameter(Mandatory = $true)][string]$TranscriptPath)

  if (-not (Test-Path -LiteralPath $TranscriptPath -PathType Leaf)) {
    throw 'Transcript is unavailable.'
  }

  $messages = New-Object System.Collections.Generic.List[object]
  foreach ($line in [IO.File]::ReadLines($TranscriptPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $row = $line | ConvertFrom-Json } catch { continue }
    if ($row.type -notin @('user', 'assistant')) { continue }

    $role = [string]$row.type
    $content = $null
    if ($null -ne $row.message) {
      if ($null -ne $row.message.role) { $role = [string]$row.message.role }
      $content = $row.message.content
    } elseif ($null -ne $row.content) {
      $content = $row.content
    }

    $text = Get-MessageText $content
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    $messages.Add([pscustomobject]@{ Role = $role; Text = $text })
  }

  $lastUserIndex = -1
  for ($i = $messages.Count - 1; $i -ge 0; $i--) {
    if ($messages[$i].Role -eq 'user') {
      $lastUserIndex = $i
      break
    }
  }
  if ($lastUserIndex -lt 0) { throw 'No user confirmation was found.' }

  $assistantText = ''
  for ($i = $lastUserIndex - 1; $i -ge 0; $i--) {
    if ($messages[$i].Role -eq 'assistant') {
      $assistantText = $messages[$i].Text
      break
    }
  }

  return [pscustomobject]@{
    UserText = $messages[$lastUserIndex].Text
    AssistantText = $assistantText
  }
}

function Remove-AttachedContext {
  param([string]$Text)
  $clean = $Text.Trim()
  $pattern = '(?is)\s*<(current_note|editor_selection|browser_selection)(?:\s+[^>]*)?>.*?</\1>\s*$'
  while ($clean -match $pattern) {
    $clean = [regex]::Replace($clean, $pattern, '').Trim()
  }
  return $clean
}

function Test-ExplicitWriteConfirmation {
  param([string]$Text)

  # 安全优先：只要同一条回复里出现否定、暂停、修改或犹豫语义，就不把它当作写入授权。
  # 这样“可以写，但先改一下”“先别写”等混合表达会先被拒绝。
  $clean = (Remove-AttachedContext $Text).Trim()
  if ([string]::IsNullOrWhiteSpace($clean)) { return $false }
  if ($clean -match '(不写|别写|不要写|不能写|不可写|先别|先不|暂不|暂停|暂缓|等等|等一下|取消|撤销|拒绝|再看看|有问题|不对|修改|改成|调整|先改|尚未|未确认)') {
    return $false
  }

  # 只接受完整、明确、无附加条件的同意句；单独的“好”“行”“知道了”仍不放行。
  $normalized = [regex]::Replace($clean, '[\s，,。.!！；;：:]+', '')
  $allowed = @(
    '确认', '确认写入', '可以写', '可以写入', '可以写了', '可以执行',
    '可以执行了', '确认可以写', '就按这个', '就按这个吧',
    '就按这个写', '就按这个写入', '就按这个执行', '按这个来',
    '按这个来吧', '按这个写', '按这个写入', '按这个执行',
    '照这个写', '就这样写', '就这么写', '没问题写吧',
    '没问题就写吧', '执行吧', '确认执行', '请执行', '开始执行',
    '请写入', '写入吧', '开始写入', '写吧'
  )
  return $allowed -contains $normalized
}

function Test-AllowedTargetBreakdownCommand {
  param([string]$Command)

  if ([string]::IsNullOrWhiteSpace($Command) -or $Command.Length -gt 20000) { return $false }
  $normalized = ($Command -replace '\\', '/').Trim()
  if ($normalized -match '[\r\n\t;&|`$><\(\)]') { return $false }
  $prefix = '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/target-breakdown\.js\s+--target\s+20_经营数据/经营目标/目标方案/btp-[a-f0-9]{16}\.md'
  $base64Pattern = $prefix + '\s+--input-base64\s+[A-Za-z0-9_-]+$'
  if ($normalized -cmatch $base64Pattern) { return $true }

  $money = '(?:0|[1-9]\d*)(?:\.\d{1,2})?'
  $integer = '(?:0|[1-9]\d*)'
  $rate = '(?:0|[1-9]\d*)(?:\.\d{1,4})?'
  $name = '[\p{L}\p{N}_-]{1,24}'
  $channelRows = $name + ':' + $rate + '(?:,' + $name + ':' + $rate + '){0,2}'
  $weekRows = $name + ':' + $rate + '(?:,' + $name + ':' + $rate + '){0,4}'
  $required = '\s+--actual-cash\s+' + $money +
    '\s+--actual-deals\s+' + $integer +
    '\s+--actual-revenue\s+' + $money +
    '\s+--actual-delivery\s+' + $rate +
    '\s+--remaining-days\s+' + $integer
  $conversion = '(?:\s+--outreach-response\s+' + $rate +
    '\s+--response-discussion\s+' + $rate +
    '\s+--discussion-quote\s+' + $rate +
    '\s+--quote-sale\s+' + $rate +
    '\s+--basis\s+(?:historical|user_estimate|mixed))?'
  $funnelActuals = '(?:\s+--actual-outreach\s+' + $integer +
    '\s+--actual-responses\s+' + $integer +
    '\s+--actual-discussions\s+' + $integer +
    '\s+--actual-quotes\s+' + $integer +
    '\s+--actual-funnel-deals\s+' + $integer + ')?'
  $optional = '(?:\s+--channels\s+' + $channelRows + ')?' +
    '(?:\s+--weeks\s+' + $weekRows + ')?' +
    '(?:\s+--sprint-factor\s+' + $rate + ')?' +
    '(?:\s+--cash-risk\s+(?:true|false))?'
  return $normalized -cmatch ($prefix + $required + $conversion + $funnelActuals + $optional + '$')
}

function Test-AllowedRelativePath {
  param([string]$RelativePath)

  if ([IO.Path]::GetFileName($RelativePath) -ieq 'README.md') { return $false }
  if ($RelativePath -eq '20_经营数据/经营状态.md') { return $true }
  if ($RelativePath -eq '60_AI商业运营专家/写回预览.md') { return $true }
  if ($RelativePath -eq '60_AI商业运营专家/已确认写回记录.md') { return $true }
  if ($RelativePath -match '^20_经营数据/当前项目/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/经营核算/AI结论/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/经营目标/行动计划/oap-[a-f0-9]{16}\.md$') { return $true }
  if ($RelativePath -match '^30_五维周复盘/历史周复盘/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^40_能力商品化/验证记录/[^/]+\.md$') { return $true }
  return $false
}

function Get-FrontmatterScalar {
  param(
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $frontmatterMatch = [regex]::Match($Content, '(?s)\A\uFEFF?---\s*\r?\n(.*?)\r?\n---(?:\r?\n|\z)')
  if (-not $frontmatterMatch.Success) { return $null }
  $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s*:\s*(.*?)\s*$'
  $match = [regex]::Match($frontmatterMatch.Groups[1].Value, $pattern)
  if (-not $match.Success) { return $null }
  $value = $match.Groups[1].Value.Trim()
  if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
    try { return [string]($value | ConvertFrom-Json) } catch { return $null }
  }
  if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
    return $value.Substring(1, $value.Length - 2).Replace("''", "'")
  }
  if ($value -in @('null', '~')) { return $null }
  return $value
}

function Get-FinanceInsightReferenceFailure {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$Content
  )

  foreach ($expectation in @(
    [pscustomobject]@{ Name = 'record_type'; Value = 'finance_ai_insight' },
    [pscustomobject]@{ Name = 'record_status'; Value = 'active' },
    [pscustomobject]@{ Name = 'privacy'; Value = 'sensitive' },
    [pscustomobject]@{ Name = 'schema_version'; Value = 'finance.v1' }
  )) {
    if ((Get-FrontmatterScalar -Content $Content -Name $expectation.Name) -ne $expectation.Value) {
      return ("frontmatter field " + $expectation.Name + " must equal " + $expectation.Value + '.')
    }
  }
  foreach ($requiredName in @('record_id', 'maximum_issue', 'unique_action', 'created_at', 'updated_at')) {
    if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $Content -Name $requiredName))) {
      return ("frontmatter field " + $requiredName + ' is missing.')
    }
  }

  $calculationId = Get-FrontmatterScalar -Content $Content -Name 'calculation_id'
  $inputHash = Get-FrontmatterScalar -Content $Content -Name 'input_hash'
  if ([string]::IsNullOrWhiteSpace($calculationId)) { return 'calculation_id is missing.' }
  if ($calculationId -notmatch '^calc-(?:actual|forecast)-\d{14}-[a-z0-9]{5}$') {
    return 'calculation_id format is invalid.'
  }
  if ([string]::IsNullOrWhiteSpace($inputHash) -or $inputHash -notmatch '^[a-f0-9]{16}$') {
    return 'input_hash must be a 16-character FNV-1a 64-bit hexadecimal value.'
  }

  $candidates = @(@(
      (Join-Path $VaultRoot ("20_经营数据\经营核算\实际核算\$calculationId.md"))
      (Join-Path $VaultRoot ("20_经营数据\经营核算\创业预估\$calculationId.md"))
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  if ($candidates.Count -ne 1) {
    return 'calculation_id does not resolve to exactly one saved calculation.'
  }

  $calculationContent = Get-Content -LiteralPath $candidates[0] -Raw -Encoding utf8
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'record_type') -ne 'business_calculation') {
    return 'the referenced file is not a business_calculation record.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_status') -ne 'confirmed') {
    return 'the referenced calculation is not confirmed.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'hash_algorithm') -ne 'fnv1a64') {
    return 'the referenced calculation does not use the supported fnv1a64 input hash.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_id') -ne $calculationId) {
    return 'calculation_id does not match the referenced calculation frontmatter.'
  }
  if (-not [string]::Equals(
      (Get-FrontmatterScalar -Content $calculationContent -Name 'input_hash'),
      $inputHash,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    return 'input_hash does not match the referenced calculation.'
  }
  return $null
}

function Get-OperatingActionValidationFailure {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($null -eq $node) {
    return 'Node.js is unavailable, so deterministic target formulas cannot be re-run.'
  }
  $validatorPath = Join-Path $VaultRoot '.claude\skills\commercial-operations-expert\scripts\target-breakdown.js'
  if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    return 'The deterministic target-breakdown validator is missing.'
  }

  try {
    $output = @($Content | & $node.Source $validatorPath '--validate-action-stdin' '--vault-root' $VaultRoot '--relative' $RelativePath 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    $validation = $null
    try { $validation = $text | ConvertFrom-Json } catch {
      return ('The deterministic action validator did not return valid JSON: ' + $text)
    }
    if ($exitCode -ne 0 -or $validation.valid -ne $true) {
      $details = @($validation.errors | ForEach-Object { [string]$_ }) -join '; '
      if ([string]::IsNullOrWhiteSpace($details)) { $details = $text }
      return ('The operating action plan failed deterministic formula/hash validation: ' + $details)
    }
    return $null
  } catch {
    return ('The deterministic action validator could not run: ' + $_.Exception.Message)
  }
}

function Get-MissingCreateSchemaField {
  param(
    [string]$RelativePath,
    [string]$Content
  )

  $required = @()
  if ($RelativePath -match '^20_经营数据/当前项目/') {
    $required = @(
      'record_type: project', 'record_id:', 'record_status: active',
      'fact_gate_confirmed: true', 'fact_gate_confirmed_at:',
      'source_ability_id:', 'created_at:', 'updated_at:',
      '客户:', '项目:', '报价:', '回款:', '下一步:', '本周复盘:',
      'privacy: sensitive', 'schema_version:'
    )
  } elseif ($RelativePath -match '^30_五维周复盘/历史周复盘/') {
    if ([IO.Path]::GetFileName($RelativePath) -notmatch '^\d{4}-W\d{2}\.md$') {
      return 'weekly filename YYYY-Www.md'
    }
    $required = @(
      'record_type: weekly_review', 'record_id:', 'record_status:', 'week:',
      'created_at:', 'updated_at:',
      '营收闭环事实:', '营收闭环判断:', '成本效率事实:', '成本效率判断:',
      '组织流程事实:', '组织流程判断:', '风险合规事实:', '风险合规判断:',
      '数据迭代事实:', '数据迭代判断:', 'maximum_bottleneck:',
      'unique_operating_action:', 'privacy: sensitive', 'schema_version:'
    )
  } elseif ($RelativePath -match '^40_能力商品化/验证记录/') {
    $required = @(
      'record_type: monetization_validation', 'record_id:', 'record_status:',
      'validation_status:', 'fact_gate_confirmed:', 'fact_gate_confirmed_at:',
      'created_at:', 'updated_at:',
      '能力或结果假设:', '对象假设:', '问题假设:', '最小交付假设:', '价格假设:',
      '本次唯一动作:', '验收信号:', '用户事实:', '外部证据:', 'AI建议:',
      '回应与讨论证据:', 'converted_project_id:', 'privacy: sensitive', 'schema_version:'
    )
  } elseif ($RelativePath -match '^20_经营数据/经营核算/AI结论/') {
    $required = @(
      'record_type: finance_ai_insight', 'record_id:', 'record_status: active',
      'calculation_id:', 'input_hash:', 'maximum_issue:', 'unique_action:',
      'created_at:', 'updated_at:', 'privacy: sensitive', 'schema_version: "finance.v1"'
    )
  } elseif ($RelativePath -match '^20_经营数据/经营目标/行动计划/') {
    $required = @(
      'record_type: operating_action_plan', 'action_plan_id:', 'record_status: active',
      'target_plan_id:', 'target_input_hash:', 'breakdown_input_hash:', 'target_month:',
      'hash_algorithm: fnv1a64', 'created_at:', 'updated_at:',
      'privacy: sensitive', 'schema_version: "operating_action_plan.v1"',
      '<!-- operating-action-plan-json:start -->', '<!-- operating-action-plan-json:end -->'
    )
  }

  foreach ($token in $required) {
    if (-not $Content.Contains($token)) { return $token }
  }
  return $null
}

try {
  $raw = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
  if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Hook input is empty.' }
  $inputData = $raw | ConvertFrom-Json
  $toolName = [string]$inputData.tool_name

  if ($toolName -eq 'Bash') {
    $command = [string]$inputData.tool_input.command
    if (Test-AllowedTargetBreakdownCommand $command) {
      Write-Decision 'allow' 'Allowed the single read-only deterministic target-breakdown command. It cannot write files or chain another shell command.'
    }
    Write-Decision 'deny' 'Shell commands are disabled except for the exact read-only target-breakdown calculation command.'
  }
  if ($toolName -in @('MultiEdit', 'NotebookEdit')) {
    Write-Decision 'deny' 'Batch and notebook edits are disabled. Use one guarded Markdown Edit or Write at a time.'
  }
  if ($toolName -notin @('Edit', 'Write')) {
    Write-Decision 'deny' 'This write-capable tool is not part of the approved operating workflow.'
  }

  $rawPath = [string]$inputData.tool_input.file_path
  if ([string]::IsNullOrWhiteSpace($rawPath)) { throw 'Target file path is missing.' }
  $cwd = [IO.Path]::GetFullPath([string]$inputData.cwd).TrimEnd('\', '/')
  $target = if ([IO.Path]::IsPathRooted($rawPath)) {
    [IO.Path]::GetFullPath($rawPath)
  } else {
    [IO.Path]::GetFullPath((Join-Path $cwd $rawPath))
  }

  $prefix = $cwd + [IO.Path]::DirectorySeparatorChar
  if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Decision 'deny' 'The target is outside the current operating space.'
  }
  $relative = $target.Substring($prefix.Length).Replace('\', '/')
  if ($relative -match '^20_经营数据/经营目标/目标方案/') {
    Write-Decision 'deny' 'Business target plans are deterministic and AI-read-only. Create them only from the target page after its own summary confirmation.'
  }
  if (-not (Test-AllowedRelativePath $relative)) {
    Write-Decision 'deny' ("The target is outside the business-data write whitelist: " + $relative)
  }
  if ($relative -match '^20_经营数据/经营核算/AI结论/' -and $toolName -ne 'Write') {
    Write-Decision 'deny' 'Finance AI insights are append-only. Create a new bound insight instead of editing an existing one.'
  }
  if ($relative -match '^20_经营数据/经营目标/行动计划/' -and $toolName -ne 'Write') {
    Write-Decision 'deny' 'Operating action plans are append-only. Re-run the deterministic breakdown and create a new bound action instead of editing history.'
  }
  if ($toolName -eq 'Write' -and (Test-Path -LiteralPath $target)) {
    Write-Decision 'deny' 'Write may only create a new approved Markdown record. Existing files must use a guarded Edit.'
  }
  if ($toolName -eq 'Edit' -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
    Write-Decision 'deny' 'Edit may only update an existing approved Markdown record. New records must use a guarded Write.'
  }
  if ($toolName -eq 'Edit' -and $inputData.tool_input.replace_all -eq $true) {
    Write-Decision 'deny' 'Replace-all edits are disabled.'
  }

  $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
  $confirmation = Remove-AttachedContext $evidence.UserText
  if (-not (Test-ExplicitWriteConfirmation $confirmation)) {
    Write-Decision 'deny' 'No clear current write approval was found. After the write-back preview, accept only an unqualified explicit approval such as: 确认、确认写入、可以写、就按这个、没问题写吧、执行吧. Ambiguous, negative, conditional, or revision language must not write.'
  }

  $preview = [string]$evidence.AssistantText
  if (-not $preview.Contains('【写回预览】') -or -not $preview.Contains('【等待确认】')) {
    Write-Decision 'deny' 'The immediately preceding assistant message is not a valid current write-back preview.'
  }
  if (-not $preview.Contains($relative)) {
    Write-Decision 'deny' ("The confirmed preview did not list this target: " + $relative)
  }
  if (-not $preview.Contains('【拟写原文】')) {
    Write-Decision 'deny' 'The confirmed preview did not include the exact proposed text marker.'
  }

  if ($toolName -eq 'Write') {
    $content = [string]$inputData.tool_input.content
    if ([string]::IsNullOrWhiteSpace($content) -or -not $preview.Contains($content)) {
      Write-Decision 'deny' 'The Write content does not exactly match text shown in the confirmed preview.'
    }
    $missingSchema = Get-MissingCreateSchemaField $relative $content
    if ($null -ne $missingSchema) {
      Write-Decision 'deny' ("The new record is missing required schema content: " + $missingSchema)
    }
    if ($relative -match '^20_经营数据/经营核算/AI结论/') {
      $referenceFailure = Get-FinanceInsightReferenceFailure -VaultRoot $cwd -Content $content
      if ($null -ne $referenceFailure) {
        Write-Decision 'deny' ("The finance AI insight is not bound to a current saved calculation: " + $referenceFailure)
      }
    }
    if ($relative -match '^20_经营数据/经营目标/行动计划/') {
      $actionFailure = Get-OperatingActionValidationFailure -VaultRoot $cwd -RelativePath $relative -Content $content
      if ($null -ne $actionFailure) {
        Write-Decision 'deny' $actionFailure
      }
    }
  } else {
    $oldString = [string]$inputData.tool_input.old_string
    $newString = [string]$inputData.tool_input.new_string
    if ([string]::IsNullOrEmpty($oldString) -or [string]::IsNullOrEmpty($newString)) {
      Write-Decision 'deny' 'Guarded Edit requires non-empty exact old and new text.'
    }
    if (-not $preview.Contains($oldString) -or -not $preview.Contains($newString)) {
      Write-Decision 'deny' 'The Edit old/new text does not exactly match text shown in the confirmed preview.'
    }
    if ($oldString -match '(?m)^\s*(record_type|record_id|schema_version|privacy)\s*:') {
      Write-Decision 'deny' 'Core record identity and schema fields cannot be changed by the operating write flow.'
    }
  }

  Write-Decision 'allow' ("Confirmed whitelisted Markdown write: " + $relative)
} catch {
  Write-Decision 'deny' ("Write guard could not validate this operation: " + $_.Exception.Message)
}
