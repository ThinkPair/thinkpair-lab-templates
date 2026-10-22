# `/practice-plan`｜生成唯一刻意练习

## 目标

针对当前证据最弱且最影响目标成果的一个维度，生成一条范围小、结果可观察的刻意练习。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。正式练习和主技能更新只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write。

## 开始前

1. 确认唯一正式主技能与刚好六个正式维度。
2. 读取最新正式复盘、当前证据和未关闭练习。
3. 若已有 `planned | in_progress` 练习，不创建第二条。先让用户选择继续当前练习，或先用 `/practice-close` 收口；这属于事实选择，不是保存确认。
4. 证据最弱综合状态、有效证据数量、最近性和对目标成果的影响，不只看练习次数。

## 提问节奏

每轮最多问三个：本次具体差距、可投入时间/材料、可观察完成信号。精力状态只在用户愿意时记录。信息够用即建立写入器清单。

## 写入器清单

新建一条 `practice_record` confirmed 记录，状态为 `planned`，关联一个有效维度，写清 `practice_goal`、`deliberate_constraint`、`success_signal` 和步骤；计划阶段的 `result`、`evidence_refs`、`next_adjustment` 留空。同时更新主技能 `current_practice_id`。

本命令不修改 `evidence_state` 或 `ability_version`。把新练习与主技能更新放进同一清单；Inspect 为 `routine` 时自动 Apply，无需二次保存确认。Apply 后复读，并只告诉用户：现在练什么、完成信号是什么、完成后使用 `/practice-close`。
