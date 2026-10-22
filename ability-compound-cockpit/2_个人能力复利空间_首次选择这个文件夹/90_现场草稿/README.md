---
page_type: system_readme
record_status: system
privacy: private
---

# 现场草稿

当 AI 暂时不可用时，可从首页新建现场草稿。

- 现场草稿固定为 `record_type: field_draft`、`record_status: draft`。
- `excluded_from_statistics: true`，不会进入首页数字、复盘或能力等级判断。
- 草稿不能直接变成正式证据，也不能生成正式能力移交卡。
- AI 恢复后，用 `/evidence-add` 或 `/practice-close` 整理；普通证据和练习记录会直接另建并复读，能力等级仍需单独确认。
