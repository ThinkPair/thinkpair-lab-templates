# 经营目标拆解｜确定性倒推

先读取 `10_商业运营专家内核/AI接手索引.md`、`经营目标倒推协议.md` 与 `写回与事实分层协议.md`。本命令不得心算漏斗目标或修改目标方案。

按顺序执行：

1. 读取最新有效 `business_calculation`，再读取 `20_经营数据/经营目标/目标方案` 中与其 `calculation_id + source_input_hash` 完全匹配、`target_input_hash` 可复算的最新 `business_target_plan`。没有有效目标时，引导用户回到创业算账页制定目标，不生成行动计划。
2. 读取与当前 `target_plan_id + target_input_hash` 匹配的最新行动计划作为进度参考；旧哈希记录只作历史，不参与当前数字。
3. 每轮只问 1—3 个问题，补齐累计实际实收、成交单数、确认收入、交付量、剩余有效经营日和四段转化依据。必要时再问 1—3 个主要渠道占比。不要让用户填写 YAML 或技术字段。
4. 转化率必须注明 `historical` 或 `user_estimate`；混合来源使用 `mixed`。完全未知时选择 `seven_day_calibration`，只记录五段漏斗分子分母，不生成伪精确目标，也不引用行业默认值。
5. 在当前经营空间中，只通过守卫允许的固定顺序安全参数调用确定性脚本。日常命令不得添加 `--vault-root`、引号、重定向或其他参数。最小调用用于转化率完全未知、进入七天校准；所有 `0` 都必须是用户确认的真实未发生，不得用来代替未知：

```text
node .claude/skills/commercial-operations-expert/scripts/target-breakdown.js --target 20_经营数据/经营目标/目标方案/<target_plan_id>.md --actual-cash <实收> --actual-deals <成交整数> --actual-revenue <确认收入> --actual-delivery <交付量> --remaining-days <正整数>
```

已知四段转化率时，紧接必填参数按固定顺序追加：

```text
--outreach-response <百分数> --response-discussion <百分数> --discussion-quote <百分数> --quote-sale <百分数> --basis <historical|user_estimate|mixed>
```

随后可按固定顺序追加：

```text
--actual-outreach <整数> --actual-responses <整数> --actual-discussions <整数> --actual-quotes <整数> --actual-funnel-deals <整数> --channels 渠道A:60,渠道B:40 --weeks 本周:40,下周:60 --sprint-factor 1.00 --cash-risk false
```

五段漏斗实际数必须同时提供，且 `actual-funnel-deals` 与成交进度一致；未知时整组省略。渠道最多 3 个、周权重最多 5 个，名称只能使用无空格的中英文、数字、下划线或短横线。不得自行补算、四舍五入或修改脚本输出。输入变化时重新调用脚本。`--input-base64` 只为旧流程兼容，日常对话不得要求模型编码长 JSON。
6. 输出“【目标拆解草稿】”：分别展示利润交付线、销售收款线、四类当前差额、漏斗与每日任务、转化依据、渠道／周权重、显式冲刺系数、最大断点和唯一动作。产能不可行时不得继续扩大获客目标。
7. 默认只分析。用户要求保存或已经采用当前结果时，向 `20_经营数据/经营目标/行动计划/<action_plan_id>.md` 新增一条 `operating_action_plan`；不得 Edit 旧行动，不得写入目标方案目录。
8. 行动记录使用下列固定外壳。机器块的 `input` 必须逐字等于脚本返回的 `deterministicInput`，`result` 必须保存脚本返回的完整 envelope（不是只保存 `preview`）：

````markdown
---
record_type: operating_action_plan
action_plan_id: "oap-<breakdown_input_hash>"
record_status: active
target_plan_id: "btp-<target_input_hash>"
target_input_hash: "16 位哈希"
breakdown_input_hash: "16 位哈希"
target_month: "YYYY-MM"
hash_algorithm: fnv1a64
created_at: "ISO 8601 时间"
updated_at: "ISO 8601 时间"
privacy: sensitive
schema_version: "operating_action_plan.v1"
---

# 本月经营行动计划

- 本周先做：<result.result.uniqueAction.text>

<!-- operating-action-plan-json:start -->
```json
{"input": <deterministicInput>, "result": <完整 operating_action_plan envelope>}
```
<!-- operating-action-plan-json:end -->
````

9. 正式预览必须列出来源目标路径、`target_plan_id + target_input_hash + breakdown_input_hash`，并在“【拟写原文】”下逐字展示完整记录，以“【等待确认】”结束。
10. 用户对当前预览明确、无条件同意后立即 Write。守卫将用同一引擎复算并拒绝旧目标、哈希失配、数字篡改、非法占比、隐藏冲刺系数或越权路径。
11. 写后复读目标和行动计划，核对三组绑定、确定性结果与唯一动作，登记确认日志，再输出“【已写入看板】”。任一核验失败都不得声称首页已更新。

本命令只用于新会话快速进入目标拆解；进入对话后用户继续用自然语言即可。

本轮补充：$ARGUMENTS
