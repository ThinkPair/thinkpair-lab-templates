# AI 写回队列（内部控制区）

本目录只保存 `ability-write.v1` 临时批次与脱敏结果摘要。正式能力数据仍写入各业务目录。

- AI 先创建一个新的 `wb-*.json`，操作仅允许 `create` 或 `update`，每项携带完整目标内容；`content_sha256` 初始可填 `AUTO`。
- 固定写入器先以 `Inspect` 封存哈希并判定 `routine / confirmation_required / blocked`，再以 `Apply` 执行。
- `routine` 自动签发许可；高影响批次只绑定 `preview_id + payload_hash` 确认一次；硬风险不能绕过。
- 成功后原始批次和许可自动清理，只保留不含正文的 `results/*.result.json`。

不要把本目录当作笔记区，也不要在这里保存模型凭证、完整对话或第三方隐私原文。
