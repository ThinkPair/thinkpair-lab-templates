# 创业算账解读｜只解释已保存结果

先读取 `10_商业运营专家内核/AI接手索引.md`、`诊断追问与验收协议.md` 和 `写回与事实分层协议.md`。本命令默认只读，不创建或修改核算记录。

按顺序执行：

1. 若参数包含核算路径，只接受 `20_经营数据/经营核算/实际核算/*.md` 或 `20_经营数据/经营核算/创业预估/*.md`；否则从两个目录中选择 `updated_at` 最新的一份已确认核算。
2. 核对来源文件同时满足：`record_type: business_calculation`、`calculation_status: confirmed`，并存在 `calculation_id`、`input_hash`、`calculation_mode`、`calculation_version`。任何字段缺失、路径越界或文件不存在时停止解读，不猜测。
3. 逐字采用来源文件已经保存的 `sustainable_profit`、`cash_net_change`、`safety_value`、`safety_label`、`headline_status` 与保本摘要。不得心算、重算、修正或 Edit 公式结果，不得把项目“报价－回款”当财务应收。
4. 若 `calculation_mode: forecast`，所有表述必须使用“预估／预计”，不得计入真实利润、现金或业绩；若为 `actual`，也只能解释该文件声明的核算周期。
5. 用普通中文解释利润、现金和交付安全为何可能不同；只指出一个证据最强的 `maximum_issue`，再提出一个具体、可执行、可验收的 `unique_action`。缺少依据时把“补齐最关键数据”作为动作，不生成健康评级或一组泛化建议。
6. 先在对话中展示解读及依据。默认到此结束，不写文件。
7. 只有用户明确要求保存或已经采用当前解读时，才准备向 `20_经营数据/经营核算/AI结论/finance-insight-<时间戳>.md` 新增一条记录。不得 Edit 旧结论，也不得写入实际核算、创业预估或产品收费方案目录。
8. 写回前重新读取来源核算，确认 `calculation_id + input_hash` 仍与本次解读完全一致。然后只展示一次“【写回预览】”，在“【拟写原文】”下逐字给出完整新文件，至少包含：

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

9. 预览以“【等待确认】”结尾。用户对当前预览用“确认”“确认写入”“可以写”“就按这个”“没问题写吧”“执行吧”等无条件自然语言明确同意后立即新增；模糊、否定、附带修改条件、来源已经变化或旧预览确认均不授权。
10. 写后复读新结论与来源核算，再次核对 `calculation_id + input_hash`，登记确认日志并输出“【已写入看板】”。只复述来源中已经保存的公式数字，不由 AI 重新计算。若任一核对失败，如实报告且不得声称首页已更新。

本命令只用于新会话快速进入核算解读；进入对话后用户继续使用自然语言，不得要求再次输入命令。

核算路径或问题：$ARGUMENTS
