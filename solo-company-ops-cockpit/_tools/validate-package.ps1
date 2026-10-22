param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot,
  [switch]$ReleaseMode
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Test-PinnedHomeLeaf {
  param($Node)
  if ($null -eq $Node) { return $false }
  if ($Node.type -eq 'leaf' -and
      $Node.state.state.file -eq '00_开始这里/首页.md' -and
      $Node.pinned -eq $true -and
      $Node.state.pinned -eq $true) {
    return $true
  }
  foreach ($child in @($Node.children)) {
    if (Test-PinnedHomeLeaf $child) { return $true }
  }
  return $false
}

function Normalize-ReleaseText {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { return '' }
  return (($Text -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd()
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

function Get-FinanceCalculationReferenceFailure {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$CalculationId,
    [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$InputHash
  )

  if ([string]::IsNullOrWhiteSpace($CalculationId)) { return '缺少 calculation_id' }
  if ([string]::IsNullOrWhiteSpace($InputHash)) { return '缺少 input_hash' }
  if ($CalculationId -notmatch '^calc-(?:actual|forecast)-\d{14}-[a-z0-9]{5}$') {
    return 'calculation_id 格式错误'
  }
  if ($InputHash -notmatch '^[a-f0-9]{16}$') {
    return 'input_hash 不是 16 位 FNV-1a 64-bit 十六进制值'
  }
  $candidates = @(@(
      (Join-Path $VaultRoot ("20_经营数据\经营核算\实际核算\$CalculationId.md"))
      (Join-Path $VaultRoot ("20_经营数据\经营核算\创业预估\$CalculationId.md"))
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  if ($candidates.Count -ne 1) { return 'calculation_id 没有唯一对应已保存核算' }

  $calculationContent = Get-Content -LiteralPath $candidates[0] -Raw -Encoding utf8
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'record_type') -ne 'business_calculation') {
    return '引用目标不是 business_calculation'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_status') -ne 'confirmed') {
    return '引用核算尚未 confirmed'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'hash_algorithm') -ne 'fnv1a64') {
    return '引用核算的 hash_algorithm 不是 fnv1a64'
  }
  if ((Get-FrontmatterScalar -Content $calculationContent -Name 'calculation_id') -ne $CalculationId) {
    return '引用文件内 calculation_id 不一致'
  }
  if (-not [string]::Equals(
      (Get-FrontmatterScalar -Content $calculationContent -Name 'input_hash'),
      $InputHash,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    return '引用文件内 input_hash 不一致'
  }
  return $null
}

function Test-FinanceDataSchemas {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)

  $calculationDirectories = @(
    [pscustomobject]@{ Relative = '20_经营数据\经营核算\实际核算'; Mode = 'actual' },
    [pscustomobject]@{ Relative = '20_经营数据\经营核算\创业预估'; Mode = 'forecast' }
  )
  foreach ($entry in $calculationDirectories) {
    $directory = Join-Path $VaultRoot $entry.Relative
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Force -File | Where-Object { $_.Name -ne 'README.md' })) {
      $relative = $file.FullName.Substring($VaultRoot.Length + 1)
      if ($file.Extension -ne '.md') {
        $script:failures.Add("经营核算目录含非 Markdown 记录：$relative")
        continue
      }
      $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
      $calculationId = Get-FrontmatterScalar -Content $content -Name 'calculation_id'
      $inputHash = Get-FrontmatterScalar -Content $content -Name 'input_hash'
      if ((Get-FrontmatterScalar -Content $content -Name 'record_type') -ne 'business_calculation') {
        $script:failures.Add("核算 record_type 错误：$relative")
      }
      if ((Get-FrontmatterScalar -Content $content -Name 'calculation_mode') -ne $entry.Mode) {
        $script:failures.Add("核算模式与目录不一致：$relative")
      }
      if ((Get-FrontmatterScalar -Content $content -Name 'calculation_status') -ne 'confirmed') {
        $script:failures.Add("已保存核算不是 confirmed：$relative")
      }
      if ((Get-FrontmatterScalar -Content $content -Name 'record_status') -ne 'saved') {
        $script:failures.Add("已保存核算 record_status 不是 saved：$relative")
      }
      $schemaVersion = Get-FrontmatterScalar -Content $content -Name 'schema_version'
      if ($schemaVersion -notin @('finance.v1', 'finance.v2')) {
        $script:failures.Add("核算 schema_version 错误：$relative")
      }
      if ($schemaVersion -eq 'finance.v2') {
        if ((Get-FrontmatterScalar -Content $content -Name 'input_mode') -ne 'quick_v3') {
          $script:failures.Add("finance.v2 核算 input_mode 不是 quick_v3：$relative")
        }
        foreach ($requiredName in @(
          'period_end_inclusive', 'period_month_factor',
          'monthly_fixed_cost_ex_owner', 'monthly_owner_wage',
          'period_fixed_cost_ex_owner', 'period_owner_wage'
        )) {
          if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
            $script:failures.Add("quick_v3 核算缺少 $requiredName：$relative")
          }
        }
        if ((Get-FrontmatterScalar -Content $content -Name 'period_end_inclusive') -ne 'true') {
          $script:failures.Add("quick_v3 核算 period_end_inclusive 不是 true：$relative")
        }
      }
      if ((Get-FrontmatterScalar -Content $content -Name 'privacy') -ne 'sensitive') {
        $script:failures.Add("核算 privacy 不是 sensitive：$relative")
      }
      foreach ($requiredName in @(
        'period_start', 'period_end', 'calculation_version', 'sustainable_profit',
        'cash_net_change', 'safety_value', 'safety_label', 'headline_code',
        'headline_status', 'created_at', 'updated_at'
      )) {
        if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
          $script:failures.Add("核算缺少 $requiredName：$relative")
        }
      }
      if ([string]::IsNullOrWhiteSpace($calculationId) -or $file.BaseName -ne $calculationId) {
        $script:failures.Add("核算文件名与 calculation_id 不一致：$relative")
      }
      if ([string]::IsNullOrWhiteSpace($inputHash) -or $inputHash -notmatch '^[a-f0-9]{16}$') {
        $script:failures.Add("核算 input_hash 格式错误：$relative")
      }
      if ((Get-FrontmatterScalar -Content $content -Name 'hash_algorithm') -ne 'fnv1a64') {
        $script:failures.Add("核算 hash_algorithm 不是 fnv1a64：$relative")
      }
      $payloadMatch = [regex]::Match($content, '(?s)<!-- finance-json:start -->\s*```json\s*(.*?)\s*```\s*<!-- finance-json:end -->')
      if (-not $payloadMatch.Success) {
        $script:failures.Add("核算缺少 finance-json 数据块：$relative")
      } else {
        try {
          $payload = $payloadMatch.Groups[1].Value | ConvertFrom-Json
          if (-not [string]::Equals([string]$payload.inputHash, $inputHash, [StringComparison]::OrdinalIgnoreCase)) {
            $script:failures.Add("核算数据块与 frontmatter 的 input_hash 不一致：$relative")
          }
          if ([string]$payload.calculationVersion -ne (Get-FrontmatterScalar -Content $content -Name 'calculation_version')) {
            $script:failures.Add("核算数据块与 frontmatter 的 calculation_version 不一致：$relative")
          }
        } catch {
          $script:failures.Add("核算 finance-json 无法解析：$relative")
        }
      }
    }
  }

  $planDirectory = Join-Path $VaultRoot '20_经营数据\经营核算\产品收费方案'
  if (-not (Test-Path -LiteralPath $planDirectory -PathType Container)) { return }
  foreach ($file in @(Get-ChildItem -LiteralPath $planDirectory -Force -File | Where-Object { $_.Name -ne 'README.md' })) {
    $relative = $file.FullName.Substring($VaultRoot.Length + 1)
    if ($file.Extension -ne '.md') {
      $script:failures.Add("产品收费方案目录含非 Markdown 记录：$relative")
      continue
    }
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $calculationId = Get-FrontmatterScalar -Content $content -Name 'calculation_id'
    $inputHash = Get-FrontmatterScalar -Content $content -Name 'input_hash'
    foreach ($expectation in @(
      [pscustomobject]@{ Name = 'record_type'; Value = 'finance_product_plan_set' },
      [pscustomobject]@{ Name = 'record_status'; Value = 'saved' },
      [pscustomobject]@{ Name = 'privacy'; Value = 'sensitive' },
      [pscustomobject]@{ Name = 'schema_version'; Value = 'finance.v1' }
    )) {
      if ((Get-FrontmatterScalar -Content $content -Name $expectation.Name) -ne $expectation.Value) {
        $script:failures.Add("产品收费方案 $($expectation.Name) 错误：$relative")
      }
    }
    foreach ($requiredName in @('record_id', 'created_at')) {
      if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
        $script:failures.Add("产品收费方案缺少 $requiredName：$relative")
      }
    }
    $referenceFailure = Get-FinanceCalculationReferenceFailure -VaultRoot $VaultRoot -CalculationId $calculationId -InputHash $inputHash
    if ($null -ne $referenceFailure) {
      $script:failures.Add("产品收费方案引用无效：$relative（$referenceFailure）")
    }
  }

  $insightDirectory = Join-Path $VaultRoot '20_经营数据\经营核算\AI结论'
  if (-not (Test-Path -LiteralPath $insightDirectory -PathType Container)) { return }
  foreach ($file in @(Get-ChildItem -LiteralPath $insightDirectory -Force -File | Where-Object { $_.Name -ne 'README.md' })) {
    $relative = $file.FullName.Substring($VaultRoot.Length + 1)
    if ($file.Extension -ne '.md') {
      $script:failures.Add("AI 结论目录含非 Markdown 记录：$relative")
      continue
    }
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    foreach ($expectation in @(
      [pscustomobject]@{ Name = 'record_type'; Value = 'finance_ai_insight' },
      [pscustomobject]@{ Name = 'record_status'; Value = 'active' },
      [pscustomobject]@{ Name = 'privacy'; Value = 'sensitive' },
      [pscustomobject]@{ Name = 'schema_version'; Value = 'finance.v1' }
    )) {
      if ((Get-FrontmatterScalar -Content $content -Name $expectation.Name) -ne $expectation.Value) {
        $script:failures.Add("AI 结论 $($expectation.Name) 错误：$relative")
      }
    }
    foreach ($requiredName in @('record_id', 'maximum_issue', 'unique_action', 'created_at', 'updated_at')) {
      if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
        $script:failures.Add("AI 结论缺少 $requiredName：$relative")
      }
    }
    $calculationId = Get-FrontmatterScalar -Content $content -Name 'calculation_id'
    $inputHash = Get-FrontmatterScalar -Content $content -Name 'input_hash'
    $referenceFailure = Get-FinanceCalculationReferenceFailure -VaultRoot $VaultRoot -CalculationId $calculationId -InputHash $inputHash
    if ($null -ne $referenceFailure) {
      $script:failures.Add("AI 结论引用无效：$relative（$referenceFailure）")
    }
  }
}

function Invoke-TargetRecordValidator {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][ValidateSet('target', 'action')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($null -eq $node) { return '缺少 Node.js，无法重新运行经营目标确定性公式' }
  $scriptPath = Join-Path $VaultRoot '.claude\skills\commercial-operations-expert\scripts\target-breakdown.js'
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { return '缺少 target-breakdown.js' }
  $arguments = if ($Kind -eq 'target') {
    @($scriptPath, '--validate-target-file', '--vault-root', $VaultRoot, '--target', $RelativePath)
  } else {
    @($scriptPath, '--validate-action-file', '--vault-root', $VaultRoot, '--action', $RelativePath)
  }
  try {
    $output = @(& $node.Source @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    $validation = $null
    try { $validation = $text | ConvertFrom-Json } catch { return "确定性校验未返回有效 JSON：$text" }
    if ($exitCode -ne 0 -or $validation.valid -ne $true) {
      $details = @($validation.errors | ForEach-Object { [string]$_ }) -join '；'
      if ([string]::IsNullOrWhiteSpace($details)) { $details = $text }
      return $details
    }
    return $null
  } catch {
    return ('确定性校验执行失败：' + $_.Exception.Message)
  }
}

function Test-TargetDataSchemas {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)

  $directories = @(
    [pscustomobject]@{ Relative = '20_经营数据\经营目标\目标方案'; Kind = 'target'; Type = 'business_target_plan'; Schema = 'business_target_plan.v1'; Id = 'target_plan_id'; Hash = 'target_input_hash'; Pattern = '^btp-[a-f0-9]{16}$'; Marker = 'business-target-plan-json' },
    [pscustomobject]@{ Relative = '20_经营数据\经营目标\行动计划'; Kind = 'action'; Type = 'operating_action_plan'; Schema = 'operating_action_plan.v1'; Id = 'action_plan_id'; Hash = 'breakdown_input_hash'; Pattern = '^oap-[a-f0-9]{16}$'; Marker = 'operating-action-plan-json' }
  )
  foreach ($entry in $directories) {
    $directory = Join-Path $VaultRoot $entry.Relative
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Force -File | Where-Object { $_.Name -ne 'README.md' })) {
      $relative = $file.FullName.Substring($VaultRoot.Length + 1).Replace('\', '/')
      if ($file.Extension -ne '.md') {
        $script:failures.Add("经营目标目录含非 Markdown 记录：$relative")
        continue
      }
      $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
      $recordId = Get-FrontmatterScalar -Content $content -Name $entry.Id
      $recordHash = Get-FrontmatterScalar -Content $content -Name $entry.Hash
      foreach ($expectation in @(
        [pscustomobject]@{ Name = 'record_type'; Value = $entry.Type },
        [pscustomobject]@{ Name = 'schema_version'; Value = $entry.Schema },
        [pscustomobject]@{ Name = 'hash_algorithm'; Value = 'fnv1a64' },
        [pscustomobject]@{ Name = 'privacy'; Value = 'sensitive' }
      )) {
        if ((Get-FrontmatterScalar -Content $content -Name $expectation.Name) -ne $expectation.Value) {
          $script:failures.Add("经营目标 $($expectation.Name) 错误：$relative")
        }
      }
      foreach ($requiredName in @('target_plan_id', 'target_input_hash', 'target_month', 'created_at', 'updated_at')) {
        if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
          $script:failures.Add("经营目标缺少 $requiredName：$relative")
        }
      }
      if ($entry.Kind -eq 'target') {
        foreach ($requiredName in @('calculation_id', 'source_input_hash')) {
          if ([string]::IsNullOrWhiteSpace((Get-FrontmatterScalar -Content $content -Name $requiredName))) {
            $script:failures.Add("目标方案缺少 $requiredName：$relative")
          }
        }
      } else {
        if ((Get-FrontmatterScalar -Content $content -Name 'record_status') -ne 'active') {
          $script:failures.Add("行动计划 record_status 不是 active：$relative")
        }
      }
      if ([string]::IsNullOrWhiteSpace($recordId) -or $recordId -notmatch $entry.Pattern -or $file.BaseName -ne $recordId) {
        $script:failures.Add("经营目标文件名或 $($entry.Id) 格式错误：$relative")
      }
      if ([string]::IsNullOrWhiteSpace($recordHash) -or $recordHash -notmatch '^[a-f0-9]{16}$') {
        $script:failures.Add("经营目标 $($entry.Hash) 格式错误：$relative")
      }
      $payloadPattern = '(?s)<!--\s*' + [regex]::Escape($entry.Marker) + ':start\s*-->\s*```json\s*(.*?)\s*```\s*<!--\s*' + [regex]::Escape($entry.Marker) + ':end\s*-->'
      $payloadMatch = [regex]::Match($content, $payloadPattern)
      if (-not $payloadMatch.Success) {
        $script:failures.Add("经营目标缺少 $($entry.Marker) 数据块：$relative")
      } else {
        try {
          $payload = $payloadMatch.Groups[1].Value | ConvertFrom-Json
          if ($null -eq $payload.input -or $null -eq $payload.result) {
            $script:failures.Add("经营目标数据块必须保存 input + 完整 result envelope：$relative")
          }
        } catch {
          $script:failures.Add("经营目标 JSON 无法解析：$relative")
        }
      }
      $validationFailure = Invoke-TargetRecordValidator -VaultRoot $VaultRoot -Kind $entry.Kind -RelativePath $relative
      if ($null -ne $validationFailure) {
        $script:failures.Add("经营目标确定性复算失败：$relative（$validationFailure）")
      }
    }
  }
}

function Get-DefaultBusinessStateText {
  return @'
---
record_type: business_state
current_path: auto
current_week: ""
global_operating_action: null
derived_from_weekly_review: null
updated_at: null
privacy: private
schema_version: "1.0"
---

# 经营状态

## 自动分流规则

- `当前项目` 中存在至少一份通过事实门且 `record_status: active` 的项目：进入“已有项目”路径。
- 不存在有效当前项目：进入“只有能力”路径，从能力商品化和验证开始。
- `current_path: auto` 表示始终按真实数据自动判断，不由 AI 凭印象选择。

## 当前状态

- 当前路径：由系统自动判断
- 本周：尚未建立
- 全局唯一经营动作：尚未确认

本页只保存跨项目的路径与本周全局状态，不复制项目六字段。它是独立周复盘的派生镜像，不是第二份事实源；不一致时以 `30_五维周复盘/历史周复盘` 中最新有效周文件为准。模板、README、归档状态项目和未通过事实门的记录不得影响路径判断。
'@
}

function Get-EmptyConfirmedWritebackLogText {
  return @'
---
record_type: confirmed_writeback_log
log_mode: append_only
privacy: sensitive
retrieval: excluded
schema_version: "1.1"
---

# 已确认写回记录

本页只登记用户已经明确确认、AI 已实际执行并复读核验的写回。未执行的建议不得登记为完成。

## 记录格式

每次在末尾追加一条，包含：

- 时间：ISO 8601，含时区
- 授权来源：用户直接指令或原生确认
- 用户授权语义：只记录简短动作语义，不复制整段敏感对话
- 目标文件：完整相对路径
- 修改摘要：字段名和修改类型，不重复敏感正文
- 核验结果：成功、部分成功或失败；部分成功与失败必须写明未完成项

---

暂无已确认写回。
'@
}

function Get-EmptyWritebackPreviewText {
  return @'
---
record_type: writeback_preview
preview_status: empty
created_at: null
privacy: sensitive
retrieval: excluded
schema_version: "1.2"
---

# 写回预览

本页只保留 AI 主动提出修改时的简短预览格式。用户已经直接要求“保存、写入、更新、记录、填进去”等动作时，该指令本身就是本轮库内白名单授权，AI 通过路径、schema 与来源校验后直接执行，不重复展示本页，也不再索要口令。创业算账页的“确认保存”仍是计算器自己的页内授权，不授权 AI 创建正式核算记录或目标方案。

用户授权不够明确时，AI 只展示一次以下自然语言摘要，并由原生确认窗口完成最终确认：

**【修改预览】**

## 目标文件

列出每个完整相对路径，并说明是新建还是编辑。

## 字段变化

| 字段或段落 | 原值 | 拟写值 | 信息层级 |
| --- | --- | --- | --- |

信息层级只能是：用户事实、外部证据、待验证假设、AI 建议。

## 校验结果

- 真实项目事实门：
- 报价事实门：
- 回款事实门：
- 金额格式、明确应收与未知项（不得用报价减回款推导应收）：
- 若为核算 AI 结论：来源路径、`calculation_id + input_hash` 匹配，且公式记录未被修改：
- 若为经营行动计划：来源目标、`target_plan_id + target_input_hash + breakdown_input_hash` 匹配，且全部数字已复算：
- 唯一下一步或唯一经营动作：
- 白名单与禁止区检查：

## 关键变化

只展示用户需要核对的字段、前后值、事实层级、是否出库和是否可恢复，不铺开整份 Markdown，也不显示内部脚本或权限术语。

## 需要的确认

**【等待原生确认】**

单独“好/行/知道了”等模糊表达不直接授权，由原生窗口询问一次。问句、否定或暂停不执行；附带修改条件时先更新拟写内容，再发起一次原生确认。

执行后必须重新读取目标文件并输出“【已写入看板】”。只有复读到的新值才算已经进入首页所读数据；不得修改首页代码来模拟成功。
'@
}

function Test-HasNonEmptySessionMetadata {
  param([AllowNull()]$Node)

  if ($null -eq $Node) { return $false }
  if ($Node -is [Array] -or $Node -is [Collections.IList]) {
    foreach ($entry in $Node) {
      if (Test-HasNonEmptySessionMetadata -Node $entry) { return $true }
    }
    return $false
  }
  if ($Node -isnot [pscustomobject]) { return $false }

  foreach ($property in @($Node.PSObject.Properties)) {
    $normalized = ($property.Name -replace '[-_]', '').ToLowerInvariant()
    if ($normalized -match '^(?:opentabs|activetabid|tabid|conversationid|sessionid|currentconversationid|activeconversationid)$') {
      $value = $property.Value
      if ($null -eq $value) { continue }
      if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { continue }
      if (($value -is [Array] -or $value -is [Collections.IList]) -and @($value).Count -eq 0) { continue }
      $objectProperties = if ($value -is [pscustomobject]) { @($value.PSObject.Properties).Count } else { -1 }
      if ($objectProperties -eq 0) { continue }
      return $true
    }
    if (Test-HasNonEmptySessionMetadata -Node $property.Value) { return $true }
  }
  return $false
}

$vaults = @(Get-ChildItem -LiteralPath $package -Directory | Where-Object {
  Test-Path -LiteralPath (Join-Path $_.FullName '.obsidian')
})
if ($vaults.Count -ne 1) {
  $failures.Add("经营空间数量应为 1，实际为 $($vaults.Count)。")
  $vaultRoot = $null
} else {
  $vaultRoot = $vaults[0].FullName
}

if ($vaultRoot) {
  $required = @(
    '00_开始这里\首页.md',
    '00_开始这里\创业算账.md',
    '10_商业运营专家内核\AI接手索引.md',
    '20_经营数据\模板_项目记录.md',
    '20_经营数据\经营核算\README.md',
    '20_经营数据\经营核算\产品收费方案\README.md',
    '20_经营数据\经营核算\实际核算\README.md',
    '20_经营数据\经营核算\创业预估\README.md',
    '20_经营数据\经营核算\AI结论\README.md',
    '20_经营数据\经营目标\目标方案\README.md',
    '20_经营数据\经营目标\行动计划\README.md',
    '30_五维周复盘\模板_五维周复盘.md',
    '40_能力商品化\能力商品化起点.md',
    '40_能力商品化\能力卡受控导入说明.md',
    '60_AI商业运营专家\核算草稿\README.md',
    '60_AI商业运营专家\对话归档\README.md',
    '40_能力商品化\模板_验证记录.md',
    '40_能力商品化\模板_市场反馈导出.md',
    '40_能力商品化\验证记录\README.md',
    '40_能力商品化\市场反馈导出\README.md',
    '60_AI商业运营专家\AI使用说明.md',
    'CLAUDE.md',
    'AGENTS.md',
    '.claude\settings.json',
    '.claude\hooks\guard-write.ps1',
    '.claude\hooks\test-guard-write.js',
    '.claude\skills\commercial-operations-expert\SKILL.md',
    '.claude\skills\commercial-operations-expert\scripts\operation-preview.js',
    '.claude\skills\commercial-operations-expert\scripts\finance-entry.js',
    '.claude\skills\commercial-operations-expert\scripts\session-export.js',
    '.claude\skills\commercial-operations-expert\scripts\safe-recycle.ps1',
    '.claude\skills\commercial-operations-expert\scripts\target-breakdown.js',
    '.claude\commands\finance-entry.md',
    '.claude\commands\session-export.md',
    '.claude\commands\target-breakdown.md',
    '10_商业运营专家内核\经营目标倒推协议.md',
    '.obsidian\snippets\business-cockpit.css',
    '.obsidian\plugins\dataview\main.js',
    '.obsidian\plugins\homepage\main.js',
    '.obsidian\plugins\realclaudian\main.js',
    '90_系统设置_不用先看\创业算账引擎.js'
  )
  foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $vaultRoot $relative))) {
      $failures.Add("缺少：$relative")
    }
  }

  Get-ChildItem -LiteralPath $vaultRoot -Recurse -File -Filter '*.json' | ForEach-Object {
    try { Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8 | ConvertFrom-Json | Out-Null }
    catch { $failures.Add("JSON 无法解析：$($_.FullName.Substring($vaultRoot.Length + 1))") }
  }

  $homePath = Join-Path $vaultRoot '00_开始这里\首页.md'
  if (Test-Path -LiteralPath $homePath) {
    $homeContent = Get-Content -LiteralPath $homePath -Raw -Encoding utf8
    foreach ($token in @('fm.record_type !== "project"', 'fm.record_type === "weekly_review"', 'fm.record_type !== "monetization_validation"', 'fact_gate_confirmed', 'data-ai-command', 'app.vault.on("modify"', 'setPinned(true)')) {
      if (-not $homeContent.Contains($token)) { $failures.Add("首页 schema 缺少：$token") }
    }
    if ($homeContent -match '<\s*(form|input|textarea|select)\b') {
      $failures.Add('首页仍包含用户录入表单；AI 主导看板必须保持只读。')
    }
    if ($homeContent -match 'app\.vault\.(create|modify|delete)\s*\(' -or $homeContent -match 'adapter\.(write|append)\s*\(') {
      $failures.Add('首页仍包含经营数据写入 API；写回必须只由受控 AI 流程执行。')
    }
    if ($homeContent -match 'Number\([^\)]*回款[^\)]*\?\?\s*0') {
      $failures.Add('首页疑似把未知回款当作 0 计算。')
    }
  }

  $calculatorPath = Join-Path $vaultRoot '00_开始这里\创业算账.md'
  if (Test-Path -LiteralPath $calculatorPath) {
    $calculatorContent = Get-Content -LiteralPath $calculatorPath -Raw -Encoding utf8
    foreach ($token in @(
      '90_系统设置_不用先看/创业算账引擎.js',
      '20_经营数据/经营核算/实际核算',
      '20_经营数据/经营核算/创业预估',
      '20_经营数据/经营核算/产品收费方案',
      '20_经营数据/经营核算/AI结论',
      'data-confirm-save', 'finance-json:start', 'calculation_id', 'input_hash',
      'app.vault.create(', 'localStorage', 'inputMode: "quick_v3"', 'quick_v2',
      'period_end_inclusive: true', 'period_month_factor:', 'calculation_draft',
      'CORE_FIELDS', 'metricReadiness', '真实核账', '创业预估',
      'finiteValue'
    )) {
      if (-not $calculatorContent.Contains($token)) { $failures.Add("创业算账界面缺少：$token") }
    }
    if ($calculatorContent -match 'app\.vault\.(?:delete|rename)\s*\(') {
      $failures.Add('创业算账界面不得删除或重命名 vault 文件。')
    }
    if ($calculatorContent -match 'adapter\.(?:write|append|remove|rename)\s*\(') {
      $failures.Add('创业算账界面不得绕过 Vault API 直接写入 adapter。')
    }
  }

  $financeEnginePath = Join-Path $vaultRoot '90_系统设置_不用先看\创业算账引擎.js'
  if (Test-Path -LiteralPath $financeEnginePath) {
    $financeEngineContent = Get-Content -LiteralPath $financeEnginePath -Raw -Encoding utf8
    foreach ($token in @(
      'const VERSION', 'const HASH_ALGORITHM', 'function calculate', 'function hashInput',
      'quick_v2', 'quick_v3', 'QUICK_V3_SCHEMA_VERSION', 'function cleanQuickState',
      'function cleanQuickV3State', 'function getPeriodProfile', 'classifyLegacyQuickPeriod',
      'metricReadiness', 'breakEvenRevenue', 'monthlyBreakEvenRevenue',
      'capacityRate', 'module.exports'
    )) {
      if (-not $financeEngineContent.Contains($token)) { $failures.Add("创业算账引擎缺少：$token") }
    }
    if ($financeEngineContent -match 'app\.vault|adapter\.(?:write|append|remove|rename)\s*\(|\bfetch\s*\(|XMLHttpRequest|WebSocket') {
      $failures.Add('创业算账引擎必须保持纯函数：不得联网或读写 vault。')
    }
    foreach ($token in @(
      'calculateBusinessTargetPlan', 'validateBusinessTargetPlan',
      'validateBusinessTargetPlanRecord', 'calculateOperatingBreakdown',
      'validateOperatingActionPlanRecord', 'business_target_plan.v1', 'operating_action_plan.v1'
    )) {
      if (-not $financeEngineContent.Contains($token)) { $failures.Add("经营目标确定性引擎缺少：$token") }
    }
  }

  $targetCliPath = Join-Path $vaultRoot '.claude\skills\commercial-operations-expert\scripts\target-breakdown.js'
  if (Test-Path -LiteralPath $targetCliPath) {
    $targetCliContent = Get-Content -LiteralPath $targetCliPath -Raw -Encoding utf8
    foreach ($token in @(
      'calculateOperatingBreakdown', 'validateBusinessTargetPlanRecord',
      'validateOperatingActionPlanRecord', 'safeInputFromArguments',
      '"actual-cash"', '"remaining-days"', '--input-base64', 'validate-action-stdin'
    )) {
      if (-not $targetCliContent.Contains($token)) { $failures.Add("目标拆解只读脚本缺少：$token") }
    }
    if ($targetCliContent -match '\b(?:writeFile|appendFile|unlink|rmSync|rename|mkdir|createWriteStream)\s*\(' -or $targetCliContent -match '\b(?:fetch|XMLHttpRequest|WebSocket)\b') {
      $failures.Add('目标拆解脚本必须保持只读：不得写文件、删除、重命名、建目录或联网。')
    }
  }

  Test-FinanceDataSchemas -VaultRoot $vaultRoot
  Test-TargetDataSchemas -VaultRoot $vaultRoot

  $homepageConfigPath = Join-Path $vaultRoot '.obsidian\plugins\homepage\data.json'
  if (Test-Path -LiteralPath $homepageConfigPath) {
    $homepageConfig = Get-Content -LiteralPath $homepageConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    $mainHomepage = $homepageConfig.homepages.'Main Homepage'
    if ($null -eq $mainHomepage -or $mainHomepage.value -ne '00_开始这里/首页' -or $mainHomepage.openOnStartup -ne $true -or $mainHomepage.pin -ne $true) {
      $failures.Add('Homepage 插件未按真实 Main Homepage schema 固定首页。')
    }
  }

  $workspacePath = Join-Path $vaultRoot '.obsidian\workspace.json'
  if (Test-Path -LiteralPath $workspacePath) {
    $workspaceState = Get-Content -LiteralPath $workspacePath -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not (Test-PinnedHomeLeaf $workspaceState.main)) {
      $failures.Add('Obsidian 工作区没有固定的首页叶子。')
    }
    if ($ReleaseMode) {
      $lastOpenFiles = @($workspaceState.lastOpenFiles)
      if ($lastOpenFiles.Count -ne 1 -or $lastOpenFiles[0] -ne '00_开始这里/首页.md') {
        $failures.Add('发布包 Obsidian 最近打开记录不是仅保留首页的空白状态。')
      }
      $mainMarkdownFiles = @($workspaceState.main.children | ForEach-Object {
        $_.children
      } | Where-Object {
        $_.type -eq 'leaf' -and $_.state.type -eq 'markdown'
      } | ForEach-Object {
        [string]$_.state.state.file
      })
      if ($mainMarkdownFiles.Count -ne 1 -or $mainMarkdownFiles[0] -ne '00_开始这里/首页.md') {
        $failures.Add('发布包 Obsidian 主区不是仅打开固定首页的空白状态。')
      }
      $workspaceText = $workspaceState | ConvertTo-Json -Depth 100
      if ($workspaceText -match '(?i)(?:20_经营数据/(?:当前项目|归档项目|经营核算|经营目标)|30_五维周复盘/历史周复盘|40_能力商品化/(?:验证记录|市场反馈导出))/(?!README\.md)') {
        $failures.Add('发布包 Obsidian 工作区仍引用用户经营记录路径。')
      }
    }
  }

  $guardPath = Join-Path $vaultRoot '.claude\hooks\guard-write.ps1'
  if (Test-Path -LiteralPath $guardPath) {
    $guardContent = Get-Content -LiteralPath $guardPath -Raw -Encoding utf8
    foreach ($token in @(
      'user_confirmation_required', 'path_protected', 'schema_invalid', 'stale_reference', 'permanent_risk',
      'permissionDecision', "Write-Decision 'ask'", 'README.md',
      '20_经营数据/经营核算/AI结论', 'finance_ai_insight',
      'Get-FinanceInsightReferenceFailure', 'finance-entry\.js',
      'session-export\.js', 'safe-recycle\.ps1', 'WebFetch', 'WebSearch'
    )) {
      if (-not $guardContent.Contains($token)) { $failures.Add("写入守卫缺少：$token") }
    }
    foreach ($token in @(
      'Test-AllowedTargetBreakdownCommand', '20_经营数据/经营目标/行动计划',
      'Business target plans are deterministic and AI-read-only',
      'Get-OperatingActionValidationFailure', 'operating_action_plan',
      '--actual-cash', '--remaining-days', 'historical|user_estimate|mixed'
    )) {
      if (-not $guardContent.Contains($token)) { $failures.Add("经营目标写入守卫缺少：$token") }
    }
  }

  $claudianSettingsPath = Join-Path $vaultRoot '.claudian\claudian-settings.json'
  if (Test-Path -LiteralPath $claudianSettingsPath) {
    $claudianSettings = Get-Content -LiteralPath $claudianSettingsPath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($claudianSettings.permissionMode -ne 'normal') { $failures.Add('Claudian permissionMode 不是 normal。') }
    if ($claudianSettings.providerConfigs.claude.safeMode -ne 'acceptEdits') { $failures.Add('Claudian Claude safeMode 不是 acceptEdits。') }
    if (-not [string]::IsNullOrWhiteSpace([string]$claudianSettings.providerConfigs.claude.cliPath)) { $failures.Add('Claudian cliPath 不应写入不可迁移路径。') }
    if ($ReleaseMode) {
      if ($claudianSettings.savedProviderPermissionMode.claude -ne 'normal') { $failures.Add('发布包 Claudian savedProviderPermissionMode.claude 不是 normal。') }
      if ($claudianSettings.providerConfigs.claude.enableChrome -ne $false) { $failures.Add('发布包 Claudian 浏览器控制没有关闭。') }
      if ($claudianSettings.providerConfigs.claude.enableBangBash -ne $false) { $failures.Add('发布包 Claudian Bang Bash 没有关闭。') }
      if (@($claudianSettings.persistentExternalContextPaths).Count -ne 0) { $failures.Add('发布包 Claudian 仍保留外部上下文目录。') }
      if (-not [string]::IsNullOrWhiteSpace([string]$claudianSettings.userName)) { $failures.Add('发布包 Claudian 仍保留本机用户名。') }
    }
  }

  if ($ReleaseMode) {
    $releaseRecordDirectories = @(
      '20_经营数据\当前项目',
      '20_经营数据\归档项目',
      '20_经营数据\经营核算\产品收费方案',
      '20_经营数据\经营核算\实际核算',
      '20_经营数据\经营核算\创业预估',
      '20_经营数据\经营核算\AI结论',
      '20_经营数据\经营目标\目标方案',
      '20_经营数据\经营目标\行动计划',
      '30_五维周复盘\历史周复盘',
      '40_能力商品化\验证记录',
      '40_能力商品化\市场反馈导出',
      '60_AI商业运营专家\核算草稿',
      '60_AI商业运营专家\对话归档'
    )
    foreach ($relativeDirectory in $releaseRecordDirectories) {
      $directory = Join-Path $vaultRoot $relativeDirectory
      $readme = Join-Path $directory 'README.md'
      if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        $failures.Add("发布包数据目录缺少 README：$relativeDirectory")
        continue
      }
      $unexpectedItems = @(Get-ChildItem -LiteralPath $directory -Force -Recurse | Where-Object {
        -not $_.FullName.Equals($readme, [StringComparison]::OrdinalIgnoreCase)
      })
      if ($unexpectedItems.Count -gt 0) {
        $failures.Add("发布包残留用户经营记录：$relativeDirectory")
      }
    }

    foreach ($privateRuntimeDirectory in @(
      (Join-Path $vaultRoot '.trash'),
      (Join-Path $vaultRoot '.claude\runtime'),
      (Join-Path $package '备份')
    )) {
      if (Test-Path -LiteralPath $privateRuntimeDirectory) {
        $privateItems = @(Get-ChildItem -LiteralPath $privateRuntimeDirectory -Force -Recurse)
        if ($privateItems.Count -gt 0) {
          $failures.Add("发布包残留回收站、写回恢复记录、操作审计或经营备份：$($privateRuntimeDirectory.Substring($package.Length + 1))")
        }
      }
    }

    $businessStatePath = Join-Path $vaultRoot '20_经营数据\经营状态.md'
    if (
      -not (Test-Path -LiteralPath $businessStatePath -PathType Leaf) -or
      (Normalize-ReleaseText (Get-Content -LiteralPath $businessStatePath -Raw -Encoding utf8)) -ne (Normalize-ReleaseText (Get-DefaultBusinessStateText))
    ) {
      $failures.Add('发布包经营状态不是全新默认状态。')
    }

    $confirmedLogPath = Join-Path $vaultRoot '60_AI商业运营专家\已确认写回记录.md'
    if (
      -not (Test-Path -LiteralPath $confirmedLogPath -PathType Leaf) -or
      (Normalize-ReleaseText (Get-Content -LiteralPath $confirmedLogPath -Raw -Encoding utf8)) -ne (Normalize-ReleaseText (Get-EmptyConfirmedWritebackLogText))
    ) {
      $failures.Add('发布包已确认写回日志不是全新空白。')
    }

    $previewPath = Join-Path $vaultRoot '60_AI商业运营专家\写回预览.md'
    if (
      -not (Test-Path -LiteralPath $previewPath -PathType Leaf) -or
      (Normalize-ReleaseText (Get-Content -LiteralPath $previewPath -Raw -Encoding utf8)) -ne (Normalize-ReleaseText (Get-EmptyWritebackPreviewText))
    ) {
      $failures.Add('发布包写回预览不是全新空白模板。')
    }

    $claudianRoot = Join-Path $vaultRoot '.claudian'
    $claudianRuntimeFiles = @(Get-ChildItem -LiteralPath $claudianRoot -Force -Recurse -File | Where-Object {
      -not $_.FullName.Equals((Join-Path $claudianRoot 'claudian-settings.json'), [StringComparison]::OrdinalIgnoreCase)
    })
    if ($claudianRuntimeFiles.Count -gt 0) {
      $failures.Add('发布包仍包含 Claudian 会话或运行文件。')
    }

    $realClaudianDataPath = Join-Path $vaultRoot '.obsidian\plugins\realclaudian\data.json'
    if (-not (Test-Path -LiteralPath $realClaudianDataPath -PathType Leaf)) {
      $failures.Add('发布包缺少 RealClaudian data.json。')
    } else {
      try {
        $realClaudianData = Get-Content -LiteralPath $realClaudianDataPath -Raw -Encoding utf8 | ConvertFrom-Json
        $openTabs = @($realClaudianData.tabManagerState.openTabs)
        $activeTabId = [string]$realClaudianData.tabManagerState.activeTabId
        if ($openTabs.Count -ne 0 -or -not [string]::IsNullOrWhiteSpace($activeTabId) -or (Test-HasNonEmptySessionMetadata -Node $realClaudianData)) {
          $failures.Add('发布包 RealClaudian 会话标签元数据不是空白状态。')
        }
      } catch {
        $failures.Add('发布包 RealClaudian data.json 无法解析或校验。')
      }
    }
  }
}

Get-ChildItem -LiteralPath $package -Recurse -File -Filter '*.ps1' | ForEach-Object {
  $relative = $_.FullName.Substring($package.Length + 1)
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
  if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0 -and -not $hasBom) {
    $failures.Add("含非 ASCII 字符的 PowerShell 缺少 UTF-8 BOM：$relative")
  }
  try { [scriptblock]::Create((Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8)) | Out-Null }
  catch { $failures.Add("PowerShell 无法解析：$relative") }
}

Get-ChildItem -LiteralPath $package -Recurse -File -Filter '*.cmd' | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) {
    $failures.Add("批处理不是纯 ASCII：$($_.FullName.Substring($package.Length + 1))")
  }
}

$allPackageFiles = @(Get-ChildItem -LiteralPath $package -Recurse -Force -File)
if ($ReleaseMode) {
  foreach ($file in @($allPackageFiles | Where-Object {
    $_.Name -match '^(?:\.env(?:\..*)?|credentials?(?:\..*)?|secrets?(?:\..*)?|id_(?:rsa|ed25519)(?:\..*)?)$' -or
    $_.Extension -in @('.pem', '.key', '.pfx', '.p12')
  })) {
    $failures.Add("发布包含敏感凭证文件：$($file.FullName.Substring($package.Length + 1))")
  }
}

$textFiles = $allPackageFiles | Where-Object {
  $_.Extension -in @('.md', '.txt', '.json', '.jsonl', '.yaml', '.yml', '.toml', '.env', '.ini', '.cfg', '.conf', '.cmd', '.ps1', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.html', '.log', '.csv') -and
  $_.FullName -notmatch '\\.obsidian\\plugins\\[^\\]+\\main\.js$'
}
$secretPattern = '(?i)sk-[A-Za-z0-9_-]{12,}|ANTHROPIC_(?:AUTH_TOKEN|API_KEY)=(?!PASTE_)|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bBearer\s+[A-Za-z0-9._~+/=-]{16,}|(?m)^\s*(?:api[_-]?key|auth[_-]?token|access[_-]?token|secret[_-]?key)\s*[:=]\s*["'']?(?!PASTE_|YOUR_|<|\$\{)[A-Za-z0-9._~+/=-]{12,}'
foreach ($file in $textFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
  if ($content -match $secretPattern) {
    if ($ReleaseMode) {
      $failures.Add("发布包疑似包含明文密钥：$($file.Name)")
    } else {
      $warnings.Add("本机运行副本已配置模型凭证：不要分享当前文件夹；发布前必须使用脱敏净包。")
    }
  }
  if ($content -match "`0") { $failures.Add("包含 NUL：$($file.Name)") }
  if ($file.FullName -match '\\LICENSES\\.*\.(txt|md)$' -and $content -match '(?m)^\+Permission is hereby granted') {
    $failures.Add("许可证残留补丁符号：$($file.Name)")
  }
}

if ($ReleaseMode) {
  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  if ($null -eq $nodeCommand) {
    $failures.Add('发布校验缺少 Node.js，无法运行公式、草稿、权限与脚本回归测试。')
  } else {
    function Invoke-ReleaseNodeTest {
      param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @(),
        [switch]$SyntaxOnly
      )

      if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        $script:failures.Add("发布回归缺少：$Label")
        return
      }
      $nodeArguments = @(if ($SyntaxOnly) { '--check'; $ScriptPath } else { $ScriptPath; @($Arguments) })
      $previousErrorAction = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
        $captured = @(& $nodeCommand.Source @nodeArguments 2>&1)
      } finally {
        $ErrorActionPreference = $previousErrorAction
      }
      if ($LASTEXITCODE -ne 0) {
        $tail = (@($captured | Select-Object -Last 3) -join ' | ').Trim()
        $script:failures.Add("发布回归失败：$Label" + $(if ($tail) { "（$tail）" } else { '' }))
      }
    }

    $expertScripts = Join-Path $vaultRoot '.claude\skills\commercial-operations-expert\scripts'
    Invoke-ReleaseNodeTest -Label '64 项创业算账与目标公式' -ScriptPath (Join-Path $package '_tools\test-finance-engine.js')
    Invoke-ReleaseNodeTest -Label '首页目标来源 fixture' -ScriptPath (Join-Path $package '_tools\test-home-target-selection.js')
    Invoke-ReleaseNodeTest -Label '旧版操作预览兼容自测' -ScriptPath (Join-Path $expertScripts 'operation-preview.js') -Arguments @('--self-test')
    Invoke-ReleaseNodeTest -Label '核算代填草稿自测' -ScriptPath (Join-Path $expertScripts 'finance-entry.js') -Arguments @('--self-test')
    Invoke-ReleaseNodeTest -Label '真实会话导出自测' -ScriptPath (Join-Path $expertScripts 'session-export.js') -Arguments @('--self-test')
    Invoke-ReleaseNodeTest -Label 'AI 分级授权与低摩擦写回场景' -ScriptPath (Join-Path $vaultRoot '.claude\hooks\test-guard-write.js')
    Invoke-ReleaseNodeTest -Label '目标拆解脚本语法' -ScriptPath (Join-Path $expertScripts 'target-breakdown.js') -SyntaxOnly
  }
}

if ($failures.Count -gt 0) {
  Write-Host '驾驶舱自检未通过：' -ForegroundColor Red
  $failures | Select-Object -Unique | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
  exit 1
}

if ($warnings.Count -gt 0) {
  Write-Host '驾驶舱自检提醒：' -ForegroundColor Yellow
  $warnings | Select-Object -Unique | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
}

Write-Host '驾驶舱自检通过。' -ForegroundColor Green
Write-Host "Package：$package"
Write-Host "Vault：$vaultRoot"
if ($ReleaseMode) {
  Write-Host '发布模式：结构、schema、JSON、脚本、批处理编码、密钥与 NUL 检查均通过。'
} else {
  Write-Host '本机模式：结构、schema、JSON、脚本、批处理编码与 NUL 检查均通过。'
}
exit 0
