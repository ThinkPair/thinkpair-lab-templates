$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:AbilityUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:AbilityStates = @('unproven', 'observed', 'repeatable', 'externally_validated', 'transfer_ready')
$script:AbilityCommands = @('skill-start', 'practice-plan', 'practice-close', 'evidence-add', 'skill-review', 'ability-transfer', 'feedback-return', 'system-control')

function Get-AbilitySha256Text {
  param([AllowEmptyString()][string]$Text)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($script:AbilityUtf8NoBom.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Get-AbilityProperty {
  param($Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Normalize-AbilityRelativePath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path)) { throw '路径必须是空间内相对路径。' }
  $normalized = $Path.Replace('\', '/').TrimStart('/')
  if ($normalized -match '(^|/)\.\.(/|$)' -or $normalized -match '(^|/)\.(/|$)' -or $normalized.Contains([char]0)) { throw '路径包含越界或无效片段。' }
  return $normalized
}

function Resolve-AbilityTargetPath {
  param([string]$Root, [string]$RelativePath)
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $relative = Normalize-AbilityRelativePath $RelativePath
  $target = [IO.Path]::GetFullPath((Join-Path $rootFull $relative.Replace('/', '\')))
  $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw '目标越出当前能力空间。' }
  return $target
}

function Test-AbilityAllowedDataPath {
  param([string]$RelativePath)
  $p = Normalize-AbilityRelativePath $RelativePath
  if ($p -eq '20_能力地图/主技能.md') { return $true }
  if ($p -match '^20_能力地图/能力维度/0[1-6]_维度[一二三四五六]\.md$') { return $true }
  if ($p -match '^30_刻意练习/练习记录/(?!README|模板|template)[^/]+\.md$') { return $true }
  if ($p -match '^40_证据与反馈/(?:证据记录|反馈记录)/(?!README|模板|template)[^/]+\.md$') { return $true }
  if ($p -match '^50_能力复盘/复盘记录/(?!README|模板|template)[^/]+\.md$') { return $true }
  if ($p -match '^60_双工具交换/(?:能力移交卡|市场反馈)/(?!README|模板|template)[^/]+\.md$') { return $true }
  if ($p -in @('80_AI能力教练/写回预览.md', '80_AI能力教练/已确认写回记录.md')) { return $true }
  if ($p -match '^90_现场草稿/(?!README|模板|template)[^/]+\.md$') { return $true }
  return $false
}

function Get-AbilityFrontmatter {
  param([string]$Content)
  $match = [regex]::Match($Content, '(?s)\A\uFEFF?---\s*\r?\n(.*?)\r?\n---(?:\r?\n|\z)')
  if (-not $match.Success) { return $null }
  return $match.Groups[1].Value
}

function Get-AbilityField {
  param([string]$Content, [string]$Name)
  $fm = Get-AbilityFrontmatter $Content
  if ($null -eq $fm) { return $null }
  $match = [regex]::Match($fm, '(?m)^\s*' + [regex]::Escape($Name) + '\s*:\s*(.*?)\s*$')
  if (-not $match.Success) { return $null }
  $value = $match.Groups[1].Value.Trim()
  if ($value -in @('null', '~')) { return $null }
  if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
    try { return [string]($value | ConvertFrom-Json) } catch { return $value.Substring(1, $value.Length - 2) }
  }
  if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) { return $value.Substring(1, $value.Length - 2).Replace("''", "'") }
  return $value
}

function Resolve-AbilityAutoNowContent {
  param(
    [string]$Root,
    [string]$Path,
    [ValidateSet('create','update')][string]$Action,
    [string]$Content,
    [string]$Now = ([DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz'))
  )
  $autoPattern = '(?m)^(\s*{0}\s*:\s*)(?:"AUTO_NOW"|''AUTO_NOW''|AUTO_NOW)\s*$'
  $resolved = [regex]::Replace($Content, ($autoPattern -f 'updated_at'), { param($m) $m.Groups[1].Value + '"' + $Now + '"' })
  if ($Action -eq 'create') {
    $resolved = [regex]::Replace($resolved, ($autoPattern -f 'created_at'), { param($m) $m.Groups[1].Value + '"' + $Now + '"' })
  } elseif ($resolved -match ($autoPattern -f 'created_at')) {
    $target = Resolve-AbilityTargetPath $Root $Path
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'update 使用 AUTO_NOW 时找不到原记录。' }
    $oldCreated = Get-AbilityField ([IO.File]::ReadAllText($target, $script:AbilityUtf8NoBom)) 'created_at'
    if ([string]::IsNullOrWhiteSpace($oldCreated)) { $oldCreated = $Now }
    $resolved = [regex]::Replace($resolved, ($autoPattern -f 'created_at'), { param($m) $m.Groups[1].Value + '"' + $oldCreated + '"' })
  }
  return $resolved
}

function Get-AbilityList {
  param([string]$Content, [string]$Name)
  $fm = Get-AbilityFrontmatter $Content
  if ($null -eq $fm) { return @() }
  $scalar = Get-AbilityField $Content $Name
  if ($null -ne $scalar -and $scalar -match '^\[(.*)\]$') {
    $inside = $Matches[1].Trim()
    if ([string]::IsNullOrWhiteSpace($inside)) { return @() }
    return @(($inside -split ',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  $lines = $fm -split '\r?\n'
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*' + [regex]::Escape($Name) + '\s*:\s*$') { $start = $i; break } }
  if ($start -lt 0) { return @() }
  $items = New-Object System.Collections.Generic.List[string]
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s+-\s+(.*?)\s*$') { $items.Add($Matches[1].Trim().Trim('"').Trim("'")); continue }
    if ($lines[$i] -match '^\S') { break }
  }
  return $items.ToArray()
}

function Get-AbilityExpectedType {
  param([string]$Path)
  if ($Path -eq '20_能力地图/主技能.md') { return 'skill_profile' }
  if ($Path -match '^20_能力地图/能力维度/') { return 'skill_dimension' }
  if ($Path -match '^30_刻意练习/练习记录/') { return 'practice_record' }
  if ($Path -match '^40_证据与反馈/') { return 'evidence_item' }
  if ($Path -match '^50_能力复盘/复盘记录/') { return 'skill_review' }
  if ($Path -match '^60_双工具交换/能力移交卡/') { return 'capability_transfer' }
  if ($Path -match '^60_双工具交换/市场反馈/') { return 'market_feedback' }
  if ($Path -match '^90_现场草稿/') { return 'field_draft' }
  return $null
}

function Test-AbilityTimestamp {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  $parsed = [DateTimeOffset]::MinValue
  return [DateTimeOffset]::TryParse($Value, [ref]$parsed)
}

function Get-AbilityRecordErrors {
  param([string]$Path, [string]$Content, [AllowNull()][string]$OldContent)
  $errors = New-Object System.Collections.Generic.List[string]
  if ($Path -eq '80_AI能力教练/写回预览.md') { if ($Content -notmatch '#\s*(?:待确认写回预览|写回预览)') { $errors.Add('写回预览控制页缺少标题。') }; return $errors.ToArray() }
  if ($Path -eq '80_AI能力教练/已确认写回记录.md') { if ($Content -notmatch '#\s*已确认写回记录') { $errors.Add('写回审计页缺少标题。') }; return $errors.ToArray() }
  $expected = Get-AbilityExpectedType $Path
  if ($null -eq $expected) { $errors.Add('目标目录没有对应记录类型。'); return $errors.ToArray() }
  if ($null -eq (Get-AbilityFrontmatter $Content)) { $errors.Add('记录缺少 YAML frontmatter。'); return $errors.ToArray() }
  $type = Get-AbilityField $Content 'record_type'
  if ($type -ne $expected) { $errors.Add('record_type 与目标目录不匹配。') }
  $required = if ($type -eq 'field_draft') { @('record_id','record_type','record_status','created_at','updated_at','privacy','schema_version') } else { @('record_id','record_type','skill_id','record_status','created_at','updated_at','privacy','schema_version') }
  foreach ($name in $required) { if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content $name))) { $errors.Add("缺少必填字段：$name。") } }
  $status = Get-AbilityField $Content 'record_status'
  if ($status -notin @('draft','confirmed','archived')) { $errors.Add('record_status 非法或 demo 写入被禁止。') }
  $privacy = Get-AbilityField $Content 'privacy'
  if ($privacy -notin @('private','sensitive','shareable')) { $errors.Add('privacy 必须是 private、sensitive 或 shareable。') }
  if (-not (Test-AbilityTimestamp (Get-AbilityField $Content 'created_at'))) { $errors.Add('created_at 必须是有效时间。') }
  if (-not (Test-AbilityTimestamp (Get-AbilityField $Content 'updated_at'))) { $errors.Add('updated_at 必须是有效时间。') }
  if ($type -notin @('capability_transfer','market_feedback') -and $type -ne 'field_draft' -and (Get-AbilityField $Content 'schema_version') -ne 'ability.v1') { $errors.Add('能力记录 schema_version 必须是 ability.v1。') }
  if ($type -eq 'field_draft') {
    if ($status -ne 'draft' -or (Get-AbilityField $Content 'excluded_from_statistics') -ne 'true') { $errors.Add('现场草稿必须保持 draft 且不进入统计。') }
  }
  if ($type -eq 'skill_profile') {
    if ((Get-AbilityField $Content 'status') -notin @('active','inactive')) { $errors.Add('主技能 status 非法。') }
    if ((Get-AbilityField $Content 'dimension_count') -ne '6') { $errors.Add('主技能固定为六维。') }
    if ((Get-AbilityField $Content 'ability_version') -notmatch '^v\d+\.\d+$') { $errors.Add('ability_version 格式非法。') }
  }
  if ($type -eq 'skill_dimension') {
    if ((Get-AbilityField $Content 'dimension_order') -notin @('1','2','3','4','5','6')) { $errors.Add('dimension_order 必须为 1–6。') }
    if ((Get-AbilityField $Content 'evidence_state') -notin $script:AbilityStates) { $errors.Add('evidence_state 非法。') }
    if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'dimension_id'))) { $errors.Add('缺少 dimension_id。') }
  }
  if ($type -eq 'practice_record') {
    if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'practice_id'))) { $errors.Add('缺少 practice_id。') }
    if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'dimension_id'))) { $errors.Add('练习必须关联维度。') }
    if ((Get-AbilityField $Content 'practice_status') -notin @('planned','in_progress','closed')) { $errors.Add('practice_status 非法。') }
  }
  if ($type -eq 'evidence_item') {
    if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'evidence_id'))) { $errors.Add('缺少 evidence_id。') }
    if ((Get-AbilityField $Content 'evidence_validity') -notin @('current','superseded','withdrawn')) { $errors.Add('evidence_validity 非法。') }
    if ($Path -match '/反馈记录/' -and ((Get-AbilityField $Content 'evidence_type') -ne 'external_feedback' -or (Get-AbilityField $Content 'verification_level') -ne 'externally_provided')) { $errors.Add('反馈记录必须是可追溯的外部反馈。') }
  }
  if ($type -eq 'skill_review' -and [string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'review_id'))) { $errors.Add('缺少 review_id。') }
  if ($type -eq 'capability_transfer') {
    if ((Get-AbilityField $Content 'schema_version') -ne 'exchange.capability_transfer.v1') { $errors.Add('能力移交卡 schema 非法。') }
    if ($status -eq 'confirmed') {
      if ([string]::IsNullOrWhiteSpace((Get-AbilityField $Content 'user_confirmed_at'))) { $errors.Add('正式移交卡缺少 user_confirmed_at。') }
      if ((Get-AbilityField $Content 'content_hash') -notmatch '^[a-f0-9]{64}$') { $errors.Add('正式移交卡缺少合法内容哈希。') }
    }
  }
  if ($type -eq 'market_feedback') {
    if ((Get-AbilityField $Content 'schema_version') -ne 'exchange.market_feedback.v1') { $errors.Add('市场反馈 schema 非法。') }
    if ((Get-AbilityField $Content 'content_hash') -notmatch '^[a-f0-9]{64}$') { $errors.Add('市场反馈缺少合法来源哈希。') }
  }
  if ($type -in @('capability_transfer','market_feedback') -and $Content -match '(?i)(\b[A-Z]:\\|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|1[3-9]\d{9}|\d{17}[\dXx]|(?:客户|患者)(?:姓名|电话|手机|微信|身份证)|[￥¥]|(?:报价|回款|收入|利润|成本|价格|金额)\s*[:：]?\s*\d)') { $errors.Add('交换记录含本机路径、身份、联系方式或财务信息。') }
  if (-not [string]::IsNullOrEmpty($OldContent)) {
    $identity = @('record_type','record_id','skill_id','schema_version','created_at')
    if ($type -eq 'skill_dimension') { $identity += 'dimension_id' }
    if ($type -eq 'practice_record') { $identity += 'practice_id' }
    if ($type -eq 'evidence_item') { $identity += 'evidence_id' }
    if ($type -eq 'skill_review') { $identity += 'review_id' }
    if ($type -eq 'capability_transfer') { $identity += 'transfer_id' }
    if ($type -eq 'market_feedback') { $identity += @('feedback_id','source_transfer_id','source_transfer_hash','content_hash') }
    foreach ($name in $identity) {
      $before = Get-AbilityField $OldContent $name
      $after = Get-AbilityField $Content $name
      if (-not [string]::IsNullOrWhiteSpace($before) -and $before -ne $after) { $errors.Add("身份或来源字段初始化后不可修改：$name。") }
    }
    if ($type -eq 'market_feedback') {
      foreach ($name in @('feedback_summary','skill_gap','next_practice_candidate')) { if ((Get-AbilityField $OldContent $name) -ne (Get-AbilityField $Content $name)) { $errors.Add("导入后的市场反馈正文不可改写：$name。") } }
    }
    if ($type -eq 'capability_transfer' -and (Get-AbilityField $OldContent 'record_status') -eq 'confirmed' -and $OldContent -ne $Content) { $errors.Add('正式能力移交卡只读；请生成新版本。') }
  }
  return $errors.ToArray()
}

function Get-AbilityOperationMap {
  param([string]$Root, $Manifest)
  $map = @{}
  foreach ($op in @(Get-AbilityProperty $Manifest 'operations')) {
    $path = Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path'))
    $map[$path] = [string](Get-AbilityProperty $op 'content')
  }
  return $map
}

function Get-AbilityCurrentDataFiles {
  param([string]$Root)
  $result = @{}
  foreach ($dir in @('20_能力地图','30_刻意练习/练习记录','40_证据与反馈/证据记录','40_证据与反馈/反馈记录','50_能力复盘/复盘记录','60_双工具交换/能力移交卡','60_双工具交换/市场反馈','90_现场草稿')) {
    $full = Join-Path $Root $dir.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $full)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $full -Recurse -File -Filter '*.md') {
      $relative = $file.FullName.Substring(([IO.Path]::GetFullPath($Root).TrimEnd('\') + '\').Length).Replace('\','/')
      if (Test-AbilityAllowedDataPath $relative) { $result[$relative] = [IO.File]::ReadAllText($file.FullName, $script:AbilityUtf8NoBom) }
    }
  }
  return $result
}

function Get-AbilityModelErrors {
  param([string]$Root, $Manifest)
  $errors = New-Object System.Collections.Generic.List[string]
  $records = Get-AbilityCurrentDataFiles $Root
  foreach ($entry in (Get-AbilityOperationMap $Root $Manifest).GetEnumerator()) { if ((Get-AbilityExpectedType $entry.Key) -ne $null) { $records[$entry.Key] = $entry.Value } }
  $ids = @{}
  $main = $null
  $dimensions = New-Object System.Collections.Generic.List[object]
  $practices = New-Object System.Collections.Generic.List[object]
  $evidence = @{}
  foreach ($entry in $records.GetEnumerator()) {
    $content = [string]$entry.Value
    $id = Get-AbilityField $content 'record_id'
    if (-not [string]::IsNullOrWhiteSpace($id)) { if ($ids.ContainsKey($id)) { $errors.Add("record_id 重复：$id。") } else { $ids[$id] = $entry.Key } }
    $type = Get-AbilityField $content 'record_type'
    if ($type -eq 'skill_profile' -and (Get-AbilityField $content 'record_status') -eq 'confirmed' -and (Get-AbilityField $content 'status') -eq 'active') { if ($null -ne $main) { $errors.Add('同一时间只能有一个 active 主技能。') } else { $main = $content } }
    if ($type -eq 'skill_dimension' -and (Get-AbilityField $content 'record_status') -eq 'confirmed') { $dimensions.Add([pscustomobject]@{ Path=$entry.Key; Content=$content }) }
    if ($type -eq 'practice_record' -and (Get-AbilityField $content 'record_status') -eq 'confirmed') { $practices.Add([pscustomobject]@{ Path=$entry.Key; Content=$content }) }
    if ($type -eq 'evidence_item' -and (Get-AbilityField $content 'record_status') -eq 'confirmed' -and (Get-AbilityField $content 'evidence_validity') -eq 'current') { $evidence[(Get-AbilityField $content 'evidence_id')] = $content }
  }
  if ($null -ne $main) {
    $skillId = Get-AbilityField $main 'skill_id'
    $skillDimensions = @($dimensions | Where-Object { (Get-AbilityField $_.Content 'skill_id') -eq $skillId })
    if ($skillDimensions.Count -ne 6) { $errors.Add('active 主技能必须同时拥有六条 confirmed 维度。') }
    $orders = @($skillDimensions | ForEach-Object { Get-AbilityField $_.Content 'dimension_order' } | Select-Object -Unique)
    $dimensionIds = @($skillDimensions | ForEach-Object { Get-AbilityField $_.Content 'dimension_id' } | Select-Object -Unique)
    if ($orders.Count -ne 6 -or $dimensionIds.Count -ne 6) { $errors.Add('六维顺序和 dimension_id 必须唯一。') }
    foreach ($dimension in $skillDimensions) {
      $state = Get-AbilityField $dimension.Content 'evidence_state'
      $refs = @(Get-AbilityList $dimension.Content 'evidence_refs')
      if ($state -ne 'unproven') {
        $valid = @($refs | Where-Object { $evidence.ContainsKey($_) })
        if ($valid.Count -ne $refs.Count -or $valid.Count -eq 0) { $errors.Add("$($dimension.Path) 的能力状态缺少有效 confirmed 证据。") }
        if ($state -in @('repeatable','externally_validated','transfer_ready') -and $valid.Count -lt 2) { $errors.Add("$($dimension.Path) 尚无重复证据，不能进入 $state。") }
        if ($state -in @('externally_validated','transfer_ready')) {
          $external = @($valid | Where-Object { (Get-AbilityField $evidence[$_] 'evidence_type') -eq 'external_feedback' -and (Get-AbilityField $evidence[$_] 'verification_level') -eq 'externally_provided' })
          if ($external.Count -eq 0) { $errors.Add("$($dimension.Path) 缺少外部反馈证据。") }
        }
      }
    }
    $open = @($practices | Where-Object { (Get-AbilityField $_.Content 'skill_id') -eq $skillId -and (Get-AbilityField $_.Content 'practice_status') -in @('planned','in_progress') })
    $pointer = Get-AbilityField $main 'current_practice_id'
    if ($open.Count -gt 1) { $errors.Add('同一主技能只能有一个当前练习。') }
    if ([string]::IsNullOrWhiteSpace($pointer) -and $open.Count -gt 0) { $errors.Add('主技能未指向当前练习。') }
    if (-not [string]::IsNullOrWhiteSpace($pointer) -and @($open | Where-Object { (Get-AbilityField $_.Content 'practice_id') -eq $pointer }).Count -ne 1) { $errors.Add('current_practice_id 没有唯一对应的进行中练习。') }
    $version = Get-AbilityField $main 'ability_version'
    if ($version -ne 'v0.1') {
      $versionRefs = @(Get-AbilityList $main 'version_evidence_refs')
      if ($versionRefs.Count -eq 0 -or @($versionRefs | Where-Object { $evidence.ContainsKey($_) }).Count -ne $versionRefs.Count) { $errors.Add('能力版本变化必须引用有效证据。') }
    }
  }
  return $errors.ToArray()
}

function Get-AbilityPayloadHash {
  param($Manifest)
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('ability-write.v1')
  $lines.Add([string](Get-AbilityProperty $Manifest 'batch_id'))
  $lines.Add([string](Get-AbilityProperty $Manifest 'command'))
  foreach ($op in @((Get-AbilityProperty $Manifest 'operations') | Sort-Object { [string](Get-AbilityProperty $_ 'path') })) {
    $lines.Add(('{0}|{1}|{2}' -f ([string](Get-AbilityProperty $op 'action')), (Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path'))), ([string](Get-AbilityProperty $op 'content_sha256'))))
  }
  return Get-AbilitySha256Text ($lines -join "`n")
}

function Get-AbilityManifestEvaluation {
  param([string]$Root, $Manifest, [switch]$AllowAutoHash)
  $blocked = New-Object System.Collections.Generic.List[string]
  $confirm = New-Object System.Collections.Generic.List[string]
  if ((Get-AbilityProperty $Manifest 'schema_version') -ne 'ability-write.v1') { $blocked.Add('批次 schema_version 必须是 ability-write.v1。') }
  $batchId = [string](Get-AbilityProperty $Manifest 'batch_id')
  if ($batchId -notmatch '^wb-[A-Za-z0-9._-]{3,80}$') { $blocked.Add('batch_id 格式非法。') }
  $command = ([string](Get-AbilityProperty $Manifest 'command')).TrimStart('/')
  if ($command -notin $script:AbilityCommands) { $blocked.Add('命令不在能力工作流白名单。') }
  $operations = @(Get-AbilityProperty $Manifest 'operations')
  if ($operations.Count -lt 1 -or $operations.Count -gt 50) { $blocked.Add('每批必须包含 1–50 个操作。') }
  $seen = @{}
  $confirmedTouched = 0
  $initialSkill = $false
  foreach ($op in $operations) {
    try { $path = Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path')) } catch { $blocked.Add($_.Exception.Message); continue }
    if ($seen.ContainsKey($path)) { $blocked.Add("批次目标重复：$path。") } else { $seen[$path] = $true }
    if (-not (Test-AbilityAllowedDataPath $path)) { $blocked.Add("目标不在数据白名单：$path。") ; continue }
    $action = [string](Get-AbilityProperty $op 'action')
    if ($action -notin @('create','update')) { $blocked.Add("$path 的 action 必须是 create 或 update。") }
    $content = [string](Get-AbilityProperty $op 'content')
    if ([string]::IsNullOrWhiteSpace($content)) { $blocked.Add("$path 缺少完整目标内容。") ; continue }
    $hash = [string](Get-AbilityProperty $op 'content_sha256')
    if ($hash -in @('', 'AUTO') -and $AllowAutoHash) { } elseif ($hash -notmatch '^[a-f0-9]{64}$' -or $hash -ne (Get-AbilitySha256Text $content)) { $blocked.Add("$path 的内容哈希不匹配。") }
    $target = Resolve-AbilityTargetPath $Root $path
    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $old = if ($exists) { [IO.File]::ReadAllText($target, $script:AbilityUtf8NoBom) } else { $null }
    if ($action -eq 'create' -and $exists -and $old -ne $content) { $blocked.Add("create 目标已存在：$path。") }
    if ($action -eq 'update' -and -not $exists) { $blocked.Add("update 目标不存在：$path。") }
    $validationContent = $content
    if ($AllowAutoHash -and $content -match '(?m)^\s*(?:created_at|updated_at)\s*:\s*(?:"AUTO_NOW"|''AUTO_NOW''|AUTO_NOW)\s*$') {
      try { $validationContent = Resolve-AbilityAutoNowContent $Root $path $action $content }
      catch { $blocked.Add("$path：$($_.Exception.Message)") }
    }
    foreach ($error in @(Get-AbilityRecordErrors $path $validationContent $old)) { $blocked.Add("$path：$error") }
    $type = Get-AbilityField $validationContent 'record_type'
    $oldStatus = if ($null -eq $old) { $null } else { Get-AbilityField $old 'record_status' }
    $newStatus = Get-AbilityField $validationContent 'record_status'
    if ($oldStatus -eq 'confirmed' -or $newStatus -eq 'confirmed') { $confirmedTouched++ }
    if ($newStatus -eq 'archived' -and $oldStatus -ne 'archived') { $confirm.Add("归档记录：$path") }
    $privacyRank = @{ shareable=0; private=1; sensitive=2 }
    $oldPrivacy = if ($null -eq $old) { $null } else { Get-AbilityField $old 'privacy' }
    $newPrivacy = Get-AbilityField $validationContent 'privacy'
    if ($null -ne $oldPrivacy -and $privacyRank.ContainsKey($oldPrivacy) -and $privacyRank.ContainsKey($newPrivacy) -and $privacyRank[$newPrivacy] -lt $privacyRank[$oldPrivacy]) { $confirm.Add("降低隐私保护：$path") }
    if ($type -eq 'skill_profile') {
      $oldId = if ($null -eq $old) { '' } else { Get-AbilityField $old 'record_id' }
      if ([string]::IsNullOrWhiteSpace($oldId) -and $newStatus -eq 'confirmed' -and (Get-AbilityField $validationContent 'status') -eq 'active') { $initialSkill = $true }
      elseif ($null -ne $old) {
        if ((Get-AbilityField $old 'skill_name') -ne (Get-AbilityField $validationContent 'skill_name')) { $confirm.Add('替换当前主技能') }
        if ((Get-AbilityField $old 'ability_version') -ne (Get-AbilityField $validationContent 'ability_version')) { $confirm.Add('改变能力版本') }
      }
    }
    if ($type -eq 'skill_dimension' -and $null -ne $old -and -not [string]::IsNullOrWhiteSpace((Get-AbilityField $old 'record_id')) -and (Get-AbilityField $old 'evidence_state') -ne (Get-AbilityField $validationContent 'evidence_state')) {
      $oldState = Get-AbilityField $old 'evidence_state'
      $newState = Get-AbilityField $validationContent 'evidence_state'
      $oldRank = [array]::IndexOf($script:AbilityStates, $oldState)
      $newRank = [array]::IndexOf($script:AbilityStates, $newState)
      if ($oldRank -ge 0 -and $newRank -gt ($oldRank + 1)) { $blocked.Add("证据状态只能逐级向上：$oldState → $newState。") }
      $confirm.Add("改变证据状态：$path")
    }
    if ($type -eq 'evidence_item' -and $null -ne $old -and (Get-AbilityField $old 'evidence_validity') -ne (Get-AbilityField $validationContent 'evidence_validity')) { $confirm.Add("使旧证据失效：$path") }
    if ($type -eq 'capability_transfer' -and $newStatus -eq 'confirmed') { $confirm.Add('正式生成或导出能力移交卡') }
    if ($type -eq 'market_feedback' -and $oldStatus -eq 'draft' -and $newStatus -eq 'confirmed') { $confirm.Add('确认市场反馈进入正式复盘') }
    if ($path -match '^60_双工具交换/能力移交卡/' -and $command -ne 'ability-transfer') { $blocked.Add('能力移交卡只能由 ability-transfer 写入。') }
    if ($path -match '^60_双工具交换/市场反馈/' -and $command -ne 'feedback-return') { $blocked.Add('市场反馈只能由 feedback-return 写入。') }
  }
  if ($initialSkill) {
    $expected = @('20_能力地图/主技能.md','20_能力地图/能力维度/01_维度一.md','20_能力地图/能力维度/02_维度二.md','20_能力地图/能力维度/03_维度三.md','20_能力地图/能力维度/04_维度四.md','20_能力地图/能力维度/05_维度五.md','20_能力地图/能力维度/06_维度六.md')
    if ($command -ne 'skill-start' -or $operations.Count -ne 7 -or @($expected | Where-Object { -not $seen.ContainsKey($_) }).Count -gt 0) { $blocked.Add('首次建档必须由 skill-start 一次提交主技能与完整六维。') }
  }
  if ($confirmedTouched -ge 10) { $confirm.Add('批量修改至少 10 条 confirmed 记录') }
  if ($blocked.Count -eq 0) { foreach ($error in @(Get-AbilityModelErrors $Root $Manifest)) { $blocked.Add($error) } }
  $risk = if ($blocked.Count -gt 0) { 'blocked' } elseif ($confirm.Count -gt 0) { 'confirmation_required' } else { 'routine' }
  $previewId = [string](Get-AbilityProperty $Manifest 'preview_id')
  if ([string]::IsNullOrWhiteSpace($previewId)) { $previewId = 'preview-' + $batchId }
  $payloadHash = if (@($operations | Where-Object { [string](Get-AbilityProperty $_ 'content_sha256') -in @('', 'AUTO') }).Count -eq 0) { Get-AbilityPayloadHash $Manifest } else { '' }
  return [pscustomobject]@{ Risk=$risk; BlockedReasons=$blocked.ToArray(); ConfirmationReasons=@($confirm | Select-Object -Unique); PayloadHash=$payloadHash; PreviewId=$previewId; BatchId=$batchId; Command=$command }
}

function Test-AbilityNaturalConfirmation {
  param([string]$Text, [int]$PendingCount = 1)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  $clean = [regex]::Replace($Text, '(?is)\s*<(current_note|editor_selection|browser_selection)(?:\s+[^>]*)?>.*?</\1>\s*$', '').Trim()
  if ($clean -match '(不|别|不要|不能|不可|先别|先不|暂不|暂停|取消|撤销|拒绝|有问题|不对|改成|调整|修改|等等|等一下|再看看|未确认)' -or $clean -match '[?？]') { return $false }
  $normalized = [regex]::Replace($clean, '[\s，,。.!！；;：:]+', '')
  if ($normalized -in @('好','好的','行','行的','嗯','嗯嗯')) { return $PendingCount -eq 1 }
  return $normalized -match '(确认|同意|批准|可以|没问题|就按|照这个|照此|继续|执行|写入|保存|开始)'
}

function Get-AbilityTranscriptMessages {
  param([string]$TranscriptPath)
  if ([string]::IsNullOrWhiteSpace($TranscriptPath) -or -not (Test-Path -LiteralPath $TranscriptPath -PathType Leaf)) { return @() }
  $messages = New-Object System.Collections.Generic.List[object]
  foreach ($line in [IO.File]::ReadLines($TranscriptPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $row = $line | ConvertFrom-Json } catch { continue }
    $role = [string](Get-AbilityProperty $row 'type')
    $message = Get-AbilityProperty $row 'message'
    $content = if ($null -ne $message) { $roleValue = Get-AbilityProperty $message 'role'; if ($null -ne $roleValue) { $role = [string]$roleValue }; Get-AbilityProperty $message 'content' } else { Get-AbilityProperty $row 'content' }
    if ($role -notin @('user','assistant')) { continue }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($block in @($content)) {
      if ($block -is [string]) { $parts.Add($block) }
      elseif ($null -ne $block -and (Get-AbilityProperty $block 'type') -eq 'text') { $parts.Add([string](Get-AbilityProperty $block 'text')) }
    }
    $text = ($parts -join "`n")
    if (-not [string]::IsNullOrWhiteSpace($text)) { $messages.Add([pscustomobject]@{ Role=$role; Text=$text }) }
  }
  return $messages.ToArray()
}

function Test-AbilityTranscriptConfirmation {
  param([string]$TranscriptPath, [string]$PreviewId, [string]$PayloadHash, [int]$PendingCount = 1)
  $messages = @(Get-AbilityTranscriptMessages $TranscriptPath)
  $previewIndex = -1
  for ($i = 0; $i -lt $messages.Count; $i++) { if ($messages[$i].Role -eq 'assistant' -and $messages[$i].Text.Contains($PreviewId) -and $messages[$i].Text.Contains($PayloadHash)) { $previewIndex = $i } }
  if ($previewIndex -lt 0) { return $false }
  for ($i = $previewIndex + 1; $i -lt $messages.Count; $i++) {
    if ($messages[$i].Role -ne 'user' -or -not (Test-AbilityNaturalConfirmation $messages[$i].Text $PendingCount)) { continue }
    $unanswered = $false
    $revised = $false
    for ($j = $previewIndex + 1; $j -lt $i; $j++) {
      if ($messages[$j].Role -eq 'user' -and $messages[$j].Text -match '(改成|调整|修改|换成|补充|删掉|删除|增加|新增|重做|重新)') { $revised = $true; break }
      if ($messages[$j].Role -eq 'user' -and $messages[$j].Text -match '[?？]') {
        $answered = $false
        for ($k = $j + 1; $k -lt $i; $k++) { if ($messages[$k].Role -eq 'assistant') { $answered = $true; break } }
        if (-not $answered) { $unanswered = $true; break }
      }
    }
    if (-not $unanswered -and -not $revised) { return $true }
  }
  return $false
}

function Test-AbilityWriterCommand {
  param([string]$Command)
  $pattern = '^\s*powershell\.exe\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+"?\.claude[\\/]hooks[\\/]ability-write\.ps1"?\s+-Manifest\s+"?(\.claude[\\/]write-queue[\\/][A-Za-z0-9._-]+\.json)"?\s+-Mode\s+(Inspect|Apply)\s*$'
  $match = [regex]::Match($Command, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $match.Success) { return $null }
  return [pscustomobject]@{ ManifestPath=$match.Groups[1].Value.Replace('\','/'); Mode=$match.Groups[2].Value }
}

function Write-AbilityJsonFile {
  param([string]$Path, $Value)
  $directory = [IO.Path]::GetDirectoryName($Path)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), $script:AbilityUtf8NoBom)
}

function Invoke-AbilityAtomicApply {
  param([string]$Root, $Manifest, [string]$WorkRoot, [int]$FaultAfterWriteCount = -1)
  $evaluation = Get-AbilityManifestEvaluation $Root $Manifest
  if ($evaluation.Risk -eq 'blocked') { throw ('批次被拒绝：' + ($evaluation.BlockedReasons -join '；')) }
  $batchId = $evaluation.BatchId
  $stage = Join-Path $WorkRoot ('stage-' + $batchId + '-' + [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($stage) | Out-Null
  $committed = New-Object System.Collections.Generic.List[object]
  $count = 0
  try {
    $index = 0
    foreach ($op in @(Get-AbilityProperty $Manifest 'operations')) {
      $path = Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path'))
      $content = [string](Get-AbilityProperty $op 'content')
      $target = Resolve-AbilityTargetPath $Root $path
      if (Test-Path -LiteralPath $target -PathType Leaf) {
        $current = [IO.File]::ReadAllText($target, $script:AbilityUtf8NoBom)
        if ($current -eq $content) { continue }
      }
      $staged = Join-Path $stage ("new-$index.md")
      [IO.File]::WriteAllText($staged, $content, $script:AbilityUtf8NoBom)
      $index++
    }
    $index = 0
    foreach ($op in @(Get-AbilityProperty $Manifest 'operations')) {
      $path = Normalize-AbilityRelativePath ([string](Get-AbilityProperty $op 'path'))
      $content = [string](Get-AbilityProperty $op 'content')
      $target = Resolve-AbilityTargetPath $Root $path
      if (Test-Path -LiteralPath $target -PathType Leaf) {
        $current = [IO.File]::ReadAllText($target, $script:AbilityUtf8NoBom)
        if ($current -eq $content) { continue }
      }
      $targetDir = [IO.Path]::GetDirectoryName($target)
      [IO.Directory]::CreateDirectory($targetDir) | Out-Null
      $backup = Join-Path $stage ("backup-$index.md")
      $created = -not (Test-Path -LiteralPath $target -PathType Leaf)
      $tempAtTarget = $target + '.ability-write-' + [guid]::NewGuid().ToString('N') + '.tmp'
      [IO.File]::WriteAllText($tempAtTarget, $content, $script:AbilityUtf8NoBom)
      if ($created) { [IO.File]::Move($tempAtTarget, $target) } else { [IO.File]::Replace($tempAtTarget, $target, $backup, $true) }
      $committed.Add([pscustomobject]@{ Target=$target; Backup=$backup; Created=$created })
      $count++
      if ($FaultAfterWriteCount -ge 0 -and $count -ge $FaultAfterWriteCount) { throw 'TEST_INJECTED_COMMIT_FAILURE' }
      $index++
    }
    return [pscustomobject]@{ Status='applied'; BatchId=$batchId; PayloadHash=$evaluation.PayloadHash; Changed=$count }
  } catch {
    for ($i = $committed.Count - 1; $i -ge 0; $i--) {
      $item = $committed[$i]
      if ($item.Created) { if (Test-Path -LiteralPath $item.Target) { Remove-Item -LiteralPath $item.Target -Force } }
      elseif (Test-Path -LiteralPath $item.Backup) { [IO.File]::Copy($item.Backup, $item.Target, $true) }
    }
    throw
  } finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
  }
}
