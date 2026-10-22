# `/feedback-return`｜接收市场反馈回流

## 目标

把商业验证返回的脱敏反馈先导入为草稿，再经一次确认纳入正式复盘。市场反馈不能直接改写能力等级。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。空间内市场反馈草稿和正式复盘输入只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write。

## 导入门与自动草稿

1. 只通过 `60_双工具交换/` 的导入器读取反馈卡。
2. 校验 `record_type`、`schema_version`、`transfer_id`、内容哈希、重复和必填字段；重复、篡改、旧版本或缺字段拒绝。
3. 含客户身份、联系方式、价格、收入、回款、财务信息或本机绝对路径时拒绝，并说明脱敏要求。
4. 合法卡为 `record_status: draft` 建立写入器清单；Inspect 为 `routine` 时自动 Apply，不进入首页，不改变证据状态或能力版本。

每轮最多问三个：对应哪个能力结果/维度、暴露的具体技能差距、下一次最小练习候选是否准确。不要追问已脱敏的身份或价格。

## 纳入正式复盘一次确认

草稿 Apply 成功后，为纳入正式复盘的差异建立另一清单并 Inspect。返回 `confirmation_required` 后发摘要确认卡，列明脱敏反馈摘要、技能差距、下一练习候选、关联维度、正式复盘影响，以及返回的 `preview_id` 与 `payload_hash`。明确 `state_change_proposals: []`，本命令不改变 `evidence_state` 或 `ability_version`。

用户确认后对同一清单 Apply，按交换规范把反馈纳入正式复盘输入并复读；未确认时草稿安全保留。若实际作品或可追溯外部评价需要成为能力证据，引导 `/evidence-add`，再由 `/skill-review` 判断状态。
