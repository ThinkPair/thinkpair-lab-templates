param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot,
  [switch]$ReleaseMode,
  [switch]$SkipExchangeTests,
  [switch]$SkipBusinessValidation,
  [string]$ReleaseZipPath,
  [switch]$ZipOnly,
  [switch]$Quiet,
  [switch]$LibraryMode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:PassCount = 0

function Add-ValidationFailure {
  param([Parameter(Mandatory = $true)][string]$Message)
  $script:Failures.Add($Message)
}

function Add-ValidationWarning {
  param([Parameter(Mandatory = $true)][string]$Message)
  $script:Warnings.Add($Message)
}

function Add-ValidationPass {
  param([Parameter(Mandatory = $true)][string]$Message)
  $script:PassCount++
  if (-not $Quiet) { Write-Host "PASS  $Message" -ForegroundColor Green }
}

function Get-NormalizedPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Get-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )
  $rootPath = (Get-NormalizedPath $Root) + '\'
  $fullPath = Get-NormalizedPath $Path
  if (-not $fullPath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "路径不在预期根目录中：$fullPath"
  }
  return $fullPath.Substring($rootPath.Length)
}

function Read-Utf8Text {
  param([Parameter(Mandatory = $true)][string]$Path)
  try {
    return [IO.File]::ReadAllText($Path, $script:Utf8Strict)
  } catch {
    throw "文件不是有效 UTF-8：$Path（$($_.Exception.Message)）"
  }
}

function ConvertFrom-SimpleYamlValue {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return $null }
  $trimmed = $Value.Trim()
  if ($trimmed -eq '[]') { return @() }
  if ($trimmed -in @('null', '~')) { return $null }
  if ($trimmed.Length -ge 2 -and $trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
    try { return [string]($trimmed | ConvertFrom-Json) } catch { return $trimmed.Substring(1, $trimmed.Length - 2) }
  }
  if ($trimmed.Length -ge 2 -and $trimmed.StartsWith("'") -and $trimmed.EndsWith("'")) {
    return $trimmed.Substring(1, $trimmed.Length - 2).Replace("''", "'")
  }
  if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
    $inner = $trimmed.Substring(1, $trimmed.Length - 2).Trim()
    if ([string]::IsNullOrWhiteSpace($inner)) { return @() }
    return @($inner.Split(',') | ForEach-Object { (ConvertFrom-SimpleYamlValue $_).ToString() })
  }
  return $trimmed
}

function Get-FrontMatterData {
  param([Parameter(Mandatory = $true)][string]$Content)
  $match = [regex]::Match($Content, '\A\uFEFF?---[ \t]*\r?\n(?<fm>.*?)\r?\n---(?:\r?\n|\z)', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $match.Success) { return $null }

  $data = @{}
  $currentListKey = $null
  foreach ($line in @($match.Groups['fm'].Value -split '\r?\n')) {
    if ($line -match '^([A-Za-z0-9_]+):[ \t]*(.*)$') {
      $key = $matches[1]
      $rawValue = $matches[2]
      if ([string]::IsNullOrWhiteSpace($rawValue)) {
        $data[$key] = @()
        $currentListKey = $key
      } else {
        $data[$key] = ConvertFrom-SimpleYamlValue $rawValue
        $currentListKey = $null
      }
      continue
    }
    if ($null -ne $currentListKey -and $line -match '^[ \t]+-[ \t]+(.*)$') {
      $existing = @($data[$currentListKey])
      $data[$currentListKey] = @($existing + (ConvertFrom-SimpleYamlValue $matches[1]))
      continue
    }
    if ($line -notmatch '^[ \t]*$' -and $line -notmatch '^[ \t]*#') { $currentListKey = $null }
  }
  return $data
}

function Get-DataValue {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Data,
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()]$Default = $null
  )
  if ($Data.ContainsKey($Name)) { return $Data[$Name] }
  return $Default
}

function Get-DataString {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Data,
    [Parameter(Mandatory = $true)][string]$Name
  )
  $value = Get-DataValue -Data $Data -Name $Name
  if ($null -eq $value -or $value -is [Array]) { return '' }
  return [string]$value
}

function Get-DataArray {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Data,
    [Parameter(Mandatory = $true)][string]$Name
  )
  $value = Get-DataValue -Data $Data -Name $Name
  if ($null -eq $value) { return @() }
  if ($value -is [Array]) { return @($value | ForEach-Object { [string]$_ }) }
  if ([string]::IsNullOrWhiteSpace([string]$value)) { return @() }
  return @([string]$value)
}

function Get-AbilityRecords {
  param([Parameter(Mandatory = $true)][string]$VaultRoot)
  $records = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $VaultRoot -PathType Container)) { return @() }
  foreach ($file in @(Get-ChildItem -LiteralPath $VaultRoot -Recurse -Force -Filter '*.md' -File)) {
    $content = Read-Utf8Text $file.FullName
    $data = Get-FrontMatterData $content
    if ($null -eq $data -or -not $data.ContainsKey('record_type')) { continue }
    $relative = Get-RelativePath -Root $VaultRoot -Path $file.FullName
    $isTemplate = $file.BaseName.StartsWith('模板_', [StringComparison]::OrdinalIgnoreCase) -or $relative -match '(^|\\)模板($|\\)'
    $isDemo = $relative.StartsWith('70_只读示例\', [StringComparison]::OrdinalIgnoreCase)
    $records.Add([pscustomobject]@{
      Path = $file.FullName
      RelativePath = $relative
      Content = $content
      Data = $data
      IsTemplate = $isTemplate
      IsDemo = $isDemo
    })
  }
  return $records.ToArray()
}

function Get-CurrentEvidenceRecords {
  param([Parameter(Mandatory = $true)][object[]]$Records)
  $candidates = @($Records | Where-Object {
    (Get-DataString $_.Data 'record_type') -eq 'evidence_item' -and
    (Get-DataString $_.Data 'record_status') -eq 'confirmed' -and
    (Get-DataString $_.Data 'evidence_validity') -notin @('superseded', 'invalidated', 'expired')
  })
  $supersededIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($record in $candidates) {
    $oldId = Get-DataString $record.Data 'supersedes_evidence_id'
    if (-not [string]::IsNullOrWhiteSpace($oldId)) { [void]$supersededIds.Add($oldId) }
  }
  return @($candidates | Where-Object {
    $recordId = Get-DataString $_.Data 'record_id'
    $evidenceId = Get-DataString $_.Data 'evidence_id'
    -not $supersededIds.Contains($recordId) -and -not $supersededIds.Contains($evidenceId)
  })
}

function Get-AbilityStatistics {
  param([Parameter(Mandatory = $true)][object[]]$Records)
  $confirmed = @($Records | Where-Object { (Get-DataString $_.Data 'record_status') -eq 'confirmed' })
  $currentEvidence = @(Get-CurrentEvidenceRecords -Records $Records)
  return [pscustomobject]@{
    ConfirmedTotal = $confirmed.Count
    SkillProfiles = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'skill_profile' }).Count
    Dimensions = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'skill_dimension' }).Count
    Practices = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'practice_record' }).Count
    Evidence = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'evidence_item' }).Count
    CurrentEvidence = $currentEvidence.Count
    Reviews = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'skill_review' }).Count
    Transfers = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'capability_transfer' }).Count
    MarketFeedback = @($confirmed | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'market_feedback' }).Count
  }
}

function Get-AbilityModelErrors {
  param([Parameter(Mandatory = $true)][object[]]$Records)
  $errors = New-Object System.Collections.Generic.List[string]
  $allowedTypes = @('skill_profile', 'skill_dimension', 'practice_record', 'evidence_item', 'skill_review', 'capability_transfer', 'market_feedback', 'field_draft')
  $allowedStatuses = @('draft', 'confirmed', 'archived', 'demo')
  $allowedPrivacy = @('private', 'sensitive', 'shareable')
  $allowedStates = @('unproven', 'observed', 'repeatable', 'externally_validated', 'transfer_ready')
  $commonFields = @('record_id', 'record_type', 'skill_id', 'record_status', 'created_at', 'updated_at', 'privacy', 'schema_version')
  $schemaByType = @{
    skill_profile = @('ability.v1')
    skill_dimension = @('ability.v1')
    practice_record = @('ability.v1')
    evidence_item = @('ability.v1')
    skill_review = @('ability.v1')
    capability_transfer = @('exchange.capability_transfer.v1')
    market_feedback = @('exchange.market_feedback.v1')
    field_draft = @('ability.field_draft.v1')
  }

  $idMap = @{}
  foreach ($record in $Records) {
    $data = $record.Data
    $type = Get-DataString $data 'record_type'
    $status = Get-DataString $data 'record_status'
    $schema = Get-DataString $data 'schema_version'
    foreach ($field in $commonFields) {
      if (-not $data.ContainsKey($field)) { $errors.Add("缺少共同字段 $field：$($record.RelativePath)") }
    }
    if ($type -notin $allowedTypes) { $errors.Add("未知 record_type '$type'：$($record.RelativePath)") }
    if ($status -notin $allowedStatuses) { $errors.Add("未知 record_status '$status'：$($record.RelativePath)") }
    $privacy = Get-DataString $data 'privacy'
    if ($privacy -notin $allowedPrivacy) { $errors.Add("未知 privacy '$privacy'：$($record.RelativePath)") }
    if ($schemaByType.ContainsKey($type) -and $schema -notin $schemaByType[$type]) {
      $errors.Add("schema_version 与 record_type 不匹配：$($record.RelativePath)（$type / $schema）")
    }
    if (-not $record.IsTemplate -and $status -in @('confirmed', 'demo')) {
      foreach ($field in $commonFields) {
        if ([string]::IsNullOrWhiteSpace((Get-DataString $data $field))) {
          $errors.Add("$status 记录的共同字段 $field 为空：$($record.RelativePath)")
        }
      }
    }
    if ($record.IsDemo -and $status -ne 'demo') { $errors.Add("只读示例必须是 record_status: demo：$($record.RelativePath)") }
    if (-not $record.IsDemo -and $status -eq 'demo') { $errors.Add("demo 记录只能位于 70_只读示例：$($record.RelativePath)") }
    if ($type -eq 'field_draft') {
      if (-not $record.RelativePath.StartsWith('90_现场草稿\', [StringComparison]::OrdinalIgnoreCase)) { $errors.Add("field_draft 只能位于 90_现场草稿：$($record.RelativePath)") }
      if ($status -ne 'draft' -or (Get-DataString $data 'excluded_from_statistics') -ne 'true') { $errors.Add("field_draft 必须保持 draft 且 excluded_from_statistics: true：$($record.RelativePath)") }
    }

    $recordId = Get-DataString $data 'record_id'
    if (-not [string]::IsNullOrWhiteSpace($recordId)) {
      if ($idMap.ContainsKey($recordId)) { $errors.Add("record_id 重复：$recordId") }
      else { $idMap[$recordId] = $record }
    }
  }

  foreach ($record in @($Records | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'skill_dimension' })) {
    $data = $record.Data
    $state = Get-DataString $data 'evidence_state'
    if ($state -notin $allowedStates) { $errors.Add("未知 evidence_state '$state'：$($record.RelativePath)"); continue }
    $refs = @(Get-DataArray $data 'evidence_refs')
    if ($state -ne 'unproven' -and $refs.Count -eq 0) {
      $errors.Add("非 unproven 维度必须引用证据：$($record.RelativePath)")
      continue
    }
    $resolved = New-Object System.Collections.Generic.List[object]
    foreach ($ref in $refs) {
      if (-not $idMap.ContainsKey($ref)) { $errors.Add("证据引用不存在：$ref（$($record.RelativePath)）"); continue }
      $target = $idMap[$ref]
      if ((Get-DataString $target.Data 'record_type') -ne 'evidence_item') {
        $errors.Add("evidence_refs 引用的不是 evidence_item：$ref（$($record.RelativePath)）")
        continue
      }
      $expectedStatus = if ($record.IsDemo) { 'demo' } else { 'confirmed' }
      if ((Get-DataString $target.Data 'record_status') -ne $expectedStatus) {
        $errors.Add("证据状态与维度不兼容：$ref（应为 $expectedStatus）")
      }
      if ((Get-DataString $target.Data 'evidence_validity') -in @('superseded', 'invalidated', 'expired')) {
        $errors.Add("维度仍引用已失效证据：$ref（$($record.RelativePath)）")
      }
      $resolved.Add($target)
    }
    if ($state -eq 'externally_validated') {
      $external = @($resolved | Where-Object {
        (Get-DataString $_.Data 'evidence_type') -eq 'external_feedback' -and
        (Get-DataString $_.Data 'source_kind') -eq 'external_feedback' -and
        (Get-DataString $_.Data 'verification_level') -eq 'externally_provided'
      })
      if ($external.Count -eq 0) { $errors.Add("externally_validated 必须引用外部提供的正式反馈：$($record.RelativePath)") }
    }
  }

  $activeProfiles = @($Records | Where-Object {
    (Get-DataString $_.Data 'record_type') -eq 'skill_profile' -and
    (Get-DataString $_.Data 'record_status') -eq 'confirmed' -and
    (Get-DataString $_.Data 'status') -eq 'active'
  })
  if ($activeProfiles.Count -gt 1) { $errors.Add("同时存在 $($activeProfiles.Count) 个 confirmed + active 主技能，只允许 1 个") }
  if ($activeProfiles.Count -eq 1) {
    $activeSkillId = Get-DataString $activeProfiles[0].Data 'skill_id'
    $activeDimensions = @($Records | Where-Object {
      (Get-DataString $_.Data 'record_type') -eq 'skill_dimension' -and
      (Get-DataString $_.Data 'record_status') -eq 'confirmed' -and
      (Get-DataString $_.Data 'skill_id') -eq $activeSkillId
    })
    if ($activeDimensions.Count -ne 6) { $errors.Add("当前 active 主技能必须恰好关联 6 个 confirmed 维度，当前为 $($activeDimensions.Count) 个") }
  }

  $dimensionIds = @{}
  foreach ($dimension in @($Records | Where-Object { (Get-DataString $_.Data 'record_type') -eq 'skill_dimension' })) {
    $dimensionId = Get-DataString $dimension.Data 'dimension_id'
    if (-not [string]::IsNullOrWhiteSpace($dimensionId)) { $dimensionIds[$dimensionId] = $dimension }
  }
  foreach ($practice in @($Records | Where-Object {
    (Get-DataString $_.Data 'record_type') -eq 'practice_record' -and
    (Get-DataString $_.Data 'record_status') -in @('confirmed', 'demo') -and -not $_.IsTemplate
  })) {
    $dimensionId = Get-DataString $practice.Data 'dimension_id'
    if ([string]::IsNullOrWhiteSpace($dimensionId) -or -not $dimensionIds.ContainsKey($dimensionId)) {
      $errors.Add("练习必须关联一个存在的维度：$($practice.RelativePath)")
    } elseif ((Get-DataString $dimensionIds[$dimensionId].Data 'skill_id') -ne (Get-DataString $practice.Data 'skill_id')) {
      $errors.Add("练习与关联维度不属于同一 skill_id：$($practice.RelativePath)")
    }
  }
  return $errors.ToArray()
}

function Get-DeliverableFiles {
  param([Parameter(Mandatory = $true)][string]$Root)
  $allowedRootFiles = @(
    '1_打开个人能力复利驾驶舱.cmd', '3_检查能力驾驶舱.cmd', '4_备份我的能力数据.cmd',
    '2_打开一人公司商业运营驾驶舱.cmd', '6_检查商业驾驶舱.cmd', '7_备份我的经营数据.cmd',
    '0_先看我_双驾驶舱三步开始.txt', 'AGENTS.md', 'README.md', 'ROOT_PRODUCT.md', '版本信息与校验.txt', '发布文件清单_SHA256.txt'
  )
  $allowedToolFiles = @(
    '_tools\open-vault.ps1', '_tools\backup-data.ps1', '_tools\validate-package.ps1',
    '_tools\exchange-card.ps1', '_tools\ExchangeContract.psm1',
    '_tools\open-business-vault.ps1', '_tools\validate-business-package.ps1', '_tools\backup-business-data.ps1'
  )
  return @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {
    $relative = Get-RelativePath -Root $Root -Path $_.FullName
    $top = $relative.Split('\')[0]
    ($top -in @('2_个人能力复利空间_首次选择这个文件夹', '3_受控交换箱', 'LICENSES')) -or
    ($relative -in $allowedRootFiles) -or ($relative -in $allowedToolFiles) -or
    (Test-IsSafeEmbeddedBusinessRelative -Relative $relative)
  })
}

function Test-IsSafeEmbeddedBusinessRelative {
  param([Parameter(Mandatory = $true)][string]$Relative)
  $prefix = '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\'
  if (-not $Relative.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $false }
  $nested = $Relative.Substring($prefix.Length)
  if ($nested -match '(^|\\)(备份|\.trash|node_modules|dist|_prototype|tmp|temp|测试输出|发布包)(\\|$)') { return $false }
  if ($nested -match '(^|\\)\.claudian\\' -and $nested -notmatch '\.claudian\\claudian-settings\.json$') { return $false }
  if ($nested -match '(^|\\)(\.env(?:\..*)?|credentials?\.[^\\]+|secrets?\.[^\\]+|[^\\]*(session|conversation|chat-history)[^\\]*\.json)$') { return $false }
  if ([IO.Path]::GetExtension($nested) -in @('.zip', '.tmp', '.bak', '.log')) { return $false }
  return $true
}

function Invoke-EmbeddedBusinessValidation {
  param(
    [Parameter(Mandatory = $true)][string]$Package,
    [switch]$AsRelease
  )
  $business = Join-Path $Package '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版'
  $validator = Join-Path $business '_tools\validate-package.ps1'
  if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { Add-ValidationFailure '缺少嵌套商业驾驶舱校验器'; return }
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $validator, '-PackageRoot', $business)
  if ($AsRelease) { $arguments += '-ReleaseMode' }
  $output = & powershell.exe @arguments 2>&1
  if ($LASTEXITCODE -ne 0) { Add-ValidationFailure "嵌套商业驾驶舱校验失败：$($output -join ' | ')" }
  else { Add-ValidationPass $(if ($AsRelease) { '嵌套商业驾驶舱 ReleaseMode 校验通过' } else { '嵌套商业驾驶舱本机校验通过' }) }
}

function Test-JsonFiles {
  param([Parameter(Mandatory = $true)][object[]]$Files)
  foreach ($file in @($Files | Where-Object { $_.Extension -eq '.json' })) {
    try { $null = (Read-Utf8Text $file.FullName) | ConvertFrom-Json }
    catch { Add-ValidationFailure "JSON 无法解析：$($file.FullName)（$($_.Exception.Message)）" }
  }
}

function Test-ReleaseManifest {
  param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][object[]]$DeliverableFiles
  )
  $manifestPath = Join-Path $Package '发布文件清单_SHA256.txt'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return }
  $entries = @{}
  foreach ($line in @((Read-Utf8Text $manifestPath) -split '\r?\n')) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    if ($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') { Add-ValidationFailure "发布文件清单格式错误：$line"; continue }
    $relative = $matches[2].Replace('/', '\')
    if ($entries.ContainsKey($relative)) { Add-ValidationFailure "发布文件清单路径重复：$relative"; continue }
    $candidate = Get-NormalizedPath (Join-Path $Package $relative)
    $prefix = (Get-NormalizedPath $Package) + '\'
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { Add-ValidationFailure "发布文件清单路径越界：$relative"; continue }
    $entries[$relative] = $matches[1].ToUpperInvariant()
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Add-ValidationFailure "发布文件清单引用缺失文件：$relative"; continue }
    $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    if ($actual -ne $entries[$relative]) { Add-ValidationFailure "发布文件清单哈希不一致：$relative" }
  }
  foreach ($file in @($DeliverableFiles | Where-Object { $_.FullName -ne $manifestPath })) {
    $relative = Get-RelativePath -Root $Package -Path $file.FullName
    if (-not $entries.ContainsKey($relative)) { Add-ValidationFailure "交付文件未进入发布哈希清单：$relative" }
  }
}

function Test-PluginIntegrity {
  param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Vault
  )
  $sourcePath = Join-Path $Package 'LICENSES\插件来源.md'
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Add-ValidationFailure '缺少 LICENSES\插件来源.md'; return }
  $source = Read-Utf8Text $sourcePath
  $specs = @(
    [pscustomobject]@{ Id = 'realclaudian'; Version = '2.0.21'; MainHash = '3D7ACB4D145B0F01D42DBA4D16744441D6F917CCB36AC3DEEAD1B0C8C99591B5'; License = 'Claudian-MIT.txt'; LicenseHash = '06DCDDBB6908A0C6DD4A9E8EC822EEA41D5A460A53089FECCCC8A68049E99241'; SourceToken = 'github.com/YishenTu/claudian' },
    [pscustomobject]@{ Id = 'dataview'; Version = '0.5.68'; MainHash = 'BCDB7A7882051A30427A3FA370533C1052019591E7551BCC12611BB9A726BBB3'; License = 'Dataview-MIT.txt'; LicenseHash = '35563884704F44C2EB6C77330C6724E979F000D90A83E20993928F2E6C7EBE0B'; SourceToken = 'github.com/blacksmithgu/obsidian-dataview' },
    [pscustomobject]@{ Id = 'homepage'; Version = '4.2.2'; MainHash = 'E55927995B4C2DFDFC09005D5489888F8ED6EF4262DAC82F086F7C5F00FF598E'; License = 'Homepage-MIT.txt'; LicenseHash = 'CBC970C07D68620D9BBC0B909657AD134DD6DB82538F03E58BEF47EC7FA583F0'; SourceToken = 'github.com/mirnovov/obsidian-homepage' }
  )
  foreach ($spec in $specs) {
    $pluginRoot = Join-Path $Vault ".obsidian\plugins\$($spec.Id)"
    foreach ($name in @('manifest.json', 'main.js', 'styles.css', 'data.json')) {
      if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot $name) -PathType Leaf)) { Add-ValidationFailure "插件 $($spec.Id) 缺少 $name" }
    }
    $manifestPath = Join-Path $pluginRoot 'manifest.json'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      try {
        $manifest = (Read-Utf8Text $manifestPath) | ConvertFrom-Json
        if ([string]$manifest.id -ne $spec.Id) { Add-ValidationFailure "插件目录与 manifest.id 不一致：$($spec.Id)" }
        if ([string]$manifest.version -ne $spec.Version) { Add-ValidationFailure "插件 $($spec.Id) 版本不是固定版本 $($spec.Version)" }
      } catch { Add-ValidationFailure "插件 $($spec.Id) manifest 无法解析" }
    }
    $mainPath = Join-Path $pluginRoot 'main.js'
    if (Test-Path -LiteralPath $mainPath -PathType Leaf) {
      $hash = (Get-FileHash -LiteralPath $mainPath -Algorithm SHA256).Hash
      if ($hash -ne $spec.MainHash) { Add-ValidationFailure "插件 $($spec.Id) main.js 哈希不一致：$hash" }
    }
    $licensePath = Join-Path $Package "LICENSES\$($spec.License)"
    if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) { Add-ValidationFailure "插件 $($spec.Id) 缺少随包许可证" }
    else {
      $licenseHash = (Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash
      if ($licenseHash -ne $spec.LicenseHash) { Add-ValidationFailure "插件 $($spec.Id) 许可证哈希不一致：$licenseHash" }
    }
    foreach ($token in @($spec.Version, $spec.MainHash, $spec.LicenseHash, $spec.SourceToken)) {
      if ($source.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) { Add-ValidationFailure "插件来源说明缺少 $($spec.Id) 的信息：$token" }
    }
  }
}

function Test-LocalEvidenceAssets {
  param(
    [Parameter(Mandatory = $true)][string]$Vault,
    [Parameter(Mandatory = $true)][object[]]$Records
  )
  foreach ($record in @($Records | Where-Object {
    (Get-DataString $_.Data 'record_type') -eq 'evidence_item' -and (Get-DataString $_.Data 'source_kind') -eq 'local_asset'
  })) {
    $source = Get-DataString $record.Data 'source'
    if ([string]::IsNullOrWhiteSpace($source)) { Add-ValidationFailure "local_asset 证据缺少 source：$($record.RelativePath)"; continue }
    $candidate = Get-NormalizedPath (Join-Path $Vault $source.Replace('/', '\'))
    $vaultPrefix = (Get-NormalizedPath $Vault) + '\'
    if (-not $candidate.StartsWith($vaultPrefix, [StringComparison]::OrdinalIgnoreCase)) { Add-ValidationFailure "证据附件越出能力空间：$($record.RelativePath)"; continue }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Add-ValidationFailure "证据附件不存在：$source"; continue }
    $expected = Get-DataString $record.Data 'source_hash'
    if (-not [string]::IsNullOrWhiteSpace($expected)) {
      $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
      if (-not [string]::Equals($actual, $expected, [StringComparison]::OrdinalIgnoreCase)) { Add-ValidationFailure "证据附件哈希不一致：$source" }
    }
  }
}

function Test-TcmDemoSafety {
  param([Parameter(Mandatory = $true)][string]$Vault)
  $root = Join-Path $Vault '70_只读示例\中医从业者'
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { Add-ValidationFailure '缺少中医从业者只读示例'; return }
  $danger = '(患者姓名|身份证(?:号)?[:：]|手机号[:：]|联系方式[:：]|住址[:：]|病历号[:：]|处方[:：]|建议服用|应当服用|每日\s*\d+\s*次|保证.{0,8}(治愈|有效)|疗效(?:显著|确切)|替代.{0,10}(就医|诊疗|医生)|确诊为)'
  foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -Force -Filter '*.md' -File)) {
    $content = Read-Utf8Text $file.FullName
    foreach ($line in @($content -split '\r?\n')) {
      if ($line -match $danger -and $line -notmatch '(不提供诊疗建议|不做疗效承诺|不包含患者身份|禁止|不得|不替代)') {
        Add-ValidationFailure "中医示例疑似包含患者身份、诊疗建议或疗效承诺：$($file.Name)"
        break
      }
    }
  }
  $readme = Read-Utf8Text (Join-Path $root 'README.md')
  foreach ($guard in @('不包含患者身份', '不提供诊疗建议', '不做疗效承诺', '不替代执业规范')) {
    if ($readme.IndexOf($guard, [StringComparison]::Ordinal) -lt 0) { Add-ValidationFailure "中医示例边界说明缺少：$guard" }
  }
}

function Test-ObsidianBaseline {
  param(
    [Parameter(Mandatory = $true)][string]$Vault,
    [switch]$AsRelease
  )
  $appearance = Read-Utf8Text (Join-Path $Vault '.obsidian\appearance.json')
  if ($appearance -notmatch '"ability-cockpit"') { Add-ValidationFailure 'Obsidian 未启用 ability-cockpit 视觉样式' }

  $homepage = Read-Utf8Text (Join-Path $Vault '.obsidian\plugins\homepage\data.json')
  foreach ($pattern in @('"value"\s*:\s*"00_开始这里/首页"', '"openOnStartup"\s*:\s*true', '"pin"\s*:\s*true', '"refreshDataview"\s*:\s*true')) {
    if ($homepage -notmatch $pattern) { Add-ValidationFailure "Homepage 启动配置缺少：$pattern" }
  }

  $workspace = Read-Utf8Text (Join-Path $Vault '.obsidian\workspace.json')
  if ($workspace -notmatch '"file"\s*:\s*"00_开始这里/首页\.md"' -or $workspace -notmatch '"pinned"\s*:\s*true') { Add-ValidationFailure 'workspace.json 没有固定首页' }
  if ($workspace -notmatch '"type"\s*:\s*"claudian-view"') { Add-ValidationFailure 'workspace.json 没有能力教练侧栏' }
  if ($AsRelease -and $workspace -match '(练习记录|证据记录|反馈记录|复盘记录|能力移交卡|市场反馈|90_现场草稿)[/\\][^"\\/]+\.md') {
    Add-ValidationFailure '发布 workspace.json 残留用户运行文件路径'
  }
}

function Test-AbilityWriterIntegrity {
  param(
    [Parameter(Mandatory = $true)][string]$Vault,
    [switch]$AsRelease
  )
  $relativeFiles = @(
    '.claude\hooks\ability-write-core.ps1',
    '.claude\hooks\ability-write.ps1',
    '.claude\hooks\ability-write-usage.md',
    '.claude\hooks\test-ability-write.ps1',
    '.claude\write-queue\README.md'
  )
  $missing = @($relativeFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Vault $_) -PathType Leaf) })
  foreach ($relative in $missing) { Add-ValidationFailure "能力写回引擎缺少必需文件：$relative" }
  if ($missing.Count -gt 0) { return }

  foreach ($relative in @('.claude\hooks\ability-write-core.ps1', '.claude\hooks\ability-write.ps1', '.claude\hooks\test-ability-write.ps1')) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $Vault $relative), [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) { Add-ValidationFailure "能力写回脚本存在 PowerShell 语法错误：$relative" }
  }

  $testPath = Join-Path $Vault '.claude\hooks\test-ability-write.ps1'
  $assertionCount = @([regex]::Matches((Read-Utf8Text $testPath), '(?m)^\s*Assert-True\b')).Count
  $minimumAssertionBaseline = 29
  if ($assertionCount -lt $minimumAssertionBaseline) {
    Add-ValidationFailure "能力写回核心回归低于发布安全基线 $minimumAssertionBaseline 项，当前为 $assertionCount 项"
  }
  if ($AsRelease) {
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testPath 2>&1
    if ($LASTEXITCODE -ne 0) { Add-ValidationFailure "能力写回核心回归脚本执行失败（当前清单 $assertionCount 项）" }
    else { Add-ValidationPass "能力写回核心回归脚本执行通过（当前清单 $assertionCount 项，以退出码判定）" }
  } elseif ($assertionCount -ge $minimumAssertionBaseline) {
    Add-ValidationPass "能力写回引擎必需文件、语法与测试清单完整（当前 $assertionCount 项）"
  }
}

function Test-IsCredentialPlaceholder {
  param([AllowNull()]$Value)
  if ($null -eq $Value) { return $true }
  $text = ([string]$Value).Trim().Trim('"', "'")
  if ([string]::IsNullOrWhiteSpace($text)) { return $true }
  return $text -match '(?i)^(?:PASTE(?:[_ -].*)?|YOUR(?:[_ -].*)?|REPLACE(?:[_ -]?ME)?|CHANGE(?:[_ -]?ME)?|PLACEHOLDER|EXAMPLE|DUMMY|TEST_ONLY|<[^>]+>|\$\{[^}]+\}|\{\{[^}]+\}\}|%[A-Z0-9_]+%|null|undefined|none|待填写|请填写|占位(?:符)?)$'
}

function Test-IsPlausibleCredentialValue {
  param([AllowNull()][string]$Value)
  if (Test-IsCredentialPlaceholder $Value) { return $false }
  $candidate = $Value.Trim().Trim('"', "'").TrimEnd(',', ';', '}', ']')
  if ($candidate.Length -lt 20 -or $candidate.Length -gt 4096) { return $false }
  if ($candidate -match '(?i)^(?:this|process|env|config|settings|options|params|context|request|response|example|sample|dummy|test)(?:[.:\[]|$)') { return $false }
  if ($candidate -match '[\s`$(){}\[\]]') { return $false }
  return $candidate -match '^[A-Za-z0-9_./+=:@~-]+$'
}

function Test-IsSensitiveCredentialName {
  param([AllowNull()][string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
  return $Name -match '(?i)(?:^|[_.-])(?:api[_-]?key|auth(?:orization)?[_-]?token|access[_-]?token|refresh[_-]?token|client[_-]?secret|secret(?:[_-]?key)?|password|credential)$' -or
    $Name -match '(?i)(?:ApiKey|AuthToken|AccessToken|RefreshToken|ClientSecret|SecretKey|Password|Credential)$'
}

function Add-JsonStringLeaves {
  param(
    [AllowNull()]$Value,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Target,
    [int]$Depth = 0
  )
  if ($null -eq $Value -or $Depth -gt 8) { return }
  if ($Value -is [string]) {
    if (-not [string]::IsNullOrWhiteSpace([string]$Value)) { $Target.Add([string]$Value) }
    return
  }
  if ($Value -is [System.Collections.IDictionary]) {
    foreach ($key in $Value.Keys) { Add-JsonStringLeaves -Value $Value[$key] -Target $Target -Depth ($Depth + 1) }
    return
  }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [pscustomobject]) {
    foreach ($item in $Value) { Add-JsonStringLeaves -Value $item -Target $Target -Depth ($Depth + 1) }
    return
  }
  foreach ($property in @($Value.PSObject.Properties)) {
    Add-JsonStringLeaves -Value $property.Value -Target $Target -Depth ($Depth + 1)
  }
}

function Get-JsonCredentialFinding {
  param(
    [AllowNull()]$Value,
    [int]$Depth = 0
  )
  if ($null -eq $Value -or $Depth -gt 8 -or $Value -is [string]) { return $null }

  if ($Value -is [System.Collections.IDictionary]) {
    foreach ($key in $Value.Keys) {
      $name = [string]$key
      $child = $Value[$key]
      if ((Test-IsSensitiveCredentialName $name) -and $child -is [string] -and (Test-IsPlausibleCredentialValue ([string]$child))) {
        return [pscustomobject]@{ Kind = 'sensitive_json_property' }
      }
      $nested = Get-JsonCredentialFinding -Value $child -Depth ($Depth + 1)
      if ($null -ne $nested) { return $nested }
    }
    return $null
  }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [pscustomobject]) {
    foreach ($child in $Value) {
      $nested = Get-JsonCredentialFinding -Value $child -Depth ($Depth + 1)
      if ($null -ne $nested) { return $nested }
    }
    return $null
  }
  foreach ($property in @($Value.PSObject.Properties)) {
    if ((Test-IsSensitiveCredentialName $property.Name) -and $property.Value -is [string] -and (Test-IsPlausibleCredentialValue ([string]$property.Value))) {
      return [pscustomobject]@{ Kind = 'sensitive_json_property' }
    }
    $nested = Get-JsonCredentialFinding -Value $property.Value -Depth ($Depth + 1)
    if ($null -ne $nested) { return $nested }
  }
  return $null
}

function Get-TextInspectionVariants {
  param([Parameter(Mandatory = $true)][string]$Content)
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $variants = New-Object System.Collections.Generic.List[string]
  [void]$seen.Add($Content)
  $variants.Add($Content)

  for ($round = 0; $round -lt 4; $round++) {
    $snapshot = @($variants.ToArray())
    foreach ($text in $snapshot) {
      try {
        $parsed = $text | ConvertFrom-Json
        if ($parsed -is [string]) {
          if ($seen.Add([string]$parsed)) { $variants.Add([string]$parsed) }
        } else {
          $leaves = New-Object System.Collections.Generic.List[string]
          Add-JsonStringLeaves -Value $parsed -Target $leaves
          foreach ($leaf in $leaves) { if ($seen.Add($leaf)) { $variants.Add($leaf) } }
        }
      } catch { }

      if ($text.IndexOf('\', [StringComparison]::Ordinal) -ge 0) {
        try {
          $decoded = [regex]::Unescape($text)
          if ($seen.Add($decoded)) { $variants.Add($decoded) }
        } catch { }
      }
    }
  }
  return $variants.ToArray()
}

function Get-ContentCredentialFinding {
  param([Parameter(Mandatory = $true)][string]$Content)
  $directTokenPattern = '(?i)(?:\bsk-(?:ant-|proj-|svcacct-)?[A-Za-z0-9_-]{20,}\b|\bAIza[0-9A-Za-z_-]{30,}\b|\bgh[pousr]_[0-9A-Za-z]{30,}\b|\bxox[baprs]-[0-9A-Za-z-]{20,}\b|\bAKIA[0-9A-Z]{16}\b)'
  $bearerPattern = '(?i)\bBearer[ \t]+(?<value>[A-Za-z0-9._~+/-]{20,}={0,2})'
  $assignmentPattern = '(?im)(?:^|[\s{,;])(?:["'']?)(?<name>[A-Za-z][A-Za-z0-9_.-]{1,100})(?:["'']?)\s*(?:=|:)\s*(?:["'']?)(?<value>[^\r\n"'',;\}\]]{1,4096})'

  foreach ($variant in @(Get-TextInspectionVariants -Content $Content)) {
    if ($variant -match $directTokenPattern) { return [pscustomobject]@{ Kind = 'provider_token' } }
    $bearer = [regex]::Match($variant, $bearerPattern)
    if ($bearer.Success -and (Test-IsPlausibleCredentialValue $bearer.Groups['value'].Value)) {
      return [pscustomobject]@{ Kind = 'bearer_token' }
    }
    foreach ($match in @([regex]::Matches($variant, $assignmentPattern))) {
      $assignmentName = $match.Groups['name'].Value
      $looksLikeConfigurationName = $assignmentName -match '[_-]' -or $assignmentName -cmatch '^[A-Z][A-Z0-9_]+$'
      if ($looksLikeConfigurationName -and (Test-IsSensitiveCredentialName $assignmentName) -and
          (Test-IsPlausibleCredentialValue $match.Groups['value'].Value)) {
        return [pscustomobject]@{ Kind = 'sensitive_assignment' }
      }
    }
    try {
      $parsed = $variant | ConvertFrom-Json
      $jsonFinding = Get-JsonCredentialFinding -Value $parsed
      if ($null -ne $jsonFinding) { return $jsonFinding }
    } catch { }
  }
  return $null
}

function Test-IsAllowedBlankDraftPath {
  param([Parameter(Mandatory = $true)][string]$NormalizedPath)
  if ([IO.Path]::GetFileName($NormalizedPath) -like '模板_*.md') { return $true }
  if ($NormalizedPath -match '(?i)(?:^|/)2_个人能力复利空间_首次选择这个文件夹/20_能力地图/主技能\.md$') { return $true }
  if ($NormalizedPath -match '(?i)(?:^|/)2_个人能力复利空间_首次选择这个文件夹/20_能力地图/能力维度/0[1-6]_维度[一二三四五六]\.md$') { return $true }
  return $false
}

function Get-ReleaseEntryFindings {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [AllowNull()][AllowEmptyString()][string]$Content
  )
  $findings = New-Object System.Collections.Generic.List[string]
  $rawNormalized = $RelativePath.Replace('\', '/')
  $normalized = $rawNormalized.TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized -match '(^|/)\.\.(/|$)' -or $rawNormalized.StartsWith('/')) {
    $findings.Add('路径越界或为空')
    return $findings.ToArray()
  }
  if ($normalized -match '(?i)(?:^|/)(?:sessions?|conversations?|chat-history|chat_history|backups?|备份)(?:/|$)' -or
      ($normalized -match '(?i)(?:^|/)\.claudian/' -and $normalized -notmatch '(?i)(?:^|/)\.claudian/claudian-settings\.json$')) {
    $findings.Add('会话或备份运行痕迹')
  }
  if ($normalized -match '(?i)(?:^|/)(?:fixtures?|test[-_ ]?(?:data|output)|测试数据|测试输出)(?:/|$)') {
    $findings.Add('测试数据或测试输出')
  }
  if ($normalized -match '(?i)(?:^|/)(?:\.ability-write|ability-write|write[-_ ]?batches?|pending[-_ ]?writes?|待执行写回|待确认批次)(?:/|$)' -or
      [IO.Path]::GetFileName($normalized) -match '(?i)(?:pending|待执行|待确认).*(?:batch|write|写回)') {
    $findings.Add('待执行写回批次')
  }

  $runtimePatterns = @(
    '/30_刻意练习/练习记录/', '/40_证据与反馈/证据记录/', '/40_证据与反馈/反馈记录/',
    '/50_能力复盘/复盘记录/', '/60_双工具交换/能力移交卡/', '/60_双工具交换/市场反馈/',
    '/90_现场草稿/', '/3_受控交换箱/capability_to_business/', '/3_受控交换箱/market_feedback_to_personal/'
  )
  foreach ($pattern in $runtimePatterns) {
    if (('/' + $normalized).IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and [IO.Path]::GetFileName($normalized) -ne 'README.md') {
      $findings.Add('用户草稿或运行数据')
      break
    }
  }

  if (-not [string]::IsNullOrEmpty($Content)) {
    $credential = Get-ContentCredentialFinding -Content $Content
    if ($null -ne $credential) { $findings.Add('非占位凭证') }

    $frontMatter = Get-FrontMatterData $Content
    if ($null -ne $frontMatter) {
      $status = Get-DataString $frontMatter 'record_status'
      if ($status -eq 'draft' -and -not (Test-IsAllowedBlankDraftPath -NormalizedPath $normalized)) {
        $findings.Add('非模板草稿记录')
      } elseif ($status -in @('confirmed', 'archived') -and $normalized -notmatch '(?i)(?:^|/)70_只读示例/') {
        $findings.Add('用户正式或历史记录')
      } elseif ($status -eq 'test') {
        $findings.Add('测试记录')
      }
      if ((Get-DataString $frontMatter 'test_fixture') -eq 'true') { $findings.Add('测试夹具记录') }
    }

    $extension = [IO.Path]::GetExtension($normalized)
    if ($extension -in @('.json', '.yaml', '.yml') -and
        $Content -match '(?i)ability-write\.v1' -and
        $Content -match '(?im)["'']?(?:status|batch_status)["'']?\s*[:=]\s*["'']?(?:pending|prepared|ready|awaiting_confirmation|待执行|待确认)') {
      $findings.Add('待执行写回批次')
    }
  }
  return @($findings | Sort-Object -Unique)
}

function ConvertFrom-ReleaseTextBytes {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)
  if ($Bytes.Length -eq 0) { return '' }
  try {
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
      return [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
      return [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
      return [Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    if ([Array]::IndexOf($Bytes, [byte]0) -ge 0) { return $null }
    return $script:Utf8Strict.GetString($Bytes)
  } catch { return $null }
}

function Get-ReleaseZipFindings {
  param([Parameter(Mandatory = $true)][string]$ZipPath)
  $findings = New-Object System.Collections.Generic.List[string]
  if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    $findings.Add('发布 ZIP 不存在')
    return $findings.ToArray()
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = $null
  try {
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    foreach ($entry in $archive.Entries) {
      if ([string]::IsNullOrWhiteSpace($entry.Name)) { continue }
      if ($entry.Length -gt 67108864) {
        $findings.Add("ZIP 文本候选条目异常过大：$($entry.FullName)")
        continue
      }
      $stream = $entry.Open()
      try {
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); $bytes = $memory.ToArray() } finally { $memory.Dispose() }
      } finally { $stream.Dispose() }
      $text = ConvertFrom-ReleaseTextBytes -Bytes $bytes
      foreach ($reason in @(Get-ReleaseEntryFindings -RelativePath $entry.FullName -Content $text)) {
        $findings.Add("$reason：$($entry.FullName)")
      }
    }
  } catch {
    $findings.Add("发布 ZIP 无法安全读取：$($_.Exception.Message)")
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
  }
  return $findings.ToArray()
}

function Test-ReleaseZipCleanliness {
  param([Parameter(Mandatory = $true)][string]$ZipPath)
  $zipFindings = @(Get-ReleaseZipFindings -ZipPath $ZipPath)
  foreach ($finding in $zipFindings) { Add-ValidationFailure $finding }
  if ($zipFindings.Count -eq 0) { Add-ValidationPass '发布 ZIP 全部文本条目、运行痕迹与凭证复检通过' }
}

function Add-RuntimeHygieneFinding {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [switch]$AsRelease
  )
  if ($AsRelease) { Add-ValidationFailure $Message }
  else { Add-ValidationWarning "$Message；当前运行副本可继续使用，但不可发布或回流永久空白母版" }
}

function Test-CredentialAndRuntimeCleanliness {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][object[]]$DeliverableFiles,
    [switch]$AsRelease
  )
  foreach ($file in $DeliverableFiles) {
    $relative = Get-RelativePath -Root $Root -Path $file.FullName
    if ($file.Extension -in @('.exe', '.msi', '.msix', '.appx', '.appinstaller', '.dmg', '.deb')) {
      Add-ValidationFailure "交付物捆绑了可执行安装包：$relative"
    }
    if ($file.Name -match '^(obsidian|claude)(?:\.exe|\.cmd|\.bat|\.com)$') {
      Add-ValidationFailure "交付物捆绑了 Obsidian/Claude 可执行文件：$relative"
    }
    if ($file.Name -match '^(\.env(?:\..*)?|credentials?\..*|secrets?\..*|.*session.*\.json|.*conversation.*\.json)$') {
      Add-RuntimeHygieneFinding -Message "发现本机凭证或会话文件：$relative" -AsRelease:$AsRelease
    }
  }
  $textExtensions = @('.md', '.txt', '.json', '.ps1', '.psm1', '.cmd', '.js', '.css')
  foreach ($file in @($DeliverableFiles | Where-Object { $_.Extension -in $textExtensions })) {
    $relative = Get-RelativePath -Root $Root -Path $file.FullName
    try { $content = Read-Utf8Text $file.FullName } catch { Add-ValidationFailure $_.Exception.Message; continue }
    $credentialFinding = Get-ContentCredentialFinding -Content $content
    if ($null -ne $credentialFinding) {
      Add-RuntimeHygieneFinding -Message "发现本机非占位凭证配置：$relative" -AsRelease:$AsRelease
    }
    if ($AsRelease) {
      foreach ($reason in @(Get-ReleaseEntryFindings -RelativePath $relative -Content $content)) {
        if ($reason -ne '非占位凭证') { Add-ValidationFailure "$reason：$relative" }
      }
    } else {
      foreach ($reason in @(Get-ReleaseEntryFindings -RelativePath $relative -Content $content)) {
        if ($reason -in @('会话或备份运行痕迹', '待执行写回批次')) {
          Add-RuntimeHygieneFinding -Message "$reason：$relative"
        }
      }
    }
  }

  foreach ($directory in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -Directory | Where-Object {
    $_.Name -match '^(sessions?|conversations?|chat-history|backups?|备份)$'
  })) {
    $relative = Get-RelativePath -Root $Root -Path $directory.FullName
    $containsFiles = @(Get-ChildItem -LiteralPath $directory.FullName -Recurse -Force -File -ErrorAction SilentlyContinue).Count -gt 0
    if ($containsFiles -and $relative -notmatch '^_prototype\\' -and $relative -notmatch '^设计参考\\') {
      Add-RuntimeHygieneFinding -Message "发现会话或备份目录：$relative" -AsRelease:$AsRelease
    }
  }
}

function Test-ReleaseBlankness {
  param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Vault,
    [Parameter(Mandatory = $true)][object[]]$Records
  )
  $manifestPath = Join-Path $Package 'ROOT_PRODUCT.md'
  $manifest = Get-FrontMatterData (Read-Utf8Text $manifestPath)
  if ((Get-DataString $manifest 'artifact_role') -ne 'canonical_blank_master') { Add-ValidationFailure 'ROOT_PRODUCT.md 不是 canonical_blank_master' }
  if ((Get-DataString $manifest 'contains_user_data') -ne 'false') { Add-ValidationFailure 'ROOT_PRODUCT.md 未声明 contains_user_data: false' }

  $confirmed = @($Records | Where-Object { (Get-DataString $_.Data 'record_status') -eq 'confirmed' })
  if ($confirmed.Count -gt 0) { Add-ValidationFailure "发布母版含 $($confirmed.Count) 条 confirmed 用户数据" }
  $nonDemoArchived = @($Records | Where-Object { -not $_.IsDemo -and (Get-DataString $_.Data 'record_status') -eq 'archived' })
  if ($nonDemoArchived.Count -gt 0) { Add-ValidationFailure '发布母版含历史归档记录' }

  $runtimeDirectories = @(
    '30_刻意练习\练习记录', '40_证据与反馈\证据记录', '40_证据与反馈\反馈记录',
    '50_能力复盘\复盘记录', '60_双工具交换\能力移交卡', '60_双工具交换\市场反馈', '90_现场草稿'
  )
  foreach ($relative in $runtimeDirectories) {
    $directory = Join-Path $Vault $relative
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { Add-ValidationFailure "缺少运行目录：$relative"; continue }
    $unexpected = @(Get-ChildItem -LiteralPath $directory -Recurse -Force -File | Where-Object { $_.Name -ne 'README.md' })
    foreach ($file in $unexpected) { Add-ValidationFailure "发布母版含运行数据：$(Get-RelativePath -Root $Vault -Path $file.FullName)" }
  }

  foreach ($exchangeRelative in @('3_受控交换箱\capability_to_business', '3_受控交换箱\market_feedback_to_personal')) {
    $directory = Join-Path $Package $exchangeRelative
    $unexpected = @(Get-ChildItem -LiteralPath $directory -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'README.md' })
    foreach ($file in $unexpected) { Add-ValidationFailure "发布母版交换箱含运行卡片：$(Get-RelativePath -Root $Package -Path $file.FullName)" }
  }

  $preview = Read-Utf8Text (Join-Path $Vault '80_AI能力教练\写回预览.md')
  if ($preview -notmatch '当前没有待确认的(?:写回|高影响变更)') { Add-ValidationFailure '写回预览中仍有待执行内容' }
  $audit = Read-Utf8Text (Join-Path $Vault '80_AI能力教练\已确认写回记录.md')
  if ($audit -match '(?m)^##\s+20\d{2}-') { Add-ValidationFailure '已确认写回记录未清空' }
}

function Test-ReleaseVaultFileWhitelist {
  param([Parameter(Mandatory = $true)][string]$Vault)
  $allowed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($relative in @(
    'AGENTS.md', 'CLAUDE.md',
    '00_开始这里\首页.md',
    '10_使用说明\README.md', '10_使用说明\01_数据与统计规则.md', '10_使用说明\02_六维与证据状态.md',
    '10_使用说明\03_AI确认与离线草稿.md', '10_使用说明\04_隐私与专业边界.md',
    '20_能力地图\README.md', '20_能力地图\主技能.md',
    '20_能力地图\能力维度\01_维度一.md', '20_能力地图\能力维度\02_维度二.md', '20_能力地图\能力维度\03_维度三.md',
    '20_能力地图\能力维度\04_维度四.md', '20_能力地图\能力维度\05_维度五.md', '20_能力地图\能力维度\06_维度六.md',
    '30_刻意练习\README.md', '30_刻意练习\模板_练习记录.md', '30_刻意练习\练习记录\README.md',
    '40_证据与反馈\README.md', '40_证据与反馈\模板_证据记录.md', '40_证据与反馈\模板_外部反馈.md',
    '40_证据与反馈\证据记录\README.md', '40_证据与反馈\反馈记录\README.md',
    '50_能力复盘\README.md', '50_能力复盘\模板_能力复盘.md', '50_能力复盘\复盘记录\README.md',
    '60_双工具交换\README.md', '60_双工具交换\模板_能力移交卡.md', '60_双工具交换\模板_市场反馈.md',
    '60_双工具交换\能力移交卡\README.md', '60_双工具交换\市场反馈\README.md',
    '70_只读示例\README.md',
    '80_AI能力教练\README.md', '80_AI能力教练\AI接手索引.md', '80_AI能力教练\能力教练铁律.md',
    '80_AI能力教练\数据字典与写回白名单.md', '80_AI能力教练\证据状态判定.md', '80_AI能力教练\对话与确认协议.md',
    '80_AI能力教练\命令入口.md', '80_AI能力教练\写回预览.md', '80_AI能力教练\已确认写回记录.md',
    '90_现场草稿\README.md',
    '.claude\settings.json', '.claude\hooks\guard-write.ps1',
    '.claude\hooks\ability-write-core.ps1', '.claude\hooks\ability-write.ps1',
    '.claude\hooks\ability-write-usage.md', '.claude\hooks\test-ability-write.ps1', '.claude\write-queue\README.md',
    '.claudian\claudian-settings.json',
    '.obsidian\app.json', '.obsidian\appearance.json', '.obsidian\community-plugins.json', '.obsidian\core-plugins.json', '.obsidian\workspace.json',
    '.obsidian\snippets\ability-cockpit.css',
    'assets\brand\crystal-logo.png', 'assets\demo\coffee-evidence.png', 'assets\decor\binder-rings.png', 'assets\decor\brass-clips.png',
    'assets\textures\paper-warm.png', 'assets\textures\navy-bookcloth.png'
  )) { [void]$allowed.Add($relative) }
  foreach ($name in @('skill-start', 'practice-plan', 'practice-close', 'evidence-add', 'skill-review', 'ability-transfer', 'feedback-return')) {
    [void]$allowed.Add(".claude\commands\$name.md")
    [void]$allowed.Add("80_AI能力教练\命令\$name.md")
  }
  foreach ($plugin in @('dataview', 'homepage', 'realclaudian')) {
    foreach ($name in @('manifest.json', 'main.js', 'styles.css', 'data.json')) { [void]$allowed.Add(".obsidian\plugins\$plugin\$name") }
  }

  foreach ($file in @(Get-ChildItem -LiteralPath $Vault -Recurse -Force -File)) {
    $relative = Get-RelativePath -Root $Vault -Path $file.FullName
    if ($allowed.Contains($relative)) { continue }
    if ($relative.StartsWith('70_只读示例\', [StringComparison]::OrdinalIgnoreCase)) {
      if ($file.Name -eq 'README.md') { continue }
      if ($file.Extension -eq '.md') {
        $data = Get-FrontMatterData (Read-Utf8Text $file.FullName)
        if ($null -ne $data -and (Get-DataString $data 'record_status') -eq 'demo') { continue }
      }
    }
    Add-ValidationFailure "发布能力空间含不在净包白名单中的文件：$relative"
  }
}

function Invoke-AbilityPackageValidation {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [switch]$AsRelease,
    [switch]$DoSkipExchangeTests
  )
  $package = Get-NormalizedPath $Root
  if (-not (Test-Path -LiteralPath $package -PathType Container)) { Add-ValidationFailure "产品根目录不存在：$package"; return }
  $vault = Join-Path $package '2_个人能力复利空间_首次选择这个文件夹'

  $requiredRoot = @(
    '0_先看我_双驾驶舱三步开始.txt', 'README.md', 'ROOT_PRODUCT.md', '版本信息与校验.txt', '1_打开个人能力复利驾驶舱.cmd',
    '3_检查能力驾驶舱.cmd', '4_备份我的能力数据.cmd', 'LICENSES\插件来源.md',
    '_tools\open-vault.ps1', '_tools\backup-data.ps1', '_tools\validate-package.ps1',
    '_tools\exchange-card.ps1', '_tools\ExchangeContract.psm1', '3_受控交换箱\exchange.json',
    '2_打开一人公司商业运营驾驶舱.cmd', '6_检查商业驾驶舱.cmd', '7_备份我的经营数据.cmd',
    '_tools\open-business-vault.ps1', '_tools\validate-business-package.ps1', '_tools\backup-business-data.ps1',
    '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\_tools\validate-package.ps1',
    '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\1_打开一人公司经营驾驶舱.cmd',
    '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\3_检查驾驶舱.cmd',
    '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\4_备份我的经营数据.cmd'
  )
  $requiredVault = @(
    '00_开始这里\首页.md', '20_能力地图\主技能.md', '20_能力地图\能力维度',
    '30_刻意练习\练习记录', '40_证据与反馈\证据记录', '40_证据与反馈\反馈记录',
    '50_能力复盘\复盘记录', '60_双工具交换\能力移交卡', '60_双工具交换\市场反馈',
    '70_只读示例\咖啡师', '70_只读示例\厨师', '70_只读示例\中医从业者',
    '80_AI能力教练\能力教练铁律.md', '90_现场草稿\README.md',
    '.claude\settings.json', '.claude\hooks\guard-write.ps1',
    '.claude\hooks\ability-write-core.ps1', '.claude\hooks\ability-write.ps1',
    '.claude\hooks\ability-write-usage.md', '.claude\hooks\test-ability-write.ps1', '.claude\write-queue\README.md',
    'assets\brand\crystal-logo.png', 'assets\textures\paper-warm.png', 'assets\textures\navy-bookcloth.png',
    'assets\demo\coffee-evidence.png', 'assets\decor\binder-rings.png', 'assets\decor\brass-clips.png',
    '.obsidian\snippets\ability-cockpit.css', '.claudian\claudian-settings.json'
  )
  foreach ($relative in $requiredRoot) { if (-not (Test-Path -LiteralPath (Join-Path $package $relative))) { Add-ValidationFailure "缺少必需文件：$relative" } }
  foreach ($relative in $requiredVault) { if (-not (Test-Path -LiteralPath (Join-Path $vault $relative))) { Add-ValidationFailure "能力空间缺少：$relative" } }
  if ($script:Failures.Count -gt 0 -and -not (Test-Path -LiteralPath $vault -PathType Container)) { return }

  $deliverableFiles = @(Get-DeliverableFiles -Root $package)
  Test-JsonFiles -Files $deliverableFiles
  Test-ReleaseManifest -Package $package -DeliverableFiles $deliverableFiles
  Test-PluginIntegrity -Package $package -Vault $vault
  $communityPath = Join-Path $vault '.obsidian\community-plugins.json'
  try {
    $parsedPlugins = (Read-Utf8Text $communityPath) | ConvertFrom-Json
    $enabledPlugins = @($parsedPlugins | ForEach-Object { [string]$_ } | Sort-Object)
    if (($enabledPlugins -join ',') -ne 'dataview,homepage,realclaudian') { Add-ValidationFailure "启用插件必须且只能是已核验的 dataview、homepage、realclaudian：$($enabledPlugins -join ', ')" }
  } catch { Add-ValidationFailure '.obsidian\community-plugins.json 无法解析' }

  $commands = @('skill-start', 'practice-plan', 'practice-close', 'evidence-add', 'skill-review', 'ability-transfer', 'feedback-return')
  foreach ($name in $commands) {
    $path = Join-Path $vault ".claude\commands\$name.md"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-ValidationFailure "缺少 AI 命令：/$name" }
  }
  Test-AbilityWriterIntegrity -Vault $vault -AsRelease:$AsRelease

  $records = @(Get-AbilityRecords -VaultRoot $vault)
  foreach ($errorMessage in @(Get-AbilityModelErrors -Records $records)) { Add-ValidationFailure $errorMessage }
  Test-LocalEvidenceAssets -Vault $vault -Records $records

  $dimensionDirectory = Join-Path $vault '20_能力地图\能力维度'
  $dimensions = @(Get-ChildItem -LiteralPath $dimensionDirectory -Force -Filter '*.md' -File | ForEach-Object {
    $data = Get-FrontMatterData (Read-Utf8Text $_.FullName)
    if ($null -ne $data -and (Get-DataString $data 'record_type') -eq 'skill_dimension') {
      [pscustomobject]@{ File = $_; Data = $data }
    }
  })
  if ($dimensions.Count -ne 6) { Add-ValidationFailure "能力空间必须固定六个维度槽位，当前为 $($dimensions.Count) 个" }
  $orders = @($dimensions | ForEach-Object { [int](Get-DataString $_.Data 'dimension_order') } | Sort-Object)
  if (($orders -join ',') -ne '1,2,3,4,5,6') { Add-ValidationFailure '六维 dimension_order 必须恰好为 1–6' }
  foreach ($dimension in $dimensions) {
    if ([string]::IsNullOrWhiteSpace((Get-DataString $dimension.Data 'dimension_name'))) { Add-ValidationFailure "六维名称为空：$($dimension.File.Name)" }
  }

  $homePath = Join-Path $vault '00_开始这里\首页.md'
  $homeContent = Read-Utf8Text $homePath
  if ($homeContent -notmatch 'record_status\s*===\s*["'']confirmed["'']') { Add-ValidationFailure '首页没有把 confirmed 作为统计入口门' }
  if ([regex]::Matches($homeContent, 'confirmed\(page\)').Count -lt 6) { Add-ValidationFailure '首页存在未经过 confirmed 门的主要统计集合' }
  if ($homeContent -match 'dv\.pages\([^\r\n]*70_只读示例') { Add-ValidationFailure '首页直接查询了只读示例目录' }
  if ($homeContent -notmatch 'evidence_validity' -or $homeContent -notmatch 'supersedes_evidence_id') { Add-ValidationFailure '首页没有同时过滤失效证据与被新版本取代的旧证据' }
  if ($homeContent -notmatch 'conclusion_status') { Add-ValidationFailure '首页复盘结论没有显式限定 current 版本' }

  Test-TcmDemoSafety -Vault $vault
  Test-ObsidianBaseline -Vault $vault -AsRelease:$AsRelease
  Test-CredentialAndRuntimeCleanliness -Root $package -DeliverableFiles $deliverableFiles -AsRelease:$AsRelease
  if (-not $SkipBusinessValidation) { Invoke-EmbeddedBusinessValidation -Package $package -AsRelease:$AsRelease }

  if ($AsRelease) {
    Test-ReleaseBlankness -Package $package -Vault $vault -Records $records
    Test-ReleaseVaultFileWhitelist -Vault $vault
    $demoRecords = @($records | Where-Object { $_.IsDemo })
    $demoSkillIds = @($demoRecords | ForEach-Object { Get-DataString $_.Data 'skill_id' } | Sort-Object -Unique)
    if ($demoRecords.Count -ne 33 -or ($demoSkillIds -join ',') -ne 'demo-chef,demo-coffee,demo-tcm-learning') { Add-ValidationFailure '发布包只允许内置咖啡师、厨师、中医从业者三套共 33 条 demo 记录' }
    $profileData = Get-FrontMatterData (Read-Utf8Text (Join-Path $vault '20_能力地图\主技能.md'))
    if ((Get-DataString $profileData 'record_status') -ne 'draft' -or (Get-DataString $profileData 'status') -ne 'inactive') { Add-ValidationFailure '发布母版主技能必须保持 draft + inactive' }
    foreach ($field in @('record_id', 'skill_id')) {
      if (-not [string]::IsNullOrWhiteSpace((Get-DataString $profileData $field))) { Add-ValidationFailure "发布母版主技能 $field 必须为空" }
    }
    foreach ($dimension in $dimensions) {
      if ((Get-DataString $dimension.Data 'record_status') -ne 'draft' -or (Get-DataString $dimension.Data 'evidence_state') -ne 'unproven') { Add-ValidationFailure "发布母版维度必须保持 draft + unproven：$($dimension.File.Name)" }
      foreach ($field in @('record_id', 'skill_id', 'dimension_id')) {
        if (-not [string]::IsNullOrWhiteSpace((Get-DataString $dimension.Data $field))) { Add-ValidationFailure "发布母版维度 $field 必须为空：$($dimension.File.Name)" }
      }
      if (@(Get-DataArray $dimension.Data 'evidence_refs').Count -gt 0) { Add-ValidationFailure "发布母版维度 evidence_refs 必须为空：$($dimension.File.Name)" }
    }
  }

  if (-not $DoSkipExchangeTests) {
    $exchangeTest = Join-Path $package '_tools\test-exchange-contract.ps1'
    $exchangeFixture = Join-Path $package '_tools\fixtures\exchange\valid-capability-transfer.md'
    if ((Test-Path -LiteralPath $exchangeTest -PathType Leaf) -and (Test-Path -LiteralPath $exchangeFixture -PathType Leaf)) {
      $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $exchangeTest 2>&1
      if ($LASTEXITCODE -ne 0) { Add-ValidationFailure "受控交换协议测试失败：$($output -join ' | ')" }
      else { Add-ValidationPass '受控交换协议测试通过' }
    } elseif (Test-Path -LiteralPath (Join-Path $package '发布文件清单_SHA256.txt') -PathType Leaf) {
      Add-ValidationPass '发布净包按设计省略交换测试 fixtures（发布前回归已完成）'
    } else { Add-ValidationWarning '当前目录不含交换测试 fixtures，已跳过受控交换协议回归测试。' }
  }

  if ($script:Failures.Count -eq 0) {
    Add-ValidationPass '必需文件、数据模型、插件资产、隐私边界与净包规则通过'
    $stats = Get-AbilityStatistics -Records $records
    if ($stats.ConfirmedTotal -ne 0 -and $AsRelease) { Add-ValidationFailure '发布统计意外包含 confirmed 记录' }
  }
}

if (-not $LibraryMode) {
  try {
    if ($ZipOnly) {
      if (-not $ReleaseMode) { Add-ValidationFailure 'ZipOnly 只能与 ReleaseMode 一起使用' }
      elseif ([string]::IsNullOrWhiteSpace($ReleaseZipPath)) { Add-ValidationFailure 'ZipOnly 缺少 ReleaseZipPath' }
      else { Test-ReleaseZipCleanliness -ZipPath $ReleaseZipPath }
    } else {
      Invoke-AbilityPackageValidation -Root $PackageRoot -AsRelease:$ReleaseMode -DoSkipExchangeTests:$SkipExchangeTests
      if (-not [string]::IsNullOrWhiteSpace($ReleaseZipPath)) {
        if (-not $ReleaseMode) { Add-ValidationFailure 'ReleaseZipPath 只能与 ReleaseMode 一起使用' }
        else { Test-ReleaseZipCleanliness -ZipPath $ReleaseZipPath }
      }
    }
  } catch {
    Add-ValidationFailure "校验器异常：$($_.Exception.Message)"
  }

  if (-not $Quiet) {
    Write-Host ''
    foreach ($warning in $script:Warnings) { Write-Host "WARN  $warning" -ForegroundColor Yellow }
    foreach ($failure in $script:Failures) { Write-Host "FAIL  $failure" -ForegroundColor Red }
    Write-Host ''
    Write-Host ("校验结果：{0} 项通过，{1} 项警告，{2} 项失败。模式：{3}" -f $script:PassCount, $script:Warnings.Count, $script:Failures.Count, $(if ($ReleaseMode) { 'Release' } else { 'Normal' }))
  }
  if ($script:Failures.Count -gt 0) { exit 1 }
  exit 0
}
