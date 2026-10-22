$ErrorActionPreference = 'Stop'

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Write-Decision {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('allow', 'ask', 'deny')][string]$Decision,
    [Parameter(Mandatory = $true)][string]$Reason,
    [string]$Code = ''
  )

  if ([string]::IsNullOrWhiteSpace($Code)) {
    $Code = switch ($Decision) {
      'allow' { 'allow:operation_valid' }
      'ask' { 'ask:user_confirmation_required' }
      default { 'deny:operation_not_allowed' }
    }
  }

  $output = @{
    hookSpecificOutput = @{
      hookEventName = 'PreToolUse'
      permissionDecision = $Decision
      permissionDecisionReason = ($Code + ' | ' + $Reason)
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

  if ([string]::IsNullOrWhiteSpace($TranscriptPath) -or -not (Test-Path -LiteralPath $TranscriptPath -PathType Leaf)) {
    return [pscustomobject]@{ UserText = ''; AssistantText = '' }
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
  if ($lastUserIndex -lt 0) { return [pscustomobject]@{ UserText = ''; AssistantText = '' } }

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

function Get-WriteIntentDecision {
  param([string]$Text)

  $clean = (Remove-AttachedContext $Text).Trim()
  if ([string]::IsNullOrWhiteSpace($clean)) { return 'ask' }

  # “不要忘记保存”属于明确指令，先移除这类非否定用法，再判断真正的拒绝。
  $negativeProbe = $clean -replace '(不要|别)忘记(?=(?:保存|写入|更新|记录|创建|填入|填进去|执行))', ''
  if ($negativeProbe -match '(先别|先不|暂不|暂缓|暂停|停止|取消|撤销|拒绝|不要(?:再)?(?:保存|写入|更新|记录|创建|填入|填进去|执行)|别(?:再)?(?:保存|写入|更新|记录|创建|填入|填进去|执行)|不(?:要|能|可)?(?:保存|写入|更新|记录|创建|填入|填进去|执行)|别动|不许)') {
    return 'deny'
  }

  $action = '(?:保存|写入|写进去|更新|记录(?:一下|下来)?|创建|执行|填入|填进去|落到文件|建(?:立|一份|一个)?记录|create|save|write|update|record)'
  $explicitConfirmation = $clean -match '^\s*(?:确认(?:写入|保存|执行|更新|记录|创建|填入|填进去)?|同意(?:写入|保存|执行|更新|记录|创建|填入|填进去)?|可以写(?:入)?|就按这个(?:执行|写入|保存)?|照这个(?:执行|写入|保存)?|按这个(?:执行|写入|保存)?)\s*(?:吧|了|。|！|!|$)'
  $actionAtStart = $clean -match ('^\s*' + $action)
  $imperativeMarker = $clean -match ('(?:请|麻烦|帮我|替我|给我|现在|直接|立即|把|将).{0,80}' + $action)
  $hasAction = $explicitConfirmation -or $actionAtStart -or $imperativeMarker
  if (-not $hasAction) { return 'ask' }

  # 已完成和客观叙述不是新授权，例如“我已经保存了”“我有一条记录”。
  $pastTense = $clean -match ('(?:已经|刚刚|刚才|之前|曾经|早就).{0,12}' + $action)
  $nounRecord = $clean -match '(?:我有|这里有|这是一条|看到一条|找到一条).{0,12}记录'
  if (($pastTense -or $nounRecord) -and -not $explicitConfirmation -and -not $imperativeMarker) { return 'ask' }

  # 带修改条件的回复不拒绝，由原生弹窗让用户核对 AI 是否已纳入条件。
  if ($clean -match '(但|不过|只是|前提|条件|如果|除非|先把|先改|改成|修改|调整|加上|补上|删掉|去掉|换成|然后再|之后再)') {
    return 'ask'
  }

  # “为什么写入失败”是排错问题，不是授权；“请帮我保存”仍是直接指令。
  $isRequest = $explicitConfirmation -or $imperativeMarker -or $clean -match '(请|麻烦|帮我|替我|给我|现在|直接|立即|就按|照这个|按这个)'
  if (-not $isRequest -and $clean -match '(为什么|为何|怎么|怎样|哪里|什么问题|失败|拒绝|卡住|是否|是不是|可以吗|行吗|好不好|[？?])') {
    return 'ask'
  }
  return 'allow'
}

function Test-ProtectedOrSecretPath {
  param([string]$PathText)
  $normalized = ([string]$PathText).Replace('\', '/')
  if ($normalized -match '(?i)(^|/)(?:\.ssh|\.aws|\.gnupg|Windows|Program Files|ProgramData)(/|$)') { return $true }
  $name = [IO.Path]::GetFileName($normalized)
  if ($name -match '(?i)^(?:\.env(?:\..*)?|id_rsa|id_ed25519|credentials|claudian-settings\.json|settings\.local\.json)$') { return $true }
  if ([IO.Path]::GetExtension($name) -match '(?i)^\.(?:pem|key|pfx|p12)$') { return $true }
  return $false
}

function Test-ProtectedProductRelativePath {
  param([string]$RelativePath)
  $normalized = ([string]$RelativePath).Replace('\', '/').TrimStart('/')
  return $normalized -match '(?i)^(?:\.claude/(?:hooks|runtime)(?:/|$)|\.claude/settings(?:\.local)?\.json$|\.claudian(?:/|$)|\.obsidian(?:/|$))'
}

function Test-FullCalendarMonth {
  param([string]$StartText, [string]$EndText)
  $start = [DateTime]::MinValue
  $end = [DateTime]::MinValue
  $style = [Globalization.DateTimeStyles]::None
  $culture = [Globalization.CultureInfo]::InvariantCulture
  if (-not [DateTime]::TryParseExact($StartText, 'yyyy-MM-dd', $culture, $style, [ref]$start)) { return $false }
  if (-not [DateTime]::TryParseExact($EndText, 'yyyy-MM-dd', $culture, $style, [ref]$end)) { return $false }
  if ($start.Day -ne 1 -or $start.Year -ne $end.Year -or $start.Month -ne $end.Month) { return $false }
  return $end.Day -eq [DateTime]::DaysInMonth($end.Year, $end.Month)
}

function Get-Sha256FileHex {
  param([Parameter(Mandatory = $true)][string]$Path)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose() }
  } finally { $sha.Dispose() }
}

function Save-UndoSnapshot {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [string]$ToolUseId = ''
  )

  $undoRoot = Join-Path $VaultRoot '.claude\runtime\undo'
  [IO.Directory]::CreateDirectory($undoRoot) | Out-Null
  $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
  $suffix = if ($ToolUseId -match '^[A-Za-z0-9_-]{4,100}$') { $ToolUseId } else { [Guid]::NewGuid().ToString('N').Substring(0, 12) }
  $snapshotRoot = Join-Path $undoRoot ($stamp + '-' + $suffix)
  [IO.Directory]::CreateDirectory($snapshotRoot) | Out-Null
  $snapshotFile = Join-Path $snapshotRoot 'original.md'
  [IO.File]::Copy($Target, $snapshotFile, $false)
  $metadata = [ordered]@{
    format = 'business-cockpit-undo.v1'
    captured_at = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    operation = 'edit'
    target_relative = $RelativePath
    source_sha256 = Get-Sha256FileHex $Target
    restore_from = '.claude/runtime/undo/' + [IO.Path]::GetFileName($snapshotRoot) + '/original.md'
  }
  [IO.File]::WriteAllText((Join-Path $snapshotRoot 'metadata.json'), ($metadata | ConvertTo-Json -Depth 4), $Utf8NoBom)
  return $metadata.restore_from
}

function Get-ReplacedContent {
  param([string]$Original, [string]$OldText, [string]$NewText)
  $first = $Original.IndexOf($OldText, [StringComparison]::Ordinal)
  if ($first -lt 0) { return $null }
  if ($Original.IndexOf($OldText, $first + $OldText.Length, [StringComparison]::Ordinal) -ge 0) { return $null }
  return $Original.Substring(0, $first) + $NewText + $Original.Substring($first + $OldText.Length)
}

function Get-ProtectedIdentityChange {
  param([string]$Before, [string]$After)
  foreach ($name in @('record_type', 'record_id', 'action_plan_id', 'schema_version', 'privacy')) {
    $beforeValue = Get-FrontmatterScalar -Content $Before -Name $name
    $afterValue = Get-FrontmatterScalar -Content $After -Name $name
    if (-not [string]::Equals([string]$beforeValue, [string]$afterValue, [StringComparison]::Ordinal)) { return $name }
  }
  return $null
}

function Test-ExplicitExternalIntent {
  param([string]$Text, [ValidateSet('read', 'web')][string]$Kind)
  $clean = Remove-AttachedContext ([string]$Text)
  if ($Kind -eq 'web') { return $clean -match '(搜索|查资料|外查|联网|网页|网站|链接|研究|对标|验证市场|browse|search|https?://)' }
  return $clean -match '(读取|查看|打开|检查|扫描|分析|导入|这个文件|这个文件夹|这个目录|外部目录|桌面|下载|read|open|inspect)'
}

function Test-ShellChainingOrWrapper {
  param([string]$Command)
  if ($Command -match '[\r\n;&|`><]' -or $Command -match '\$\(') { return $true }
  return $Command -match '(?i)^\s*(?:powershell(?:\.exe)?|pwsh(?:\.exe)?|cmd(?:\.exe)?|bash|sh|python(?:\.exe)?|node(?:\.exe)?)\s+(?:-c|-command|/c|/k|-encodedcommand)\b'
}

function Test-PermanentlyDeniedCommand {
  param([string]$Command)
  return $Command -match '(?i)(?:\brm\s+-[^\r\n]*r|\bRemove-Item\b|\bdel\b|\berase\b|\brmdir\b|\brd\b|\bshred\b|\bsdelete\b|cipher\s+/w|runas\b|Start-Process[^\r\n]*-Verb\s+RunAs|Set-ExecutionPolicy|Disable-WindowsDefender|Set-MpPreference|netsh\b|reg(?:\.exe)?\s+(?:add|delete)|(?:api[_-]?key|auth[_-]?token|password|private[_-]?key)|(?:pay|payment|transfer|转账|付款)|(?:Downloads|AppData[/\\]Local[/\\]Temp)[^\r\n]*\.(?:exe|msi|ps1|bat|cmd|js)\b)'
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
  if ($RelativePath -match '^20_经营数据/当前项目/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/自媒体运营/内容快照/(?!README\.md$|模板_)[a-z0-9-]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/自媒体运营/转化事件/(?!README\.md$|模板_)[a-z0-9-]+\.md$') { return $true }
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

function New-GuardFailure {
  param([string]$Code, [string]$Message)
  return [pscustomobject]@{ Code = $Code; Message = $Message }
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
      return New-GuardFailure 'deny:schema_invalid' ("frontmatter field " + $expectation.Name + " must equal " + $expectation.Value + '.')
    }
  }
  foreach ($requiredName in @('record_id', 'maximum_issue', 'unique_action', 'created_at', 'updated_at')) {
    if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $Content -Name $requiredName))) {
      return New-GuardFailure 'deny:schema_invalid' ("frontmatter field " + $requiredName + ' is missing.')
    }
  }

  $calculationId = Get-FrontmatterScalar -Content $Content -Name 'calculation_id'
  $inputHash = Get-FrontmatterScalar -Content $Content -Name 'input_hash'
  if ([string]::IsNullOrWhiteSpace($calculationId)) { return New-GuardFailure 'deny:schema_invalid' 'calculation_id is missing.' }
  if ($calculationId -notmatch '^calc-(?:actual|forecast)-\d{14}-[a-z0-9]{5}$') {
    return New-GuardFailure 'deny:schema_invalid' 'calculation_id format is invalid.'
  }
  if ([string]::IsNullOrWhiteSpace($inputHash) -or $inputHash -notmatch '^[a-f0-9]{16}$') {
    return New-GuardFailure 'deny:schema_invalid' 'input_hash must be a 16-character FNV-1a 64-bit hexadecimal value.'
  }

  $candidates = @(@(
      (Join-Path $VaultRoot ("20_经营数据\经营核算\实际核算\$calculationId.md"))
      (Join-Path $VaultRoot ("20_经营数据\经营核算\创业预估\$calculationId.md"))
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  if ($candidates.Count -ne 1) {
    return New-GuardFailure 'deny:stale_reference' 'calculation_id does not resolve to exactly one saved calculation.'
  }

  $calculationContent = Get-Content -LiteralPath $candidates[0] -Raw -Encoding utf8
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'record_type') -ne 'business_calculation') {
    return New-GuardFailure 'deny:stale_reference' 'the referenced file is not a business_calculation record.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_status') -ne 'confirmed') {
    return New-GuardFailure 'deny:stale_reference' 'the referenced calculation is not confirmed.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'record_status') -ne 'saved') {
    return New-GuardFailure 'deny:stale_reference' 'the referenced calculation is not a saved record.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'hash_algorithm') -ne 'fnv1a64') {
    return New-GuardFailure 'deny:stale_reference' 'the referenced calculation does not use the supported fnv1a64 input hash.'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_id') -ne $calculationId) {
    return New-GuardFailure 'deny:stale_reference' 'calculation_id does not match the referenced calculation frontmatter.'
  }
  if (-not [string]::Equals(
      (Get-FrontmatterScalar -Content $calculationContent -Name 'input_hash'),
      $inputHash,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    return New-GuardFailure 'deny:stale_reference' 'input_hash does not match the referenced calculation.'
  }

  $reviewRequired = Get-FrontmatterScalar -Content $calculationContent -Name 'period_review_required'
  if ([string]::Equals([string]$reviewRequired, 'true', [StringComparison]::OrdinalIgnoreCase)) {
    return New-GuardFailure 'deny:stale_reference' 'the referenced calculation is marked period_review_required and must be reviewed in the calculation page before an AI insight can be saved.'
  }
  $inputMode = Get-FrontmatterScalar -Content $calculationContent -Name 'input_mode'
  if ($inputMode -eq 'quick_v2') {
    $periodStart = Get-FrontmatterScalar -Content $calculationContent -Name 'period_start'
    $periodEnd = Get-FrontmatterScalar -Content $calculationContent -Name 'period_end'
    if (-not (Test-FullCalendarMonth -StartText $periodStart -EndText $periodEnd)) {
      return New-GuardFailure 'deny:stale_reference' 'legacy quick_v2 calculations are eligible only for one complete calendar month; review the monthly-versus-period cost basis and save a quick_v3 record first.'
    }
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
  } elseif ($RelativePath -match '^20_经营数据/自媒体运营/内容快照/') {
    $required = @(
      'record_type: self_media_content_snapshot', 'record_id:', 'record_status: active',
      'content_id:', 'title:', 'platform:', 'snapshot_at:',
      'source_ref:', 'fact_state:', 'unknown_fields:',
      'created_at:', 'updated_at:', 'privacy: sensitive',
      'schema_version: "self_media_snapshot.v1"'
    )
  } elseif ($RelativePath -match '^20_经营数据/自媒体运营/转化事件/') {
    $required = @(
      'record_type: self_media_conversion_event', 'record_id:', 'record_status: active',
      'event_type:', 'event_at:', 'platform:', 'count:', 'amount:',
      'source_ref:', 'fact_state:', 'attribution_method:',
      'created_at:', 'updated_at:', 'privacy: sensitive',
      'schema_version: "self_media_event.v1"'
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

  if ($toolName -in @('MultiEdit', 'NotebookEdit')) {
    Write-Decision 'deny' 'Batch and notebook edits remain disabled. Use one bounded operation at a time.'
  }

  if ($toolName -eq 'Bash') {
    $command = [string]$inputData.tool_input.command
    $normalized = ($command -replace '\\', '/').Trim()
    if (Test-AllowedTargetBreakdownCommand $command) {
      Write-Decision 'allow' 'Allowed the single read-only deterministic target-breakdown command. It cannot write files or chain another shell command.'
    }
    if ($normalized -cmatch '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/operation-preview\.js\s+--input-base64\s+[A-Za-z0-9_-]+$' -or
        $normalized -cmatch '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/finance-entry\.js\s+--preview\s+--input-base64\s+[A-Za-z0-9_-]+$' -or
        $normalized -cmatch '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/session-export\.js\s+--preview\s+--conversation\s+conv-[A-Za-z0-9-]{8,80}$' -or
        $normalized -cmatch '^powershell(?:\.exe)?\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+\.claude/skills/commercial-operations-expert/scripts/safe-recycle\.ps1\s+-Mode\s+preview\s+-PathBase64\s+[A-Za-z0-9_-]+$') {
      Write-Decision 'allow' 'Allowed one deterministic read-only preview command.'
    }
    # 兼容旧参数，但不再从聊天正文解析或核对 preview_id / payload_hash。
    $legacyTokens = '(?:\s+--preview-id\s+opv-[a-f0-9]{16}\s+--payload-hash\s+sha256:[a-f0-9]{64})?'
    $stage = [regex]::Match($normalized, '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/finance-entry\.js\s+--stage\s+--input-base64\s+[A-Za-z0-9_-]+' + $legacyTokens + '$')
    $export = [regex]::Match($normalized, '^node(?:\.exe)?\s+\.claude/skills/commercial-operations-expert/scripts/session-export\.js\s+--export\s+--conversation\s+conv-[A-Za-z0-9-]{8,80}' + $legacyTokens + '$')
    if ($stage.Success -or $export.Success) {
      $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
      $intent = Get-WriteIntentDecision $evidence.UserText
      if ($intent -eq 'deny') {
        Write-Decision 'deny' 'The latest user message explicitly declines this write operation.' 'deny:user_declined'
      }
      if ($intent -eq 'ask') {
        Write-Decision 'ask' 'This approved draft or export is valid, but the latest message is not an unambiguous write instruction. Confirm it once in the native dialog.' 'ask:user_confirmation_required'
      }
      Write-Decision 'allow' $(if ($stage.Success) { 'Direct user instruction allows one finance input draft stage; no formal calculation is created.' } else { 'Direct user instruction allows one source-backed, redacted session export.' }) 'allow:direct_user_instruction'
    }
    if ($normalized -cmatch '^powershell(?:\.exe)?\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+\.claude/skills/commercial-operations-expert/scripts/safe-recycle\.ps1\s+-Mode\s+recycle\s+-PathBase64\s+[A-Za-z0-9_-]+\s+-PreviewId\s+opv-[a-f0-9]{16}\s+-PayloadHash\s+sha256:[a-f0-9]{64}$') {
      Write-Decision 'ask' 'This moves one selected file to the Windows Recycle Bin. Verify the path in the native confirmation dialog.'
    }
    if (Test-ShellChainingOrWrapper $command) {
      Write-Decision 'deny' 'Chained commands, redirection, command substitution, and nested shell/interpreter wrappers are not allowed.' 'deny:permanent_risk'
    }
    if (Test-PermanentlyDeniedCommand $command) {
      Write-Decision 'deny' 'This command matches a permanent safety boundary: credentials, privilege/security changes, permanent deletion, payment, or execution from a download/temp location.' 'deny:permanent_risk'
    }
    Write-Decision 'ask' 'This is a single bounded shell operation outside the deterministic previews. Review the exact command before allowing it once.'
  }

  if ($toolName -eq 'Read') {
    $rawPath = [string]$inputData.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($rawPath)) { throw 'Read path is missing.' }
    $cwd = [IO.Path]::GetFullPath([string]$inputData.cwd).TrimEnd('\', '/')
    $target = if ([IO.Path]::IsPathRooted($rawPath)) { [IO.Path]::GetFullPath($rawPath) } else { [IO.Path]::GetFullPath((Join-Path $cwd $rawPath)) }
    if (Test-ProtectedOrSecretPath $target) { Write-Decision 'deny' 'Credential-bearing and protected system paths cannot be read by the operating expert.' 'deny:path_protected' }
    $prefix = $cwd + [IO.Path]::DirectorySeparatorChar
    if ($target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      $relative = $target.Substring($prefix.Length).Replace('\', '/')
      if (Test-ProtectedProductRelativePath $relative) {
        Write-Decision 'deny' 'Safeguard code, permission settings, provider settings, and runtime audit files are not readable by the product AI.' 'deny:path_protected'
      }
      Write-Decision 'allow' 'Allowed a read inside the current operating space.' 'allow:vault_read'
    }
    $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
    if (Test-ExplicitExternalIntent $evidence.UserText 'read') { Write-Decision 'ask' 'The user requested external material. Confirm this selected path for the current task.' }
    Write-Decision 'deny' 'Reading outside the operating space requires an explicit user request for that file or directory.'
  }

  if ($toolName -in @('Glob', 'Grep')) {
    $cwd = [IO.Path]::GetFullPath([string]$inputData.cwd).TrimEnd('\', '/')
    $rawPath = [string]$inputData.tool_input.path
    $searchShape = ([string]$inputData.tool_input.pattern) + ' ' + ([string]$inputData.tool_input.glob)
    if ($searchShape -match '(?i)(?:\.claudian/claudian-settings|\.claude/(?:hooks|runtime)|\.claude/settings|guard-write|post-write-audit|\.env(?:\.|$)|\.ssh|credentials|private[_-]?key)') {
      Write-Decision 'deny' 'Search patterns may not target safeguards, permission settings, runtime audit files, provider credentials, or other secrets.' 'deny:path_protected'
    }
    if ([string]::IsNullOrWhiteSpace($rawPath)) { Write-Decision 'allow' 'Allowed search inside the current operating space.' }
    $target = if ([IO.Path]::IsPathRooted($rawPath)) { [IO.Path]::GetFullPath($rawPath) } else { [IO.Path]::GetFullPath((Join-Path $cwd $rawPath)) }
    if (Test-ProtectedOrSecretPath $target) { Write-Decision 'deny' 'Credential-bearing and protected system paths cannot be searched.' 'deny:path_protected' }
    $prefix = $cwd + [IO.Path]::DirectorySeparatorChar
    if ($target -eq $cwd -or $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      $relative = if ($target -eq $cwd) { '' } else { $target.Substring($prefix.Length).Replace('\', '/') }
      if (-not [string]::IsNullOrWhiteSpace($relative) -and (Test-ProtectedProductRelativePath $relative)) {
        Write-Decision 'deny' 'Safeguard code, permission settings, provider settings, and runtime audit files cannot be searched by the product AI.' 'deny:path_protected'
      }
      Write-Decision 'allow' 'Allowed search inside the current operating space.' 'allow:vault_search'
    }
    $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
    if (Test-ExplicitExternalIntent $evidence.UserText 'read') { Write-Decision 'ask' 'Confirm this external search scope for the current task.' }
    Write-Decision 'deny' 'Searching outside the operating space requires explicit user scope.'
  }

  if ($toolName -in @('WebFetch', 'WebSearch')) {
    $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
    if (Test-ExplicitExternalIntent $evidence.UserText 'web') { Write-Decision 'allow' 'The user explicitly requested public-web research for this task; sources must remain external evidence.' }
    Write-Decision 'deny' 'Public-web research starts only after the user explicitly asks to search, research, compare, or open a link.'
  }

  if ($toolName -like 'mcp__*') {
    $serialized = ([string]($inputData.tool_input | ConvertTo-Json -Depth 20 -Compress))
    if ($toolName -match '(?i)(delete|remove|destroy|payment|pay|transfer|credential|secret|security|admin|system_setting)' -or $serialized -match '(?i)(api[_-]?key|auth[_-]?token|private[_-]?key|password)') {
      Write-Decision 'deny' 'This external tool call crosses a permanent boundary: permanent deletion, payment, credentials, privilege, or system security.' 'deny:permanent_risk'
    }
    if ($toolName -match '(?i)(send|publish|post|submit|upload|overwrite|move|rename|browser|chrome)') {
      Write-Decision 'ask' 'This external operation can change state or disclose data. Confirm the exact action once in the native dialog.'
    }
    if ($toolName -match '(?i)(read|search|fetch|get|list)') {
      $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
      if (Test-ExplicitExternalIntent $evidence.UserText 'web') {
        Write-Decision 'allow' 'The user explicitly requested connector-based public research for this task.'
      }
      if (Test-ExplicitExternalIntent $evidence.UserText 'read') {
        Write-Decision 'ask' 'Confirm this external read/research scope for the current task.'
      }
      Write-Decision 'deny' 'External connector reads require an explicit user request.'
    }
    Write-Decision 'ask' 'This connector operation is outside the local read-only workflow. Review and allow it once if intended.'
  }

  if ($toolName -notin @('Edit', 'Write')) {
    Write-Decision 'ask' 'This operation is outside the automatic local read-only class. Review it once before allowing.'
  }

  $rawPath = [string]$inputData.tool_input.file_path
  if ([string]::IsNullOrWhiteSpace($rawPath)) { throw 'Target file path is missing.' }
  $cwd = [IO.Path]::GetFullPath([string]$inputData.cwd).TrimEnd('\', '/')
  $target = if ([IO.Path]::IsPathRooted($rawPath)) {
    [IO.Path]::GetFullPath($rawPath)
  } else {
    [IO.Path]::GetFullPath((Join-Path $cwd $rawPath))
  }

  if (Test-ProtectedOrSecretPath $target) { Write-Decision 'deny' 'Credential-bearing and protected system paths cannot be written.' 'deny:path_protected' }
  $prefix = $cwd + [IO.Path]::DirectorySeparatorChar
  $insideVault = $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
  $relative = if ($insideVault) { $target.Substring($prefix.Length).Replace('\', '/') } else { $target.Replace('\', '/') }
  if ($insideVault -and ($relative -match '^(?:\.claude|\.claudian|\.obsidian|10_商业运营专家内核)(?:/|$)' -or $relative -in @('CLAUDE.md', 'AGENTS.md'))) {
    Write-Decision 'deny' 'The AI cannot modify safeguards, provider settings, Obsidian settings, root instructions, or the expert kernel.' 'deny:path_protected'
  }
  if ($relative -match '^20_经营数据/经营目标/目标方案/') {
    Write-Decision 'deny' 'Business target plans are deterministic and AI-read-only. Create them only from the target page after its own summary confirmation.' 'deny:path_protected'
  }

  $evidence = Get-ConversationEvidence ([string]$inputData.transcript_path)
  $intent = Get-WriteIntentDecision $evidence.UserText
  if ($intent -eq 'deny') {
    Write-Decision 'deny' 'The latest user message explicitly declines this write operation.' 'deny:user_declined'
  }

  # 库外新建、覆盖或编辑始终交给原生弹窗逐次确认，不因聊天指令自动放行。
  if (-not $insideVault) {
    Write-Decision 'ask' 'This operation changes a file outside the operating space. Review the exact path and change once in the native confirmation dialog.' 'ask:external_state_change'
  }
  if ($insideVault -and -not (Test-AllowedRelativePath $relative)) {
    Write-Decision 'deny' ("The target is outside the business-data write whitelist: " + $relative) 'deny:path_protected'
  }
  if ($relative -match '^20_经营数据/经营核算/AI结论/' -and $toolName -ne 'Write') {
    Write-Decision 'deny' 'Finance AI insights are append-only. Create a new bound insight instead of editing an existing one.' 'deny:path_protected'
  }
  if ($relative -match '^20_经营数据/经营目标/行动计划/' -and $toolName -ne 'Write') {
    Write-Decision 'deny' 'Operating action plans are append-only. Re-run the deterministic breakdown and create a new bound action instead of editing history.' 'deny:path_protected'
  }
  if ($relative -match '^20_经营数据/自媒体运营/(?:内容快照|转化事件)/' -and $toolName -ne 'Write') {
    Write-Decision 'deny' 'Self-media snapshots and conversion events are append-only. Create a new evidence-bound record instead of editing history.' 'deny:path_protected'
  }
  if ($insideVault -and $toolName -eq 'Write' -and (Test-Path -LiteralPath $target)) {
    Write-Decision 'deny' 'Write may only create a new approved Markdown record. Existing files must use a guarded Edit.' 'deny:schema_invalid'
  }
  if ($toolName -eq 'Edit' -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
    Write-Decision 'deny' 'Edit may only update an existing approved Markdown record. New records must use a guarded Write.' 'deny:schema_invalid'
  }
  if ($toolName -eq 'Edit' -and $inputData.tool_input.replace_all -eq $true) {
    Write-Decision 'deny' 'Replace-all edits are disabled.' 'deny:schema_invalid'
  }

  if ($toolName -eq 'Write') {
    $content = [string]$inputData.tool_input.content
    if ([string]::IsNullOrWhiteSpace($content)) {
      Write-Decision 'deny' 'A new business record cannot be empty.' 'deny:schema_invalid'
    }
    $missingSchema = Get-MissingCreateSchemaField $relative $content
    if ($null -ne $missingSchema) {
      Write-Decision 'deny' ("The new record is missing required schema content: " + $missingSchema) 'deny:schema_invalid'
    }
    if ($relative -match '^20_经营数据/经营核算/AI结论/') {
      $referenceFailure = Get-FinanceInsightReferenceFailure -VaultRoot $cwd -Content $content
      if ($null -ne $referenceFailure) {
        Write-Decision 'deny' ("The finance AI insight is not bound to a current saved calculation: " + $referenceFailure.Message) $referenceFailure.Code
      }
    }
    if ($relative -match '^20_经营数据/经营目标/行动计划/') {
      $actionFailure = Get-OperatingActionValidationFailure -VaultRoot $cwd -RelativePath $relative -Content $content
      if ($null -ne $actionFailure) {
        Write-Decision 'deny' $actionFailure 'deny:schema_invalid'
      }
    }
  } else {
    $oldString = [string]$inputData.tool_input.old_string
    $newString = [string]$inputData.tool_input.new_string
    if ([string]::IsNullOrEmpty($oldString) -or [string]::IsNullOrEmpty($newString)) {
      Write-Decision 'deny' 'Guarded Edit requires non-empty exact old and new text.' 'deny:schema_invalid'
    }
    $original = Get-Content -LiteralPath $target -Raw -Encoding utf8
    $proposed = Get-ReplacedContent -Original $original -OldText $oldString -NewText $newString
    if ($null -eq $proposed) {
      Write-Decision 'deny' 'The edit anchor must occur exactly once in the current file.' 'deny:schema_invalid'
    }
    $identityChange = Get-ProtectedIdentityChange -Before $original -After $proposed
    if ($null -ne $identityChange) {
      Write-Decision 'deny' ("Core record identity or privacy cannot change in this flow: " + $identityChange) 'deny:schema_invalid'
    }
    $missingSchema = Get-MissingCreateSchemaField $relative $proposed
    if ($null -ne $missingSchema) {
      Write-Decision 'deny' ("The edited record would violate its schema: " + $missingSchema) 'deny:schema_invalid'
    }
    $restoreFrom = Save-UndoSnapshot -VaultRoot $cwd -Target $target -RelativePath $relative -ToolUseId ([string]$inputData.tool_use_id)
  }

  if ($intent -eq 'ask') {
    $restoreNote = if ($toolName -eq 'Edit') { ' A pre-edit recovery snapshot is available at ' + $restoreFrom + '.' } else { '' }
    Write-Decision 'ask' ("The business-data change passed path and schema checks, but the latest message is not an unambiguous write instruction. Confirm it once in the native dialog." + $restoreNote) 'ask:user_confirmation_required'
  }
  $restoreNote = if ($toolName -eq 'Edit') { ' Recovery snapshot: ' + $restoreFrom + '.' } else { '' }
  Write-Decision 'allow' ("Direct user instruction allows this validated business-data write: " + $relative + '.' + $restoreNote) 'allow:direct_user_instruction'
} catch {
  Write-Decision 'deny' ("Write guard could not validate this operation: " + $_.Exception.Message) 'deny:operation_not_allowed'
}
