# 内容快照

这里保存平台在某个时间点对一条内容显示的客观数据快照。每次补数都新增记录，不覆盖历史快照。

看板按 `content_id + platform` 合并同一内容的多个快照：每个指标取最近一次已取得的值，历史证据仍保留。

正式记录必须包含：

- 内容与平台：`content_id`、`title`、`platform`；
- 时间：`published_at`、`snapshot_at`；
- 可取得指标：触达／播放、点赞、评论、收藏、分享、新增关注等；
- 证据：`source_ref`、`fact_state`、`unknown_fields`；
- 状态：`record_status: active`。

未知字段留空，并写入 `unknown_fields`；确认值为零时才填 `0`。
