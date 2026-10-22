---
description: 建立当前唯一主技能与固定六维证据地图
---

先读取 `.claude/hooks/ability-write-usage.md`，再读取 `80_AI能力教练/命令/skill-start.md` 并严格执行。结合 `$ARGUMENTS`，每轮只问 1—3 个真正影响主技能、目标、六维、证据标准或基线的问题。空白空间的主技能和六维文件已经存在，七项操作全部使用 `update`；七份完整内容都必须显式写入 `created_at: AUTO_NOW` 和 `updated_at: AUTO_NOW`。信息足够后建立同含七项操作的 `ability-write.v1` 清单并 Inspect，`routine` 自动 Apply、复读并汇报。替换已有 active 主技能时，Inspect 返回 `confirmation_required` 后确认一次再 Apply。禁止直接 Edit/Write 正式文件。
