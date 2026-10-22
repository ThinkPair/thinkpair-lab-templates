# 创业算账解读｜只解释已保存结果

先读取 `10_商业运营专家内核/AI接手索引.md`、`诊断追问与验收协议.md` 和 `写回与事实分层协议.md`。本命令默认只读，不创建或修改核算记录。

按顺序执行：

1. 若参数包含核算路径，只接受 `20_经营数据/经营核算/实际核算/*.md` 或 `20_经营数据/经营核算/创业预估/*.md`；否则从两个目录中先按 `updated_at` 找到最新的一份已确认核算，再执行期间状态门，不得跳过一条较新的待复核记录去解释旧记录。
2. 核对来源文件同时满足：`record_type: business_calculation`、`calculation_status: confirmed`、`record_status: saved`，并存在 `calculation_id`、`input_hash`、`calculation_mode`、`calculation_version`。`quick_v3` 必须有合法的含首尾日期，且创业预估只能覆盖一个完整自然月；`quick_v2` 只有从当月 1 日到当月最后一天的完整单月记录可解释。跨月、全年、部分月或日期无效的 `quick_v2` 一律视为“旧版周期需复核”：只说明为什么不能判断成本口径，并引导用户到创业算账页选择“每月金额／本期总额”后另存新版结果；禁止解读其利润、现金、安全余额，禁止保存 AI 结论或继续目标倒推。任何字段缺失、路径越界、文件不存在或期间不合格时停止，不猜测。
3. 逐字采用来源文件已经保存的 `sustainable_profit`、`cash_net_change`、`safety_value`、`safety_label`、`headline_status` 与保本摘要。不得心算、重算、修正或 Edit 公式结果，不得把项目“报价－回款”当财务应收。
4. 若 `calculation_mode: forecast`，所有表述必须使用“预估／预计”，不得计入真实利润、现金或业绩；若为 `actual`，也只能解释该文件声明的核算周期。
5. 用普通中文解释利润、现金和交付安全为何可能不同；只指出一个证据最强的 `maximum_issue`，再提出一个具体、可执行、可验收的 `unique_action`。缺少依据时把“补齐最关键数据”作为动作，不生成健康评级或一组泛化建议。
6. 先在对话中展示解读及依据。默认到此结束，不写文件。
7. 用户明确要求保存当前解读时，该指令即为授权；校验通过后向 `20_经营数据/经营核算/AI结论/finance-insight-<时间戳>.md` 新增一条记录，不再要求二次确认。不得 Edit 旧结论，也不得写入实际核算、创业预估或产品收费方案目录。
8. 写回前重新读取来源核算，确认 `calculation_id + input_hash` 仍与本次解读完全一致。新记录必须包含以下 schema：

```yaml
---
record_type: finance_ai_insight
record_id: "finance-insight-YYYYMMDD-HHmmss"
record_status: active
calculation_id: "与来源完全一致"
input_hash: "与来源完全一致"
maximum_issue: "一个最大经营问题"
unique_action: "一个立即动作"
created_at: "ISO 8601 时间"
updated_at: "ISO 8601 时间"
privacy: sensitive
schema_version: "finance.v1"
---
```

9. 若 AI 主动建议保存，但用户只采用解读而未表达写入意图，只展示一次包含目标路径、最大问题、唯一动作和“仅库内新增、可恢复”的短预览。语义不足时交给原生确认一次。
10. 写后复读新结论与来源核算，再次核对 `calculation_id + input_hash`，登记操作日志并输出“【已写入看板】”。只复述来源中已经保存的公式数字，不由 AI 重新计算。若任一核对失败，如实报告且不得声称首页已更新。

本命令只用于新会话快速进入核算解读；进入对话后用户继续使用自然语言，不得要求再次输入命令。

核算路径或问题：$ARGUMENTS
