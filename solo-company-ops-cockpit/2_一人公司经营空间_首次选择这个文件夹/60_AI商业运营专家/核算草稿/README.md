---
record_type: directory_readme
privacy: private
retrieval: excluded
sharing_scope: internal
---

# 核算草稿

这里只保存根据用户代填指令、准备载入创业算账页的临时输入。草稿使用 `record_type: calculation_draft`、`draft_status: ready`和 `schema_version: calculation_draft.v1.1`；`preview_hash` 是计算页用来复算输入的 FNV 业务哈希，不是写入权限令牌，不需要用户或 AI 核对。计算页载入后将草稿标记为 `consumed`。草稿不是正式核算，不参与首页、经营结论或目标倒推；正式记录只能由计算页再次核对并确认保存后生成。

发布、演示和空白母版不得包含 README 以外的草稿文件。
