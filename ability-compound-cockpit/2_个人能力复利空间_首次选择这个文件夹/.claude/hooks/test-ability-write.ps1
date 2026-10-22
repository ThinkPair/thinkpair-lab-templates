$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'ability-write-core.ps1')

$script:Passed = 0
$script:Failed = 0
function Assert-True([bool]$Condition, [string]$Name, [string]$Detail = '') {
  if ($Condition) { $script:Passed++; Write-Host "PASS  $Name" -ForegroundColor Green }
  else { $script:Failed++; Write-Host "FAIL  $Name $Detail" -ForegroundColor Red }
}
function Write-Utf8([string]$Path, [string]$Content) { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null; [IO.File]::WriteAllText($Path,$Content,$utf8) }
function New-Common([string]$Id,[string]$Type,[string]$Skill,[string]$Extra,[string]$Title='测试') {
  return "---`nrecord_id: `"$Id`"`nrecord_type: $Type`nskill_id: `"$Skill`"`nrecord_status: confirmed`ncreated_at: `"2026-07-13T10:00:00+08:00`"`nupdated_at: `"2026-07-13T10:00:00+08:00`"`nprivacy: private`nschema_version: ability.v1`n$Extra`n---`n`n# $Title`n"
}
function New-InitialFixture([string]$Root) {
  $mainPath=Join-Path $Root '20_能力地图\主技能.md'
  Write-Utf8 $mainPath "---`nrecord_id: `"`"`nrecord_type: skill_profile`nskill_id: `"`"`nrecord_status: draft`ncreated_at: `"`"`nupdated_at: `"`"`nprivacy: private`nschema_version: ability.v1`nstatus: inactive`nskill_name: `"`"`ntarget_outcome: `"`"`nability_version: `"v0.0`"`ndimension_count: 6`ncurrent_practice_id: `"`"`nversion_evidence_refs: []`n---`n"
  $ops=New-Object System.Collections.Generic.List[object]
  $main=New-Common 'profile-1' 'skill_profile' 'skill-1' "status: active`nskill_name: `"咖啡制作`"`ntarget_outcome: `"稳定完成手冲`"`nability_version: `"v0.1`"`nbaseline_summary: `"初始基线`"`ndimension_count: 6`ncurrent_practice_id: `"`"`nversion_evidence_refs: []`nversion_confirmed_at: `"`"" '主技能'
  $ops.Add([pscustomobject]@{action='update';path='20_能力地图/主技能.md';content=$main;content_sha256='AUTO'})
  $cn=@('一','二','三','四','五','六')
  for($i=1;$i -le 6;$i++){
    $path=('20_能力地图/能力维度/{0:00}_维度{1}.md' -f $i,$cn[$i-1])
    Write-Utf8 (Join-Path $Root $path.Replace('/','\')) "---`nrecord_id: `"`"`nrecord_type: skill_dimension`nskill_id: `"`"`nrecord_status: draft`ncreated_at: `"`"`nupdated_at: `"`"`nprivacy: private`nschema_version: ability.v1`ndimension_id: `"`"`ndimension_order: $i`nevidence_state: unproven`n---`n"
    $content=New-Common ("dimension-$i") 'skill_dimension' 'skill-1' "dimension_id: `"dim-$i`"`ndimension_order: $i`ndimension_name: `"维度$i`"`nsuccess_criteria: `"可观察标准$i`"`nbaseline_note: `"待练习`"`nevidence_state: unproven`nevidence_refs: []`nstate_confirmed_at: `"`"`nstate_confirmed_by: `"`"" ("维度$i")
    $ops.Add([pscustomobject]@{action='update';path=$path;content=$content;content_sha256='AUTO'})
  }
  return [pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-initial-001';command='skill-start';preview_id='preview-wb-initial-001';operations=$ops.ToArray()}
}
function Seal-Manifest($Manifest){ foreach($op in @($Manifest.operations)){$op.content_sha256=Get-AbilitySha256Text ([string]$op.content)}; $Manifest|Add-Member -NotePropertyName payload_hash -NotePropertyValue (Get-AbilityPayloadHash $Manifest) -Force; return $Manifest }
function Snapshot([string]$Root){ return ((Get-ChildItem -LiteralPath $Root -Recurse -File|Sort-Object FullName|ForEach-Object{ $_.FullName.Substring($Root.Length)+'|'+(Get-AbilitySha256Text ([IO.File]::ReadAllText($_.FullName,$utf8)))}) -join "`n") }
function Invoke-GuardProcess([string]$HookPath, $Payload) {
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName='powershell.exe'
  $psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$HookPath+'"'
  $psi.UseShellExecute=$false
  $psi.RedirectStandardInput=$true
  $psi.RedirectStandardOutput=$true
  $psi.RedirectStandardError=$true
  $psi.CreateNoWindow=$true
  $process=New-Object Diagnostics.Process
  $process.StartInfo=$psi
  [void]$process.Start()
  $process.StandardInput.Write(($Payload|ConvertTo-Json -Depth 20 -Compress))
  $process.StandardInput.Close()
  $stdout=$process.StandardOutput.ReadToEnd()
  $stderr=$process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if($process.ExitCode -ne 0){throw "Guard process failed: $stderr"}
  return ($stdout|ConvertFrom-Json)
}

$temp=Join-Path ([IO.Path]::GetTempPath()) ('能力写回测试 中文 空格 '+[guid]::NewGuid().ToString('N'))
try {
  [IO.Directory]::CreateDirectory($temp)|Out-Null
  $vault=Join-Path $temp '首次能力空间 中文'
  $manifest=New-InitialFixture $vault
  $draft=Get-AbilityManifestEvaluation $vault $manifest -AllowAutoHash
  Assert-True ($draft.Risk -eq 'routine') '首次主技能与六维属于 routine' ($draft.BlockedReasons -join ';')
  $manifest=Seal-Manifest $manifest
  $sealed=Get-AbilityManifestEvaluation $vault $manifest
  Assert-True ($sealed.Risk -eq 'routine' -and $sealed.PayloadHash -match '^[a-f0-9]{64}$') 'Inspect 后得到稳定哈希'
  $applied=Invoke-AbilityAtomicApply $vault $manifest (Join-Path $vault '.claude\write-queue')
  Assert-True ($applied.Changed -eq 7) '七文件批次完整写入'
  $main=[IO.File]::ReadAllText((Join-Path $vault '20_能力地图\主技能.md'),$utf8)
  Assert-True ((Get-AbilityField $main 'status') -eq 'active') '全部成功后主技能激活'

  $practice=New-Common 'practice-1' 'practice_record' 'skill-1' "practice_id: `"practice-1`"`ndimension_id: `"dim-1`"`npractice_status: planned`npractice_title: `"手冲水流练习`"`npractice_goal: `"稳定水流`"`nbaseline: `"流速波动`"`ndeliberate_constraint: `"固定壶高`"`nsuccess_signal: `"三次流速接近`"`nplanned_steps: [准备, 练习, 记录]`nstarted_at: `"`"`nended_at: `"`"`nresult: `"`"`nevidence_refs: []`nnext_adjustment: `"`"`nenergy_state: `"`"" '刻意练习'
  $mainWithPractice=$main.Replace('current_practice_id: ""','current_practice_id: "practice-1"')
  $practicePlan=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-practice-plan';command='practice-plan';preview_id='preview-practice-plan';operations=@([pscustomobject]@{action='create';path='30_刻意练习/练习记录/practice-1.md';content=$practice;content_sha256='AUTO'},[pscustomobject]@{action='update';path='20_能力地图/主技能.md';content=$mainWithPractice;content_sha256='AUTO'})})
  $practicePlanEval=Get-AbilityManifestEvaluation $vault $practicePlan
  $practicePlanApply=if($practicePlanEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $practicePlan (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($practicePlanEval.Risk -eq 'routine' -and $practicePlanApply.Changed -eq 2) 'practice-plan 自动创建练习并更新主技能指针' ($practicePlanEval.BlockedReasons -join ';')

  $closedPractice=$practice.Replace('practice_status: planned','practice_status: closed').Replace('ended_at: ""','ended_at: "2026-07-13T11:00:00+08:00"').Replace('result: ""','result: "三次流速趋于稳定"').Replace('next_adjustment: ""','next_adjustment: "缩小注水高度波动"')
  $practiceClose=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-practice-close';command='practice-close';preview_id='preview-practice-close';operations=@([pscustomobject]@{action='update';path='30_刻意练习/练习记录/practice-1.md';content=$closedPractice;content_sha256='AUTO'},[pscustomobject]@{action='update';path='20_能力地图/主技能.md';content=$main;content_sha256='AUTO'})})
  $practiceCloseEval=Get-AbilityManifestEvaluation $vault $practiceClose
  $practiceCloseApply=if($practiceCloseEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $practiceClose (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($practiceCloseEval.Risk -eq 'routine' -and $practiceCloseApply.Changed -eq 2) 'practice-close 自动关闭练习并清空指针' ($practiceCloseEval.BlockedReasons -join ';')

  $routineEvidence=New-Common 'evidence-work-1' 'evidence_item' 'skill-1' "evidence_id: `"evidence-work-1`"`nevidence_type: work_sample`ntitle: `"水流练习记录`"`nevidence_version: 1`nevidence_validity: current`nsupersedes_evidence_id: `"`"`ncaptured_at: `"2026-07-13T11:00:00+08:00`"`nsource_kind: local_note`nsource: `"附件/水流练习.md`"`nsource_hash: `"`"`ndimension_ids: [dim-1]`nrelated_record_ids: [practice-1]`nsummary: `"记录三次练习结果`"`nverification_level: self_recorded`nsupports_state_candidate: observed" '练习证据'
  $evidenceAdd=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-evidence-add';command='evidence-add';preview_id='preview-evidence-add';operations=@([pscustomobject]@{action='create';path='40_证据与反馈/证据记录/evidence-work-1.md';content=$routineEvidence;content_sha256='AUTO'})})
  $evidenceAddEval=Get-AbilityManifestEvaluation $vault $evidenceAdd
  $evidenceAddApply=if($evidenceAddEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $evidenceAdd (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($evidenceAddEval.Risk -eq 'routine' -and $evidenceAddApply.Changed -eq 1) 'evidence-add 只加 confirmed 证据时自动执行' ($evidenceAddEval.BlockedReasons -join ';')

  $review=New-Common 'review-1' 'skill_review' 'skill-1' "review_id: `"review-1`"`nperiod_start: `"2026-07-07`"`nperiod_end: `"2026-07-13`"`nreview_status: confirmed`nevidence_refs: [evidence-work-1]`nevidence_based_findings: [`"水流稳定性已有观察证据`"]`nbiggest_gap: `"重复稳定性不足`"`nbiggest_gap_dimension_id: `"dim-1`"`nbiggest_gap_reason: `"样本仍少`"`nnext_practice: `"增加不同粉量下练习`"`nstate_change_proposals: []`nskill_version_before: `"v0.1`"`nskill_version_after: `"v0.1`"`nconclusion_status: current`nconfirmed_at: `"2026-07-13T11:10:00+08:00`"" '能力复盘'
  $reviewBatch=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-skill-review';command='skill-review';preview_id='preview-skill-review';operations=@([pscustomobject]@{action='create';path='50_能力复盘/复盘记录/review-1.md';content=$review;content_sha256='AUTO'})})
  $reviewEval=Get-AbilityManifestEvaluation $vault $reviewBatch
  $reviewApply=if($reviewEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $reviewBatch (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($reviewEval.Risk -eq 'routine' -and $reviewApply.Changed -eq 1) 'skill-review 无状态变化时自动执行' ($reviewEval.BlockedReasons -join ';')

  $transferDraft="---`nrecord_id: `"ct-draft-1`"`nrecord_type: capability_transfer`nskill_id: `"skill-1`"`nrecord_status: draft`ntransfer_id: `"ct-draft-1`"`nsource_product: personal_capability_cockpit`ntarget_product: solo_business_operations_cockpit`ncreated_at: `"2026-07-13T11:20:00+08:00`"`nupdated_at: `"2026-07-13T11:20:00+08:00`"`nuser_confirmed_at: `"`"`nprivacy: sensitive`nschema_version: exchange.capability_transfer.v1`nhash_algorithm: sha256`ncanonicalization: exchange-json-line.v1`ncapability_result: `"可稳定完成基础手冲流程`"`ncapability_version: `"v0.1`"`nevidence_summary: `"已有一条练习作品记录`"`nevidence_refs_json: `"[\`"evidence-work-1\`"]`"`napplicability_boundaries_json: `"[\`"仅限基础练习\`"]`"`nminimum_deliverable_candidate: `"一次基础演示`"`npotential_audiences_json: `"[]`"`ncontent_hash: `"`"`n---`n`n# 能力移交草稿`n"
  $transferBatch=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-transfer-draft';command='ability-transfer';preview_id='preview-transfer-draft';operations=@([pscustomobject]@{action='create';path='60_双工具交换/能力移交卡/ct-draft-1.md';content=$transferDraft;content_sha256='AUTO'})})
  $transferEval=Get-AbilityManifestEvaluation $vault $transferBatch
  $transferApply=if($transferEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $transferBatch (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($transferEval.Risk -eq 'routine' -and $transferApply.Changed -eq 1) 'ability-transfer 草稿自动执行' ($transferEval.BlockedReasons -join ';')

  $feedbackHash='c'*64
  $sourceHash='d'*64
  $feedbackDraft="---`nrecord_id: `"mf-draft-1`"`nrecord_type: market_feedback`nskill_id: `"skill-1`"`nrecord_status: draft`nfeedback_id: `"mf-draft-1`"`nsource_transfer_id: `"ct-source-1`"`nsource_transfer_hash: `"$sourceHash`"`nsource_validation_id: `"validation-1`"`nsource_product: solo_business_operations_cockpit`ntarget_product: personal_capability_cockpit`ncreated_at: `"2026-07-13T11:30:00+08:00`"`nupdated_at: `"2026-07-13T11:30:00+08:00`"`nimported_at: `"2026-07-13T11:30:00+08:00`"`nexport_status: confirmed`nexport_confirmed_at: `"2026-07-13T11:25:00+08:00`"`nredaction_confirmed: true`nredaction_confirmed_at: `"2026-07-13T11:25:00+08:00`"`nuser_confirmed_at: `"`"`nprivacy: private`nschema_version: exchange.market_feedback.v1`nhash_algorithm: sha256`ncanonicalization: exchange-json-line.v1`nfeedback_summary: `"演示步骤清楚`"`nskill_gap: `"不同条件下稳定性不足`"`nnext_practice_candidate: `"增加变化条件练习`"`ncontent_hash: `"$feedbackHash`"`n---`n`n# 市场反馈草稿`n"
  $feedbackBatch=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-feedback-draft';command='feedback-return';preview_id='preview-feedback-draft';operations=@([pscustomobject]@{action='create';path='60_双工具交换/市场反馈/mf-draft-1.md';content=$feedbackDraft;content_sha256='AUTO'})})
  $feedbackEval=Get-AbilityManifestEvaluation $vault $feedbackBatch
  $feedbackApply=if($feedbackEval.Risk -eq 'routine'){Invoke-AbilityAtomicApply $vault $feedbackBatch (Join-Path $vault '.claude\write-queue')}else{$null}
  Assert-True ($feedbackEval.Risk -eq 'routine' -and $feedbackApply.Changed -eq 1) 'feedback-return 草稿自动执行' ($feedbackEval.BlockedReasons -join ';')

  $formalTransfer=$transferDraft.Replace('record_status: draft','record_status: confirmed').Replace('user_confirmed_at: ""','user_confirmed_at: "2026-07-13T11:40:00+08:00"').Replace('content_hash: ""',('content_hash: "'+('a'*64)+'"'))
  $formalTransferBatch=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-transfer-confirm';command='ability-transfer';preview_id='preview-transfer-confirm';operations=@([pscustomobject]@{action='update';path='60_双工具交换/能力移交卡/ct-draft-1.md';content=$formalTransfer;content_sha256='AUTO'})})
  $formalTransferEval=Get-AbilityManifestEvaluation $vault $formalTransferBatch
  Assert-True ($formalTransferEval.Risk -eq 'confirmation_required') '正式能力移交卡必须一次确认' ($formalTransferEval.BlockedReasons -join ';')

  $formalFeedback=$feedbackDraft.Replace('record_status: draft','record_status: confirmed').Replace('user_confirmed_at: ""','user_confirmed_at: "2026-07-13T11:45:00+08:00"')
  $formalFeedbackBatch=Seal-Manifest ([pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-feedback-confirm';command='feedback-return';preview_id='preview-feedback-confirm';operations=@([pscustomobject]@{action='update';path='60_双工具交换/市场反馈/mf-draft-1.md';content=$formalFeedback;content_sha256='AUTO'})})
  $formalFeedbackEval=Get-AbilityManifestEvaluation $vault $formalFeedbackBatch
  Assert-True ($formalFeedbackEval.Risk -eq 'confirmation_required') '市场反馈 draft→confirmed 必须一次确认' ($formalFeedbackEval.BlockedReasons -join ';')

  $changedId=$main.Replace('skill_id: "skill-1"','skill_id: "skill-2"')
  $identity=[pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-identity-001';command='skill-start';preview_id='preview-id';operations=@([pscustomobject]@{action='update';path='20_能力地图/主技能.md';content=$changedId;content_sha256=(Get-AbilitySha256Text $changedId)})}
  $identityEval=Get-AbilityManifestEvaluation $vault $identity
  Assert-True ($identityEval.Risk -eq 'blocked') '身份字段初始化后不可变'

  $dimPath='20_能力地图/能力维度/01_维度一.md'
  $dim=[IO.File]::ReadAllText((Join-Path $vault $dimPath.Replace('/','\')),$utf8)
  $noEvidence=$dim.Replace('evidence_state: unproven','evidence_state: observed')
  $noEvidenceManifest=[pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-no-evidence';command='skill-review';preview_id='preview-no';operations=@([pscustomobject]@{action='update';path=$dimPath;content=$noEvidence;content_sha256=(Get-AbilitySha256Text $noEvidence)})}
  $noEvidenceEval=Get-AbilityManifestEvaluation $vault $noEvidenceManifest
  Assert-True ($noEvidenceEval.Risk -eq 'blocked') '没有证据时硬拦状态升级'

  $skipState=$dim.Replace('evidence_state: unproven','evidence_state: repeatable').Replace('evidence_refs: []','evidence_refs: [evidence-a, evidence-b]')
  $skipManifest=[pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-skip-state';command='skill-review';preview_id='preview-skip';operations=@([pscustomobject]@{action='update';path=$dimPath;content=$skipState;content_sha256=(Get-AbilitySha256Text $skipState)})}
  $skipEval=Get-AbilityManifestEvaluation $vault $skipManifest
  Assert-True ($skipEval.Risk -eq 'blocked' -and (($skipEval.BlockedReasons -join '；') -match '只能逐级向上')) '证据状态禁止跨级升级'

  $versionMain=$main.Replace('ability_version: "v0.1"','ability_version: "v0.2"').Replace('version_evidence_refs: []','version_evidence_refs: [evidence-1]')
  $evidence=New-Common 'evidence-1' 'evidence_item' 'skill-1' "evidence_id: `"evidence-1`"`nevidence_type: work_sample`ntitle: `"作品一`"`nevidence_version: 1`nevidence_validity: current`nsupersedes_evidence_id: `"`"`ncaptured_at: `"2026-07-13T10:00:00+08:00`"`nsource_kind: local_note`nsource: `"附件/作品一.jpg`"`nsource_hash: `"`"`ndimension_ids: [dim-1]`nrelated_record_ids: []`nsummary: `"成品`"`nverification_level: self_recorded`nsupports_state_candidate: observed" '作品证据'
  $versionManifest=[pscustomobject]@{schema_version='ability-write.v1';batch_id='wb-version-001';command='skill-review';preview_id='preview-version';operations=@([pscustomobject]@{action='create';path='40_证据与反馈/证据记录/evidence-1.md';content=$evidence;content_sha256=(Get-AbilitySha256Text $evidence)},[pscustomobject]@{action='update';path='20_能力地图/主技能.md';content=$versionMain;content_sha256=(Get-AbilitySha256Text $versionMain)})}
  $versionEval=Get-AbilityManifestEvaluation $vault $versionManifest
  Assert-True ($versionEval.Risk -eq 'confirmation_required') '能力版本变化只需一次确认' ($versionEval.BlockedReasons -join ';')

  $transcript=Join-Path $temp 'conversation.jsonl'
  $rows=@(
    @{type='assistant';message=@{role='assistant';content=@(@{type='text';text=("将升级能力版本。preview-version `n"+$versionEval.PayloadHash)})}},
    @{type='user';message=@{role='user';content='这个之后能撤销吗？'}},
    @{type='assistant';message=@{role='assistant';content='可以通过新版本记录回退，原证据保留。'}},
    @{type='user';message=@{role='user';content='没问题，继续'}}
  ) | ForEach-Object { $_|ConvertTo-Json -Depth 8 -Compress }
  Write-Utf8 $transcript ($rows -join "`n")
  Assert-True (Test-AbilityTranscriptConfirmation $transcript 'preview-version' $versionEval.PayloadHash 1) '提问不使哈希绑定确认失效'
  Assert-True (-not (Test-AbilityTranscriptConfirmation $transcript 'preview-version' ('0'*64) 1)) '内容哈希变化后旧确认失效'
  $revisionTranscript=Join-Path $temp 'revision.jsonl'
  $revisionRows=@(
    @{type='assistant';message=@{role='assistant';content=("preview-version `n"+$versionEval.PayloadHash)}},
    @{type='user';message=@{role='user';content='把版本说明修改一下'}},
    @{type='assistant';message=@{role='assistant';content='好的，我来调整。'}},
    @{type='user';message=@{role='user';content='确认'}}
  ) | ForEach-Object { $_|ConvertTo-Json -Depth 8 -Compress }
  Write-Utf8 $revisionTranscript ($revisionRows -join "`n")
  Assert-True (-not (Test-AbilityTranscriptConfirmation $revisionTranscript 'preview-version' $versionEval.PayloadHash 1)) '提出修订后旧 preview 立即失效'
  $revisionRows += (@{type='assistant';message=@{role='assistant';content=("已按要求重发 preview-version `n"+$versionEval.PayloadHash)}}|ConvertTo-Json -Depth 8 -Compress)
  $revisionRows += (@{type='user';message=@{role='user';content='可以，保存吧'}}|ConvertTo-Json -Depth 8 -Compress)
  Write-Utf8 $revisionTranscript ($revisionRows -join "`n")
  Assert-True (Test-AbilityTranscriptConfirmation $revisionTranscript 'preview-version' $versionEval.PayloadHash 1) '同 payload 重新预览后可再次确认'
  Assert-True ($null -ne (Test-AbilityWriterCommand 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude/hooks/ability-write.ps1" -Manifest ".claude/write-queue/wb-1.json" -Mode Apply')) '固定 writer 命令被允许'
  Assert-True ($null -eq (Test-AbilityWriterCommand 'powershell.exe -NoProfile -Command "Remove-Item *"')) '任意 Shell 被拒绝'

  $integrationVault=Join-Path $temp 'Hook Writer 集成空间'
  $integrationManifest=New-InitialFixture $integrationVault
  foreach($operation in @($integrationManifest.operations)){
    $operation.content=[regex]::Replace([string]$operation.content,'(?m)^created_at:\s*.*$','created_at: AUTO_NOW')
    $operation.content=[regex]::Replace([string]$operation.content,'(?m)^updated_at:\s*.*$','updated_at: AUTO_NOW')
  }
  $hookDir=Join-Path $integrationVault '.claude\hooks'
  [IO.Directory]::CreateDirectory($hookDir)|Out-Null
  foreach($scriptName in @('ability-write-core.ps1','ability-write.ps1','guard-write.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $scriptName) -Destination (Join-Path $hookDir $scriptName)}
  $queue=Join-Path $integrationVault '.claude\write-queue'
  [IO.Directory]::CreateDirectory($queue)|Out-Null
  $manifestFile=Join-Path $queue 'wb-initial-001.json'
  $integrationJson=$integrationManifest|ConvertTo-Json -Depth 20
  $queueWriteDecision=Invoke-GuardProcess (Join-Path $hookDir 'guard-write.ps1') @{tool_name='Write';cwd=$integrationVault;tool_input=@{file_path=$manifestFile;content=$integrationJson}}
  Assert-True ($queueWriteDecision.hookSpecificOutput.permissionDecision -eq 'allow') 'guard 接受含 AUTO_NOW 的临时批次清单'
  Write-Utf8 $manifestFile $integrationJson
  $inspectRaw=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hookDir 'ability-write.ps1') -Manifest '.claude/write-queue/wb-initial-001.json' -Mode Inspect
  $inspect=$inspectRaw|ConvertFrom-Json
  Assert-True ($inspect.risk -eq 'routine' -and $inspect.payload_hash -match '^[a-f0-9]{64}$') 'writer Inspect 集成封存成功'
  $sealedIntegration=[IO.File]::ReadAllText($manifestFile,$utf8)|ConvertFrom-Json
  $sealedContents=@($sealedIntegration.operations|ForEach-Object{[string]$_.content})
  $sealedTimestamp=Get-AbilityField $sealedContents[0] 'updated_at'
  Assert-True (-not (($sealedContents -join "`n") -match 'AUTO_NOW') -and (Test-AbilityTimestamp $sealedTimestamp)) 'AUTO_NOW 被替换为本机带时区时间并重算哈希'
  $applyCommand='powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude/hooks/ability-write.ps1" -Manifest ".claude/write-queue/wb-initial-001.json" -Mode Apply'
  $badPowerShell=Invoke-GuardProcess (Join-Path $hookDir 'guard-write.ps1') @{tool_name='PowerShell';cwd=$integrationVault;tool_input=@{command='Get-Date'}}
  Assert-True ($badPowerShell.hookSpecificOutput.permissionDecision -eq 'deny') '非固定 PowerShell 命令被拒绝'
  $hookResult=Invoke-GuardProcess (Join-Path $hookDir 'guard-write.ps1') @{tool_name='PowerShell';cwd=$integrationVault;tool_input=@{command=$applyCommand}}
  Assert-True ($hookResult.hookSpecificOutput.permissionDecision -eq 'allow') '固定 PowerShell writer 为 routine 自动签发许可'
  $applyRaw=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hookDir 'ability-write.ps1') -Manifest '.claude/write-queue/wb-initial-001.json' -Mode Apply
  $apply=$applyRaw|ConvertFrom-Json
  Assert-True ($apply.status -eq 'applied' -and $apply.changed_files -eq 7 -and -not (Test-Path -LiteralPath $manifestFile)) 'writer Apply 完成并清理正文清单'

  $rollbackVault=Join-Path $temp '回滚 空间'
  $rollbackManifest=Seal-Manifest (New-InitialFixture $rollbackVault)
  $before=Snapshot $rollbackVault
  $rolledBack=$false
  try { Invoke-AbilityAtomicApply $rollbackVault $rollbackManifest (Join-Path $rollbackVault '.claude\write-queue') 2 | Out-Null } catch { $rolledBack=$_.Exception.Message -eq 'TEST_INJECTED_COMMIT_FAILURE' }
  $after=Snapshot $rollbackVault
  Assert-True ($rolledBack -and $before -eq $after) '七文件中断后完整回滚'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n写回核心测试：$script:Passed 通过，$script:Failed 失败。"
if($script:Failed -gt 0){exit 1}
exit 0
