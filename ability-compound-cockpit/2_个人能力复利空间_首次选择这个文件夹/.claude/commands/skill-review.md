---
description: 生成基于证据的周期复盘与下一练习
---

先读取 `.claude/hooks/ability-write-usage.md`，再读取 `80_AI能力教练/命令/skill-review.md` 并严格执行。结合 `$ARGUMENTS`，先为复盘、最大差距和下一练习建立 `ability-write.v1` routine 清单，Inspect 后自动 Apply 并复读。证据状态、能力版本或旧结论有效性另建高影响清单，Inspect 返回 `confirmation_required` 后确认一次再 Apply；未确认或证据不足不得阻塞安全复盘。禁止直接 Edit/Write 正式文件。
