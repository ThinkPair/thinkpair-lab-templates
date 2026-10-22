param(
  [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$validator = Join-Path $PSScriptRoot 'validate-package.ps1'
. $validator -PackageRoot $PackageRoot -LibraryMode -Quiet

$script:Passed = 0
$script:Failed = 0

function Assert-Equal {
  param($Actual, $Expected, [string]$Name)
  if ($Actual -eq $Expected) { $script:Passed++; Write-Host "PASS  $Name" -ForegroundColor Green }
  else { $script:Failed++; Write-Host "FAIL  $Name -- expected '$Expected', actual '$Actual'" -ForegroundColor Red }
}

function Assert-True {
  param([bool]$Condition, [string]$Name, [string]$Message = 'condition was false')
  if ($Condition) { $script:Passed++; Write-Host "PASS  $Name" -ForegroundColor Green }
  else { $script:Failed++; Write-Host "FAIL  $Name -- $Message" -ForegroundColor Red }
}

function Write-TestRecord {
  param([string]$Path, [string]$FrontMatter, [string]$Body = '测试记录')
  $directory = [IO.Path]::GetDirectoryName($Path)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  [IO.File]::WriteAllText($Path, "---`n$FrontMatter`n---`n`n# $Body`n", $utf8NoBom)
}

function Get-MasterSnapshot {
  param([string]$Root)
  return @((Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
    '{0}|{1}|{2}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks
  }) -join "`n")
}

$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$before = Get-MasterSnapshot $package
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('能力模型测试 ' + [guid]::NewGuid().ToString('N'))

try {
  $vault = Join-Path $tempRoot '能力空间 含中文'
  [IO.Directory]::CreateDirectory($vault) | Out-Null
  $commonProfile = @'
record_id: profile-001
record_type: skill_profile
skill_id: skill-001
record_status: confirmed
created_at: "2026-07-01T09:00:00+08:00"
updated_at: "2026-07-12T09:00:00+08:00"
privacy: private
schema_version: ability.v1
status: active
dimension_count: 6
'@
  Write-TestRecord (Join-Path $vault '20_能力地图\主技能.md') $commonProfile '主技能'

  for ($i = 1; $i -le 6; $i++) {
    $state = if ($i -eq 1) { 'externally_validated' } elseif ($i -eq 2) { 'observed' } else { 'unproven' }
    $refs = if ($i -eq 1) { "evidence_refs:`n  - evidence-external-current" } elseif ($i -eq 2) { "evidence_refs:`n  - evidence-new" } else { 'evidence_refs: []' }
    $fm = @"
record_id: dimension-$i
record_type: skill_dimension
skill_id: skill-001
record_status: confirmed
created_at: "2026-07-01T09:00:00+08:00"
updated_at: "2026-07-12T09:00:00+08:00"
privacy: private
schema_version: ability.v1
dimension_id: dim-$i
dimension_order: $i
dimension_name: "维度$i"
evidence_state: $state
$refs
"@
    Write-TestRecord (Join-Path $vault ("20_能力地图\能力维度\{0:00}.md" -f $i)) $fm "维度$i"
  }

  for ($i = 1; $i -le 50; $i++) {
    $status = if ($i -le 40) { 'confirmed' } elseif ($i -le 45) { 'draft' } else { 'demo' }
    $fm = @"
record_id: practice-$i
record_type: practice_record
skill_id: skill-001
record_status: $status
created_at: "2026-07-01T09:00:00+08:00"
updated_at: "2026-07-12T09:00:00+08:00"
privacy: private
schema_version: ability.v1
dimension_id: dim-1
practice_status: closed
"@
    $folder = if ($status -eq 'demo') { '70_只读示例\压力测试' } else { '30_刻意练习\练习记录' }
    Write-TestRecord (Join-Path $vault ("$folder\practice-$i.md")) $fm "练习$i"
  }

  for ($i = 1; $i -le 20; $i++) {
    $status = if ($i -le 14) { 'confirmed' } elseif ($i -le 17) { 'draft' } else { 'demo' }
    $id = "evidence-$i"
    $validity = 'current'
    $supersedes = ''
    if ($i -eq 1) { $id = 'evidence-old'; $validity = 'superseded' }
    if ($i -eq 2) { $id = 'evidence-new'; $supersedes = 'evidence-old' }
    if ($i -eq 3) { $id = 'evidence-external-current' }
    $type = if ($i -eq 3) { 'external_feedback' } else { 'work_sample' }
    $sourceKind = if ($i -eq 3) { 'external_feedback' } else { 'local_note' }
    $verification = if ($i -eq 3) { 'externally_provided' } else { 'self_recorded' }
    $fm = @"
record_id: $id
record_type: evidence_item
skill_id: skill-001
record_status: $status
created_at: "2026-07-01T09:00:00+08:00"
updated_at: "2026-07-12T09:00:00+08:00"
privacy: private
schema_version: ability.v1
evidence_id: $id
evidence_type: $type
evidence_validity: $validity
supersedes_evidence_id: "$supersedes"
source_kind: $sourceKind
verification_level: $verification
"@
    $folder = if ($status -eq 'demo') { '70_只读示例\压力测试' } else { '40_证据与反馈\证据记录' }
    Write-TestRecord (Join-Path $vault ("$folder\evidence-$i.md")) $fm "证据$i"
  }

  for ($i = 1; $i -le 5; $i++) {
    $status = if ($i -le 3) { 'confirmed' } elseif ($i -eq 4) { 'draft' } else { 'demo' }
    $fm = @"
record_id: review-$i
record_type: skill_review
skill_id: skill-001
record_status: $status
created_at: "2026-07-01T09:00:00+08:00"
updated_at: "2026-07-12T09:00:00+08:00"
privacy: private
schema_version: ability.v1
evidence_refs:
  - evidence-new
"@
    $folder = if ($status -eq 'demo') { '70_只读示例\压力测试' } else { '50_能力复盘\复盘记录' }
    Write-TestRecord (Join-Path $vault ("$folder\review-$i.md")) $fm "复盘$i"
  }

  $fieldDraft = @'
record_id: field-draft-001
record_type: field_draft
skill_id: skill-001
record_status: draft
created_at: "2026-07-12T10:00:00+08:00"
updated_at: "2026-07-12T10:00:00+08:00"
privacy: private
schema_version: ability.field_draft.v1
excluded_from_statistics: true
'@
  Write-TestRecord (Join-Path $vault '90_现场草稿\field-draft-001.md') $fieldDraft '现场草稿'

  $records = @(Get-AbilityRecords -VaultRoot $vault)
  $stats = Get-AbilityStatistics -Records $records
  Assert-Equal $stats.Practices 40 '50 条练习中只统计 40 条 confirmed'
  Assert-Equal $stats.Evidence 14 '20 条证据中只统计 14 条 confirmed'
  Assert-Equal $stats.Reviews 3 '多轮复盘只统计 confirmed'
  Assert-Equal $stats.ConfirmedTotal 64 'draft、demo 与现场草稿不进入总统计'
  Assert-Equal $stats.Dimensions 6 '固定六维全部进入当前技能'
  Assert-Equal $stats.CurrentEvidence 13 '旧证据退出当前证据集合'

  $currentIds = @((Get-CurrentEvidenceRecords -Records $records) | ForEach-Object { Get-DataString $_.Data 'record_id' })
  Assert-True ($currentIds -contains 'evidence-new') '新版本证据进入当前结论'
  Assert-True (-not ($currentIds -contains 'evidence-old')) '被替换的旧证据不再进入当前结论'
  Assert-True ($records.Count -gt 70) '压力样本成功生成且可解析'

  $modelErrors = @(Get-AbilityModelErrors -Records $records)
  if ($modelErrors.Count -gt 0) { $modelErrors | ForEach-Object { Write-Host "MODEL  $_" -ForegroundColor Yellow } }
  Assert-Equal $modelErrors.Count 0 '有效证据状态与外部验证规则通过'

  $dimensionTwo = $records | Where-Object { (Get-DataString $_.Data 'record_id') -eq 'dimension-2' } | Select-Object -First 1
  $dimensionTwo.Data['evidence_refs'] = @()
  $invalidErrors = @(Get-AbilityModelErrors -Records $records)
  Assert-True (@($invalidErrors | Where-Object { $_ -match '非 unproven 维度必须引用证据' }).Count -eq 1) '无证据时拒绝能力状态升级'
  $dimensionTwo.Data['evidence_refs'] = @('evidence-new')

  $dimensionOne = $records | Where-Object { (Get-DataString $_.Data 'record_id') -eq 'dimension-1' } | Select-Object -First 1
  $dimensionOne.Data['evidence_refs'] = @('evidence-new')
  $externalErrors = @(Get-AbilityModelErrors -Records $records)
  Assert-True (@($externalErrors | Where-Object { $_ -match 'externally_validated 必须引用外部' }).Count -eq 1) '只有自评时不得标记外部验证'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

$after = Get-MasterSnapshot $package
Assert-Equal $after $before '测试未修改根产品母版'

Write-Host ''
Write-Host ("数据模型测试：{0} 通过，{1} 失败。" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
