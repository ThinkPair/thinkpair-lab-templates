# 证据与反馈

- `证据记录/` 保存作品、前后对比、过程记录和证书等证据。
- `反馈记录/` 保存外部评价；记录类型仍为 `evidence_item`，并使用 `evidence_type: external_feedback`。
- 保存来源、隐私级别、关联练习与关联维度。只有自评不能被标记为外部验证。
- 证据源发生实质变化时，创建新版本并把旧证据的 `evidence_validity` 改为 `superseded`；引用旧版本的结论进入 `needs_review`，不继续展示为当前结论。

在 AI 侧栏输入 `/evidence-add` 添加正式证据。

