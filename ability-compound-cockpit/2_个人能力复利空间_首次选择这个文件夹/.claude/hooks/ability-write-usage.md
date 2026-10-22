# AI 主动写回调用协议

普通写回不要询问“是否保存”。信息足够后按以下顺序执行；只有 `Inspect` 返回 `confirmation_required` 才向用户确认一次。

## 1. 新建批次清单

用 `Write` 新建 `.claude/write-queue/wb-<唯一编号>.json`。不要直接 Edit/Write 正式记录。清单结构：

```json
{
  "schema_version": "ability-write.v1",
  "batch_id": "wb-20260713-example",
  "command": "practice-plan",
  "preview_id": "preview-wb-20260713-example",
  "operations": [
    {
      "action": "create",
      "path": "30_刻意练习/练习记录/practice-example.md",
      "content": "这里必须是完整 Markdown 目标内容；新记录可在 frontmatter 使用 created_at: AUTO_NOW 与 updated_at: AUTO_NOW",
      "content_sha256": "AUTO"
    }
  ]
}
```

`action` 只允许 `create | update`；同一批次路径不得重复。`create` 只用于目标路径尚不存在的新记录；只要目标文件已经存在，即使它还是空模板，也必须使用 `update`。首次 `/skill-start` 的主技能和六个固定维度都是已存在模板，因此七项操作必须全部使用 `update`，不得先尝试 `create`。

时间字段不可省略，统一使用 `AUTO_NOW`，不要先调用 `date`、`Get-Date` 或任何取时 Shell：

- `create` 或首次初始化空模板：完整 Markdown 必须同时显式包含 `created_at: AUTO_NOW` 与 `updated_at: AUTO_NOW`；Inspect 会替换为本机带时区 ISO 时间。
- `update`：只把 `updated_at` 写成 `AUTO_NOW`，原 `created_at` 必须保留；即使误填 `created_at: AUTO_NOW`，已初始化记录也只会恢复原创建时间。首次填充空模板时是唯一例外，空的创建时间会被初始化为当前时间。
- Inspect 替换时间后会重新计算每项 `content_sha256` 与整个 `payload_hash`。

## 2. Inspect 封存并判级

只能通过 Bash、Shell 或 PowerShell 工具调用这一条完全匹配的固定命令（替换清单文件名）：

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude/hooks/ability-write.ps1" -Manifest ".claude/write-queue/wb-20260713-example.json" -Mode Inspect
```

- `routine`：立刻执行 Apply，不向用户再次确认。
- `confirmation_required`：只展示“改什么、依据、影响、是否可撤销/是否出库”，以及返回的 `preview_id`、`payload_hash`；用户自然语言确认一次后执行 Apply。
- `blocked`：修正事实或数据，禁止尝试绕过。

用户提问不会使预览失效；用户提出“改成、调整、修改、增删、重做”等修订后，旧预览立即失效。内容变化后必须重新 Inspect；即使内容恰好未变，也要重新展示同一 `preview_id + payload_hash` 后再接收确认。

## 3. Apply 写入

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".claude/hooks/ability-write.ps1" -Manifest ".claude/write-queue/wb-20260713-example.json" -Mode Apply
```

成功后向用户简要报告目标路径和关键结果。写入器会整体校验、多文件回滚、清理正文清单，并在 `results/` 留下不含正文的摘要。

禁止调用其他 Shell，包括单独的 `date`、`Get-Date`、文件命令或把额外参数/管道拼到 writer 后；禁止直接写正式记录、内核、插件、示例区或另一个 Obsidian 空间。
