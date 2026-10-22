# 导出当前 AI 对话｜读取真实会话源

本命令只在用户明确要求保存或导出 AI 对话时使用。不得凭当前上下文“尽力还原”，不得自动导出所有会话。

1. 在 `.claudian/sessions` 中定位用户指定或当前标签对应的 `conv-*.meta.json`，只读取会话 ID、标题、时间和关联的 Claude session ID；不得读取 `.claudian/claudian-settings.json`。
2. 调用只读预演：

```text
node .claude/skills/commercial-operations-expert/scripts/session-export.js --preview --conversation <conv-id>
```

3. 向用户展示目标文件、标题、源消息数、完整性口径和“会自动遮蔽疑似密钥”；不展示内部授权或脚本参数。
4. 用户已经明确要求保存或导出本次对话，该指令就是授权。只调用：

```text
node .claude/skills/commercial-operations-expert/scripts/session-export.js --export --conversation <同一 conv-id>
```

5. 若 AI 主动建议导出但用户尚未表达写入意图，只展示一次包含目标、源消息数、会脱敏且不进入默认检索的短预览；语义不足时将上述 `--export` 操作交给原生确认一次。
6. 写后复读目标，报告真实导出结果；不把归档内容放回默认检索。

用户补充：$ARGUMENTS
