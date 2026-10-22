# `/skill-review`｜基于证据做能力复盘

## 目标

对明确周期内的正式练习、当前证据和外部反馈进行复盘，先沉淀真实发现、最大差距和下一练习；状态或能力版本变化后置确认。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。正式复盘、维度和主技能更新只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write。

## 读取与提问

只读取当前 `skill_id` 下的 confirmed 记录，排除 demo、草稿、归档、模板和非当前证据。每轮最多问三个：复盘周期、最意外的真实结果、下一阶段必须改善什么。可以挑战自评，不能以 AI 观点替代证据。

## 第一阶段：安全内容经写入器自动 Apply

信息足够后为 confirmed 的 `skill_review` 建立 routine 清单，完整内容包括：

- 由证据 ID 支撑的 `evidence_based_findings`。
- 明确维度、目标差距与依据的 `biggest_gap`。
- 一次可执行的 `next_practice`。
- 逐维状态候选与限制；证据不足的写“维持原状态”。
- `skill_version_before` 与当前正式版本；确认前 `skill_version_after` 保持原值。

这一步不修改维度 `evidence_state`、主技能 `ability_version` 或旧证据/结论有效性。Inspect 为 `routine` 时自动 Apply，随后复读并报告复盘已保存。

## 第二阶段：高影响变化一次确认

只有候选满足 [[80_AI能力教练/证据状态判定]] 时，才为状态/版本差异建立另一清单并 Inspect。返回 `confirmation_required` 后给摘要确认卡，列明旧值、新值、证据 refs、限制、首页影响，以及 Inspect 返回的 `preview_id` 与 `payload_hash`。无证据拒绝升级；只有自评拒绝外部验证；复盘次数本身不升版本。

用户确认后只对同一高影响清单 Apply，再复读状态/版本/旧结论有效性差异。未确认或拒绝时正式状态保持原值，第一阶段的复盘、差距和下一练习继续有效。最终表述用“你已确认把该维度记录为……”，不说 AI 认证了职业等级。
