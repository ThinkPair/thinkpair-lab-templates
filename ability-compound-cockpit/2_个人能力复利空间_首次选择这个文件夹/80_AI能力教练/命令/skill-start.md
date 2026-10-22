# `/skill-start`｜建立主技能与六维

## 目标

在空白空间建立一项当前主技能和六个可定制能力维度。不得把职业年限、自我评价或 AI 判断写成已验证能力。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。正式记录只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write 七个目标文件。

## 权限判断

- 主技能和六维模板均为空、没有 active 主技能：属于普通写回。信息足够后创建包含七项操作的同一清单；Inspect 为 `routine` 时自动 Apply、复读并汇报，不再询问“是否保存”。
- 已存在 confirmed + active 主技能：替换属于高影响变化。先问清新技能、目标和现有练习如何处理，再给一次摘要确认卡；确认前不覆盖当前主技能。
- 同一 active 主技能的目标、基线或六维调整，按实际影响分类；涉及身份替换、状态/版本或大批量 confirmed 修改时走高影响确认。

## 提问节奏

第一轮最多问三个：主技能是什么、希望产生什么可观察结果、当前有哪些真实作品/结果/反馈可作基线。根据回答提出六维草案；再最多问三个会改变六维名称、达标证据或基线归类的问题。用户明确接受草案或信息已完整后立即执行普通建档。

## 生成与写入器提交

- `20_能力地图/主技能.md`：初始化唯一 `record_id`/`skill_id`/时间，写入 `record_status: confirmed`、`status: active`、`ability_version: v0.1`、`dimension_count: 6`。
- 六个维度各一文件：初始化唯一身份字段，顺序严格 1—6，名称不重复，成功标准能被作品或反馈验证。
- 新空间没有正式证据时，六维均为 `evidence_state: unproven`、`evidence_refs: []`；经验自述只写基线。
- 默认 `privacy: private`；含第三方或高风险专业材料提高为 `sensitive`。
- 七项完整目标内容必须放在同一个 `ability-write.v1` 清单中。七个目标文件在空白空间中已经存在，所以七项 `action` 全部使用 `update`，不得使用 `create`；每份完整 Markdown 都必须显式包含 `created_at: AUTO_NOW` 和 `updated_at: AUTO_NOW`，不得省略。由 Inspect 完整校验后再按判级 Apply；全部有效后主技能才激活，失败时不得留下半初始化记录，重试不得产生第二组 ID。

Apply 后复读主技能、六个顺序和六个证据状态，报告已建立的主技能、六维和下一步 `/practice-plan`。替换已有主技能时，只有 Inspect 返回 `confirmation_required` 才展示确认卡；只列变化、现有数据影响、可撤销性及返回的 `preview_id` 与 `payload_hash`，确认后对同一清单 Apply。
