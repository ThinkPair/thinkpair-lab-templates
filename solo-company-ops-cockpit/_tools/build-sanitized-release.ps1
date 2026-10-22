param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot,

  [Parameter(Mandatory = $true)]
  [string]$OutputZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$credentialPlaceholder = 'PASTE_YOUR_DEEPSEEK_API_KEY_HERE'
$credentialNames = @('ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY')
$runRoot = $null
$workspaceRoot = $null
$stagingPackage = $null
$zipTemporary = $null
$credentialReplacementCount = 0
$stateFieldClearCount = 0
$runtimeFileRemovalCount = 0
$userDataRemovalCount = 0
$releaseStateResetCount = 0
$realClaudianStateResetCount = 0
$obsidianWorkspaceResetCount = 0
$manifestFileCount = 0
$zipEntryCount = 0

function Get-AbsolutePath {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ([IO.Path]::IsPathRooted($Path)) {
    return [IO.Path]::GetFullPath($Path)
  }
  return [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Test-PathInside {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$Parent
  )

  $candidateFull = [IO.Path]::GetFullPath($Candidate).TrimEnd('\', '/')
  $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
  if ($candidateFull.Equals($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
    return $true
  }
  return $candidateFull.StartsWith($parentFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Find-WorkspaceRoot {
  param([Parameter(Mandatory = $true)][string[]]$Starts)

  foreach ($start in $Starts) {
    if ([string]::IsNullOrWhiteSpace($start) -or -not (Test-Path -LiteralPath $start)) {
      continue
    }
    $item = Get-Item -LiteralPath $start -Force
    $directory = if ($item.PSIsContainer) { $item } else { $item.Directory }
    while ($null -ne $directory) {
      if (
        (Test-Path -LiteralPath (Join-Path $directory.FullName 'AI_STATE.md')) -and
        (Test-Path -LiteralPath (Join-Path $directory.FullName '70_Governance'))
      ) {
        return $directory.FullName
      }
      $directory = $directory.Parent
    }
  }
  throw '未找到知识库工作区根目录；净包 staging 必须位于工作区 .codex_tmp。'
}

function Get-RelativePathSafe {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$TargetPath
  )

  $baseUri = New-Object Uri(([IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'))
  $targetUri = New-Object Uri([IO.Path]::GetFullPath($TargetPath))
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Copy-TreeIncludingHiddenAndEmpty {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $items = @(Get-ChildItem -LiteralPath $Source -Force -Recurse)
  $reparsePoints = @($items | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })
  if ($reparsePoints.Count -gt 0) {
    throw '源包包含重解析点；为防止复制越界，已停止构建。'
  }

  foreach ($directory in @($items | Where-Object { $_.PSIsContainer } | Sort-Object FullName)) {
    $relative = Get-RelativePathSafe -BasePath $Source -TargetPath $directory.FullName
    New-Item -ItemType Directory -Path (Join-Path $Destination $relative) -Force | Out-Null
  }
  foreach ($file in @($items | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName)) {
    $relative = Get-RelativePathSafe -BasePath $Source -TargetPath $file.FullName
    $destinationFile = Join-Path $Destination $relative
    $destinationDirectory = Split-Path -Parent $destinationFile
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -Force
  }
}

function Sanitize-EnvironmentText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) {
    return $null
  }
  $result = $Text
  foreach ($credentialName in $credentialNames) {
    $pattern = '(?im)^[\t ]*(?:export[\t ]+)?' + [regex]::Escape($credentialName) + '[\t ]*=.*$'
    $matches = [regex]::Matches($result, $pattern)
    if ($matches.Count -gt 0) {
      $script:credentialReplacementCount += $matches.Count
      $result = [regex]::Replace($result, $pattern, "$credentialName=$credentialPlaceholder")
    }
  }
  return $result
}

function Test-IsRuntimeStateField {
  param([Parameter(Mandatory = $true)][string]$Name)

  $normalized = ($Name -replace '[-_]', '').ToLowerInvariant()
  $exactNames = @(
    'device', 'deviceid', 'deviceids', 'devicesettingskey', 'cacheddevicesettingskey',
    'host', 'hostid', 'hostids', 'hostname', 'hostnames', 'hostpath', 'hostpaths',
    'hostnamepath', 'hostnamepaths', 'hostvaultpath', 'cachedhostname',
    'configuredhostnamepath', 'lasthostnamepath',
    'session', 'sessions', 'sessionid', 'sessionids', 'currentsessionid',
    'activesessionid', 'lastsessionid', 'loadedsessionid', 'sourcesessionid',
    'sessionhistory', 'recentsessions', 'persistedsession', 'activesession',
    'currentsession', 'lastsession', 'loadedsession', 'sourcesession',
    'conversation', 'conversations', 'conversationid', 'conversationids',
    'activeconversationid', 'lastconversationid', 'conversationhistory',
    'activeconversation', 'currentconversation', 'lastconversation',
    'hostauthtoken', 'hostauth', 'hoststate', 'hostmetadata'
  )
  if ($exactNames -contains $normalized) {
    return $true
  }
  if ($normalized.EndsWith('byhost')) {
    return $true
  }
  if ($normalized -match '^(?:cached|configured|last)?hostname\d*(?:path|paths)?$') {
    return $true
  }
  if ($normalized -match '^(?:current|active|last|loaded|source)?(?:session|conversation)(?:id|ids|history|state|metadata)$') {
    return $true
  }
  if ($normalized -match '^(?:cached)?device(?:id|ids|key|state|metadata)$') {
    return $true
  }
  return $false
}

function Get-ClearedValue {
  param([AllowNull()]$Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [string]) { return '' }
  if ($Value -is [Array] -or $Value -is [Collections.IList]) { return ,@() }
  if ($Value -is [Collections.IDictionary] -or $Value -is [pscustomobject]) { return [pscustomobject]@{} }
  if ($Value -is [bool]) { return $false }
  if ($Value -is [ValueType]) { return 0 }
  return $null
}

function Sanitize-JsonNode {
  param([AllowNull()]$Node)

  if ($null -eq $Node) { return }
  if ($Node -is [Array] -or $Node -is [Collections.IList]) {
    foreach ($entry in $Node) { Sanitize-JsonNode -Node $entry }
    return
  }
  if ($Node -isnot [pscustomobject]) { return }

  foreach ($property in @($Node.PSObject.Properties)) {
    $name = $property.Name
    if ($credentialNames -contains $name.ToUpperInvariant()) {
      if ([string]$property.Value -ne $credentialPlaceholder) {
        $script:credentialReplacementCount++
      }
      $property.Value = $credentialPlaceholder
      continue
    }
    if ($name.Equals('permissionMode', [StringComparison]::OrdinalIgnoreCase)) {
      $property.Value = 'normal'
      continue
    }
    if (Test-IsRuntimeStateField -Name $name) {
      $property.Value = Get-ClearedValue -Value $property.Value
      $script:stateFieldClearCount++
      continue
    }
    if ($property.Value -is [string]) {
      $property.Value = Sanitize-EnvironmentText -Text ([string]$property.Value)
      continue
    }
    Sanitize-JsonNode -Node $property.Value
  }
}

function Get-OrAddObjectProperty {
  param(
    [Parameter(Mandatory = $true)][pscustomobject]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property -or $null -eq $property.Value -or $property.Value -isnot [pscustomobject]) {
    if ($null -eq $property) {
      $Object | Add-Member -MemberType NoteProperty -Name $Name -Value ([pscustomobject]@{})
    } else {
      $property.Value = [pscustomobject]@{}
    }
  }
  return $Object.PSObject.Properties[$Name].Value
}

function Set-JsonProperty {
  param(
    [Parameter(Mandatory = $true)][pscustomobject]$Object,
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()]$Value
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
  } else {
    $property.Value = $Value
  }
}

function Set-CanonicalCredentialPlaceholders {
  param([Parameter(Mandatory = $true)][pscustomobject]$Settings)

  $providerConfigs = Get-OrAddObjectProperty -Object $Settings -Name 'providerConfigs'
  $claude = Get-OrAddObjectProperty -Object $providerConfigs -Name 'claude'
  $environmentProperty = $claude.PSObject.Properties['environmentVariables']
  $environmentText = if ($null -eq $environmentProperty) { '' } else { [string]$environmentProperty.Value }
  $lines = @()
  if (-not [string]::IsNullOrEmpty($environmentText)) {
    $lines = @($environmentText -split '\r?\n')
  }

  $keptLines = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    $isCredentialLine = $false
    foreach ($credentialName in $credentialNames) {
      if ($line -match ('^[\t ]*(?:export[\t ]+)?' + [regex]::Escape($credentialName) + '[\t ]*=')) {
        $isCredentialLine = $true
        break
      }
    }
    if (-not $isCredentialLine) { $keptLines.Add($line) }
  }
  while ($keptLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($keptLines[$keptLines.Count - 1])) {
    $keptLines.RemoveAt($keptLines.Count - 1)
  }
  foreach ($credentialName in $credentialNames) {
    $keptLines.Add("$credentialName=$credentialPlaceholder")
  }
  $canonicalText = $keptLines -join "`n"

  if ($null -eq $environmentProperty) {
    $claude | Add-Member -MemberType NoteProperty -Name 'environmentVariables' -Value $canonicalText
  } else {
    $environmentProperty.Value = $canonicalText
  }
}

function Set-CanonicalReleaseDefaults {
  param([Parameter(Mandatory = $true)][pscustomobject]$Settings)

  Set-JsonProperty -Object $Settings -Name 'permissionMode' -Value 'normal'
  Set-JsonProperty -Object $Settings -Name 'userName' -Value ''
  Set-JsonProperty -Object $Settings -Name 'persistentExternalContextPaths' -Value ([object[]]@())

  $savedPermission = Get-OrAddObjectProperty -Object $Settings -Name 'savedProviderPermissionMode'
  Set-JsonProperty -Object $savedPermission -Name 'claude' -Value 'normal'

  $providerConfigs = Get-OrAddObjectProperty -Object $Settings -Name 'providerConfigs'
  $claude = Get-OrAddObjectProperty -Object $providerConfigs -Name 'claude'
  Set-JsonProperty -Object $claude -Name 'safeMode' -Value 'acceptEdits'
  Set-JsonProperty -Object $claude -Name 'enableChrome' -Value $false
  Set-JsonProperty -Object $claude -Name 'enableBangBash' -Value $false
  Set-JsonProperty -Object $claude -Name 'cliPath' -Value ''
}

function Clear-ClaudianRuntimeState {
  param([Parameter(Mandatory = $true)][string]$ClaudianRoot)

  if (-not (Test-Path -LiteralPath $ClaudianRoot)) {
    New-Item -ItemType Directory -Path $ClaudianRoot -Force | Out-Null
  }
  foreach ($item in @(Get-ChildItem -LiteralPath $ClaudianRoot -Force)) {
    if ($item.Name -eq 'claudian-settings.json') { continue }
    $script:runtimeFileRemovalCount += @(
      if ($item.PSIsContainer) { Get-ChildItem -LiteralPath $item.FullName -Force -Recurse -File } else { $item }
    ).Count
    if (-not (Test-PathInside -Candidate $item.FullName -Parent $ClaudianRoot)) {
      throw 'Claudian 运行状态清理路径越界。'
    }
    Remove-Item -LiteralPath $item.FullName -Recurse -Force
  }
  New-Item -ItemType Directory -Path (Join-Path $ClaudianRoot 'sessions') -Force | Out-Null
}

function Clear-AIWriteRuntimeState {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)

  $claudeRoot = Join-Path $VaultRoot '.claude'
  $runtimeRoot = Join-Path $claudeRoot 'runtime'
  if (-not (Test-Path -LiteralPath $runtimeRoot)) { return }
  if (-not (Test-PathInside -Candidate $runtimeRoot -Parent $claudeRoot)) {
    throw 'AI 写回运行目录清理路径越界。'
  }
  $script:runtimeFileRemovalCount += @(Get-ChildItem -LiteralPath $runtimeRoot -Force -Recurse -File).Count
  Remove-Item -LiteralPath $runtimeRoot -Recurse -Force
}

function Write-Utf8NoBomText {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )

  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
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

function Reset-ReleaseBusinessData {
  param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$PackageRoot
  )

  $userRecordDirectories = @(
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

  foreach ($relativeDirectory in $userRecordDirectories) {
    $directory = Join-Path $VaultRoot $relativeDirectory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
      throw "缺少用户数据目录：$relativeDirectory"
    }
    $readme = Join-Path $directory 'README.md'
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
      throw "用户数据目录缺少 README：$relativeDirectory"
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
      if ($item.FullName.Equals($readme, [StringComparison]::OrdinalIgnoreCase)) { continue }
      if (-not (Test-PathInside -Candidate $item.FullName -Parent $directory)) {
        throw "用户数据清理路径越界：$relativeDirectory"
      }
      $script:userDataRemovalCount += @(
        if ($item.PSIsContainer) { Get-ChildItem -LiteralPath $item.FullName -Force -Recurse -File } else { $item }
      ).Count
      Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }
  }

  $privateRuntimeDirectories = @(
    [pscustomobject]@{ Path = (Join-Path $VaultRoot '.trash'); Parent = $VaultRoot },
    [pscustomobject]@{ Path = (Join-Path $PackageRoot '备份'); Parent = $PackageRoot }
  )
  foreach ($entry in $privateRuntimeDirectories) {
    if (-not (Test-Path -LiteralPath $entry.Path)) { continue }
    if (-not (Test-PathInside -Candidate $entry.Path -Parent $entry.Parent)) {
      throw '私有运行目录清理路径越界。'
    }
    $script:userDataRemovalCount += @(Get-ChildItem -LiteralPath $entry.Path -Force -Recurse -File).Count
    Remove-Item -LiteralPath $entry.Path -Recurse -Force
  }

  $businessStatePath = Join-Path $VaultRoot '20_经营数据\经营状态.md'
  $confirmedLogPath = Join-Path $VaultRoot '60_AI商业运营专家\已确认写回记录.md'
  $previewPath = Join-Path $VaultRoot '60_AI商业运营专家\写回预览.md'
  foreach ($requiredPath in @($businessStatePath, $confirmedLogPath, $previewPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
      throw "缺少发布重置目标：$($requiredPath.Substring($VaultRoot.Length + 1))"
    }
  }
  Write-Utf8NoBomText -Path $businessStatePath -Text ((Get-DefaultBusinessStateText).TrimEnd() + "`r`n")
  Write-Utf8NoBomText -Path $confirmedLogPath -Text ((Get-EmptyConfirmedWritebackLogText).TrimEnd() + "`r`n")
  Write-Utf8NoBomText -Path $previewPath -Text ((Get-EmptyWritebackPreviewText).TrimEnd() + "`r`n")
  $script:releaseStateResetCount += 3
}

function Reset-RealClaudianSessionState {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)

  $dataPath = Join-Path $VaultRoot '.obsidian\plugins\realclaudian\data.json'
  if (-not (Test-Path -LiteralPath $dataPath -PathType Leaf)) {
    throw '缺少 RealClaudian data.json，无法保证发布包不带会话标签状态。'
  }
  $emptyState = [ordered]@{
    tabManagerState = [ordered]@{
      openTabs = @()
      activeTabId = $null
    }
  }
  Write-Utf8NoBomText -Path $dataPath -Text (($emptyState | ConvertTo-Json -Depth 10) + "`r`n")
  $script:realClaudianStateResetCount++
}

function Reset-ObsidianWorkspaceState {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)

  $workspacePath = Join-Path $VaultRoot '.obsidian\workspace.json'
  if (-not (Test-Path -LiteralPath $workspacePath -PathType Leaf)) {
    throw '缺少 Obsidian workspace.json，无法保证空白母版不带历史打开记录。'
  }

  $workspace = Get-Content -LiteralPath $workspacePath -Raw -Encoding utf8 | ConvertFrom-Json
  $tabGroups = @($workspace.main.children | Where-Object { $_.type -eq 'tabs' })
  if ($tabGroups.Count -ne 1) {
    throw "Obsidian 主区 tabs 数量应为 1，实际为 $($tabGroups.Count)。"
  }
  $homeLeaves = @($tabGroups[0].children | Where-Object {
    $_.type -eq 'leaf' -and
    $_.state.type -eq 'markdown' -and
    $_.state.state.file -eq '00_开始这里/首页.md'
  })
  if ($homeLeaves.Count -ne 1) {
    throw "Obsidian 主区固定首页数量应为 1，实际为 $($homeLeaves.Count)。"
  }

  $tabGroups[0].children = @($homeLeaves[0])
  if ($null -eq $tabGroups[0].PSObject.Properties['currentTab']) {
    $tabGroups[0] | Add-Member -MemberType NoteProperty -Name 'currentTab' -Value 0
  } else {
    $tabGroups[0].currentTab = 0
  }
  $workspace.active = $homeLeaves[0].id
  $workspace.lastOpenFiles = @('00_开始这里/首页.md')

  foreach ($leaf in @($workspace.left.children | ForEach-Object { $_.children } | Where-Object {
    $_.type -eq 'leaf' -and $_.state.type -eq 'search'
  })) {
    $leaf.state.state.query = ''
  }

  Write-Utf8NoBomText -Path $workspacePath -Text (($workspace | ConvertTo-Json -Depth 100) + "`r`n")
  $script:obsidianWorkspaceResetCount++
}

function Write-Sha256Manifest {
  param([Parameter(Mandatory = $true)][string]$Root)

  $manifestPath = Join-Path $Root 'SHA256SUMS.txt'
  if (Test-Path -LiteralPath $manifestPath) {
    [IO.File]::Delete($manifestPath)
  }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($file in @(Get-ChildItem -LiteralPath $Root -Force -Recurse -File | Sort-Object FullName)) {
    if ($file.FullName.Equals($manifestPath, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $relative = (Get-RelativePathSafe -BasePath $Root -TargetPath $file.FullName).Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
    $lines.Add("$hash *$relative")
  }
  [IO.File]::WriteAllText($manifestPath, (($lines -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($false)))
  $script:manifestFileCount = $lines.Count
  return $manifestPath
}

function Test-Sha256Manifest {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ManifestPath
  )

  $lines = @([IO.File]::ReadAllLines($ManifestPath, [Text.Encoding]::UTF8) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  foreach ($line in $lines) {
    if ($line -notmatch '^([A-Fa-f0-9]{64}) \*(.+)$') {
      throw 'SHA256SUMS.txt 格式错误。'
    }
    $expected = $matches[1].ToUpperInvariant()
    $relative = $matches[2].Replace('/', '\')
    $target = [IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not (Test-PathInside -Candidate $target -Parent $Root) -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
      throw 'SHA256SUMS.txt 包含缺失或越界路径。'
    }
    $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $expected) {
      throw 'SHA256SUMS.txt 校验失败。'
    }
  }
  return $lines.Count
}

function New-StandardZip {
  param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$ZipPath
  )

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $ZipPath) { [IO.File]::Delete($ZipPath) }
  $topName = Split-Path -Leaf $SourceRoot.TrimEnd('\')
  $stream = [IO.File]::Open($ZipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  try {
    $archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $false, [Text.Encoding]::UTF8)
    try {
      $archive.CreateEntry("$topName/") | Out-Null
      foreach ($directory in @(Get-ChildItem -LiteralPath $SourceRoot -Force -Recurse -Directory | Sort-Object FullName)) {
        $relative = (Get-RelativePathSafe -BasePath $SourceRoot -TargetPath $directory.FullName).Replace('\', '/')
        $archive.CreateEntry("$topName/$relative/") | Out-Null
      }
      foreach ($file in @(Get-ChildItem -LiteralPath $SourceRoot -Force -Recurse -File | Sort-Object FullName)) {
        $relative = (Get-RelativePathSafe -BasePath $SourceRoot -TargetPath $file.FullName).Replace('\', '/')
        $entry = $archive.CreateEntry("$topName/$relative", [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $file.LastWriteTime
        $input = [IO.File]::OpenRead($file.FullName)
        $output = $entry.Open()
        try { $input.CopyTo($output) }
        finally {
          $output.Dispose()
          $input.Dispose()
        }
      }
    } finally {
      $archive.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Test-StandardZip {
  param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$TopName,
    [Parameter(Mandatory = $true)][int]$ExpectedEntryCount
  )

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entries = @($archive.Entries)
    if ($entries.Count -ne $ExpectedEntryCount) {
      throw 'ZIP 条目数量与 staging 不一致。'
    }
    foreach ($entry in $entries) {
      if (-not $entry.FullName.StartsWith("$TopName/", [StringComparison]::Ordinal)) {
        throw 'ZIP 不是单顶层目录结构。'
      }
    }
    $requiredSuffixes = @('/SHA256SUMS.txt', '/.claudian/claudian-settings.json')
    foreach ($suffix in $requiredSuffixes) {
      if (@($entries | Where-Object { $_.FullName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase) }).Count -ne 1) {
        throw "ZIP 缺少必需条目：$suffix"
      }
    }
    $sessionFiles = @($entries | Where-Object {
      $_.FullName -match '/\.claudian/sessions/.+' -and -not $_.FullName.EndsWith('/')
    })
    if ($sessionFiles.Count -gt 0) {
      throw 'ZIP 仍包含 Claudian 会话文件。'
    }
    $writeRuntimeFiles = @($entries | Where-Object {
      $_.FullName -match '/\.claude/runtime/.+' -and -not $_.FullName.EndsWith('/')
    })
    if ($writeRuntimeFiles.Count -gt 0) {
      throw 'ZIP 仍包含 AI 写回恢复快照或操作审计。'
    }
    $privateBusinessDataFiles = @($entries | Where-Object {
      ($_.FullName -match '/20_经营数据/(?:经营核算/(?:产品收费方案|实际核算|创业预估|AI结论)|经营目标/(?:目标方案|行动计划))/.+' -or
       $_.FullName -match '/40_能力商品化/(?:验证记录|市场反馈导出)/.+') -and
      -not $_.FullName.EndsWith('/') -and
      -not $_.FullName.EndsWith('/README.md', [StringComparison]::OrdinalIgnoreCase)
    })
    if ($privateBusinessDataFiles.Count -gt 0) {
      throw 'ZIP 仍包含用户经营核算、目标方案、行动计划、进度、转化假设、能力验证或市场反馈。'
    }
    $script:zipEntryCount = $entries.Count
  } finally {
    $archive.Dispose()
  }
}

try {
  $package = (Resolve-Path -LiteralPath $PackageRoot).Path
  if (-not (Test-Path -LiteralPath $package -PathType Container)) {
    throw 'PackageRoot 必须是现有目录。'
  }
  $output = Get-AbsolutePath -Path $OutputZip
  if ([IO.Path]::GetExtension($output) -ne '.zip') {
    throw 'OutputZip 必须以 .zip 结尾。'
  }
  if (Test-PathInside -Candidate $output -Parent $package) {
    throw 'OutputZip 不能位于 PackageRoot 内部。'
  }

  $workspaceRoot = Find-WorkspaceRoot -Starts @($package, $PSScriptRoot, (Get-Location).Path)
  $temporaryRoot = Join-Path $workspaceRoot '.codex_tmp'
  New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
  $runRoot = Join-Path $temporaryRoot ('sanitized-release-' + [Guid]::NewGuid().ToString('N'))
  if (-not (Test-PathInside -Candidate $runRoot -Parent $temporaryRoot)) {
    throw '净包 staging 路径越界。'
  }
  New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
  $stagingPackage = Join-Path $runRoot (Split-Path -Leaf $package.TrimEnd('\'))
  $zipTemporary = Join-Path $runRoot 'release.zip'

  Copy-TreeIncludingHiddenAndEmpty -Source $package -Destination $stagingPackage

  $vaults = @(Get-ChildItem -LiteralPath $stagingPackage -Directory -Force | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName '.obsidian')
  })
  if ($vaults.Count -ne 1) {
    throw "经营空间数量应为 1，实际为 $($vaults.Count)。"
  }
  $claudianRoot = Join-Path $vaults[0].FullName '.claudian'
  $settingsPath = Join-Path $claudianRoot 'claudian-settings.json'
  if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    throw '缺少 .claudian/claudian-settings.json，无法保证净包凭证占位状态。'
  }

  $settingsText = [IO.File]::ReadAllText($settingsPath, [Text.Encoding]::UTF8)
  $settings = $settingsText | ConvertFrom-Json
  if ($settings -isnot [pscustomobject]) {
    throw 'Claudian 设置不是 JSON 对象。'
  }
  Sanitize-JsonNode -Node $settings
  Set-CanonicalCredentialPlaceholders -Settings $settings
  Set-CanonicalReleaseDefaults -Settings $settings
  $safeSettingsText = $settings | ConvertTo-Json -Depth 100
  [IO.File]::WriteAllText($settingsPath, ($safeSettingsText + "`r`n"), (New-Object Text.UTF8Encoding($false)))
  Clear-ClaudianRuntimeState -ClaudianRoot $claudianRoot
  Clear-AIWriteRuntimeState -VaultRoot $vaults[0].FullName
  Reset-ReleaseBusinessData -VaultRoot $vaults[0].FullName -PackageRoot $stagingPackage
  Reset-RealClaudianSessionState -VaultRoot $vaults[0].FullName
  Reset-ObsidianWorkspaceState -VaultRoot $vaults[0].FullName

  $postSanitizeText = [IO.File]::ReadAllText($settingsPath, [Text.Encoding]::UTF8)
  $credentialPlaceholderLines = 0
  foreach ($credentialName in $credentialNames) {
    $count = [regex]::Matches($postSanitizeText, ('(?m)' + [regex]::Escape($credentialName) + '=' + [regex]::Escape($credentialPlaceholder))).Count
    if ($count -lt 1) { throw "净包缺少凭证占位字段：$credentialName" }
    $credentialPlaceholderLines += $count
  }
  if ($postSanitizeText -match 'sk-[A-Za-z0-9_-]{12,}|ANTHROPIC_(AUTH_TOKEN|API_KEY)=(?!PASTE_)') {
    throw '净包 Claudian 设置仍疑似包含凭证。'
  }

  $validator = Join-Path $stagingPackage '_tools\validate-package.ps1'
  if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw '净包缺少 validate-package.ps1。'
  }
  & $validator -PackageRoot $stagingPackage -ReleaseMode
  if ($LASTEXITCODE -ne 0) { throw '发布模式校验失败。' }

  $manifest = Write-Sha256Manifest -Root $stagingPackage
  $verifiedManifestCount = Test-Sha256Manifest -Root $stagingPackage -ManifestPath $manifest
  if ($verifiedManifestCount -ne $manifestFileCount) {
    throw 'SHA256SUMS.txt 文件数复核失败。'
  }

  New-StandardZip -SourceRoot $stagingPackage -ZipPath $zipTemporary
  $expectedEntries = 1 +
    @(Get-ChildItem -LiteralPath $stagingPackage -Force -Recurse -Directory).Count +
    @(Get-ChildItem -LiteralPath $stagingPackage -Force -Recurse -File).Count
  $topName = Split-Path -Leaf $stagingPackage.TrimEnd('\')
  Test-StandardZip -ZipPath $zipTemporary -TopName $topName -ExpectedEntryCount $expectedEntries

  $outputDirectory = Split-Path -Parent $output
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
  if (Test-Path -LiteralPath $output) { [IO.File]::Delete($output) }
  [IO.File]::Move($zipTemporary, $output)
  $outputHash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToUpperInvariant()
  $sidecar = $output + '.sha256'
  [IO.File]::WriteAllText(
    $sidecar,
    "$outputHash *$(Split-Path -Leaf $output)`r`n",
    (New-Object Text.UTF8Encoding($false))
  )
  $sidecarLine = [IO.File]::ReadAllText($sidecar, [Text.Encoding]::UTF8).Trim()
  if ($sidecarLine -ne "$outputHash *$(Split-Path -Leaf $output)") {
    throw 'ZIP 同级 SHA-256 文件复核失败。'
  }

  Write-Host '脱敏净包构建通过。' -ForegroundColor Green
  Write-Host "凭证占位字段完整：$($credentialPlaceholderLines -ge 2)"
  Write-Host "凭证替换次数：$credentialReplacementCount"
  Write-Host "设备/主机/会话字段清空数：$stateFieldClearCount"
  Write-Host "会话与运行文件清除数：$runtimeFileRemovalCount"
  Write-Host "用户经营记录清除数：$userDataRemovalCount"
  Write-Host "经营状态/日志/预览重置数：$releaseStateResetCount"
  Write-Host "RealClaudian 会话状态重置数：$realClaudianStateResetCount"
  Write-Host "Obsidian 工作区状态重置数：$obsidianWorkspaceResetCount"
  Write-Host "SHA256SUMS 文件数：$manifestFileCount"
  Write-Host "ZIP 条目数：$zipEntryCount"
  Write-Host "发布模式校验：True"
  Write-Host "输出：$output"
  Write-Host "校验文件：$sidecar"
} finally {
  if ($null -ne $runRoot -and (Test-Path -LiteralPath $runRoot)) {
    $temporaryRootForCleanup = Join-Path $workspaceRoot '.codex_tmp'
    if (-not (Test-PathInside -Candidate $runRoot -Parent $temporaryRootForCleanup)) {
      throw '拒绝清理越界 staging。'
    }
    Remove-Item -LiteralPath $runRoot -Recurse -Force
  }
}
