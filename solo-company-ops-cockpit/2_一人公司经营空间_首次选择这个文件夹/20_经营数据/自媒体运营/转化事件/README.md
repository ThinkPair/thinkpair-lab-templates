# 转化事件

这里保存内容发布后真实发生的线索、沟通、订单和到账事件。事件记录是看板转化阶段、来源结构、趋势和实收的事实源。

首版事件类型：

- `qualified_lead`：有效线索；
- `deep_conversation`：深度沟通／需求确认；
- `first_paid`：首次付费订单；
- `renewal`：升级或续费订单。

同一事件可以通过 `content_id` 归因到具体内容；不能归因时保持空值并说明 `attribution_method: unknown`。`amount` 只填实际到账人民币金额。
