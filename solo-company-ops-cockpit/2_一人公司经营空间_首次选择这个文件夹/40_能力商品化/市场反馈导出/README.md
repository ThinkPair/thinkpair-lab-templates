# 市场反馈导出记录

本目录只保存已经由用户确认脱敏、准备回流个人能力工具的 `market_feedback`。每条记录一份 Markdown，创建后正文和来源字段不可修改。

只有包含有效 `source_transfer_id`、`source_transfer_hash` 和 `source_validation_id` 的导入能力验证才能生成回流卡。原生商业验证没有对应个人能力卡时不得伪造来源。

反馈卡业务正文严格限制为：

- `feedback_summary`
- `skill_gap`
- `next_practice_candidate`

个人端导入后仍保持 `record_status: draft`；商业端确认导出不等于个人端已经接受，也不自动升级能力。

根产品母版和发布净包中本目录只能保留本 README。
