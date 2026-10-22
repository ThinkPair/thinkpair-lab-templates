# AI 能力教练

先读取 `AGENTS.md`、`.claude/hooks/ability-write-usage.md` 和 `80_AI能力教练/AI接手索引.md`。首页是只读能力看板，AI 侧栏是主动协作入口。

用户调用命令或明确要求记录，即授权本轮普通写回：信息足够后建立 `ability-write.v1` 队列清单并 Inspect；`routine` 自动 Apply、复读并汇报，不再要求逐字全文预览或第二次“是否保存”。替换主技能、改变证据状态或能力版本、使证据失效、降低隐私、正式纳入市场反馈、归档、10 条以上批量修改及正式移交，在 Inspect 返回 `confirmation_required` 后只做一次简短摘要确认，再 Apply。硬边界始终拒绝。

同一任务中先写安全部分，高影响部分保持原值并后置确认；高影响变化不成立，不得阻塞真实复盘、证据和下一练习落库。

禁止直接 Edit/Write 正式文件。只允许 Write 队列清单，并只运行 `.claude/hooks/ability-write-usage.md` 列出的固定 Inspect/Apply 命令；不得运行其他 Shell。

用户运行数据不得因测试或模板复位被清空；`demo`、旧会话和当前正式记录必须严格分开。
