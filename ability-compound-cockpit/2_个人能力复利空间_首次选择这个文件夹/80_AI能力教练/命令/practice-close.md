# `/practice-close`｜关闭一次练习

## 目标

把实际过程和结果自动收口为可复查记录，提炼下一次最小调整；不因“完成了一次”自动升级能力。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。正式练习和主技能更新只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write。

## 开始前与提问

读取主技能 `current_practice_id` 指向的唯一正式练习。找不到唯一未关闭练习时列出候选，让用户指出一条，不猜测。每轮最多问三个：实际做了什么和结果是什么、有什么可复查材料、下一次只改哪个变量。

感受与事实分开。没有作品也可如实关闭，`evidence_refs` 保持空；口述结果不伪装为正式证据。

## 写入器清单

信息足够后在同一清单中准备：

- 把练习改为 `closed`，记录 `ended_at`、`result`、有效 `evidence_refs`、`next_adjustment` 和可选 `energy_state`。
- 把主技能 `current_practice_id` 清空。
- 新材料尚未形成正式证据时，只记录空间内相对位置并提示 `/evidence-add`。

本命令不修改 `evidence_state` 或 `ability_version`。Inspect 为 `routine` 时自动 Apply，无需二次确认。Apply 后复读并报告结果、证据关联和下一调整。
