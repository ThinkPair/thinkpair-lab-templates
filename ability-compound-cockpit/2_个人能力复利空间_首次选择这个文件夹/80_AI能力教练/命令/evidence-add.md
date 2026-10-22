# `/evidence-add`｜添加一项证据

## 目标

把作品、前后对比、过程记录、外部反馈或证书沉淀为可追溯证据。一项材料一条 Markdown；证据录入与能力升级分开。

执行前必须读取 `.claude/hooks/ability-write-usage.md`。正式证据只走 `ability-write.v1` 队列 → Inspect → Apply，禁止直接 Edit/Write 证据或反馈记录。

## 提问与校验

每轮最多问三个：材料是什么和产生时间、空间内相对位置或可追溯来源、它具体显示哪个维度的什么结果。外部反馈只补问是否已脱敏、是否确由外部提供。

- 必须关联当前 `skill_id` 和至少一个有效维度。
- `source` 不保存本机绝对路径；`summary` 只写材料中可观察事实。
- 自评使用 `verification_level: self_recorded`，不得冒充外部反馈。
- 外部反馈去除姓名、电话、账号、地址、价格和财务信息；需要时自动提高为 `privacy: sensitive`。
- 同源材料检查哈希和版本，不能把同一来源重复计为多项独立证据。

## 先经写入器保存证据

信息足够后为 confirmed、current 的 `evidence_item` 建立清单，完整内容包含来源、摘要、关联维度、验证级别、隐私和版本关系。Inspect 为 `routine` 时自动 Apply。`supports_state_candidate` 只是候选，本命令不改维度 `evidence_state`。

若材料实质变化，先用 routine 独立清单安全保存新版本，但不把新旧同源记录重复计数；旧版本 `superseded` 与旧结论失效使用另一清单 Inspect，返回 `confirmation_required` 后发一次摘要确认卡，确认后 Apply。提高隐私保护可经 routine 自动 Apply，降低隐私保护必须确认。

Apply 后复读并报告证据标题、关联维度和验证级别。若可能支持升级，只建议随后使用 `/skill-review`，不得在本命令中升级。
