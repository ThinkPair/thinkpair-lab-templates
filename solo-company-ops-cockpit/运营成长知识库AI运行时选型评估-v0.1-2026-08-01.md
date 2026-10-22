---
type: product_architecture_assessment
layer: output
status: archived
validity: superseded
retrieval: excluded
effective_from: 2026-08-01T07:41:45+08:00
effective_to: 2026-08-01T09:27:18+08:00
recorded_at: 2026-08-01T07:41:45+08:00
created: 2026-08-01
updated: 2026-08-01
confidence: inferred
privacy: private
entity_id: product.free_knowledge_base.ai_runtime
claim_key: product.free_knowledge_base.ai_runtime_selection
claim_value: keep_agent_neutral_claude_deepseek_default_codex_deepseek_experimental_pending_blackbox
superseded_by: 20_理解/Claudian-Claude-Code-Codex-DeepSeek功能边界与选型评估-2026-08-01.md
change_reason: DeepSeek 于 2026-08-01 已提供官方 Responses API 与 Codex 直连文档，原评估中“Codex+DeepSeek 需要第三方 Responses 网关”的前提失效；新版评估同时补齐图片能力与 Claudian/独立 Codex 宿主边界。
source_refs:
  - 10_Sources/用户确认自用知识库与交付产品AI底座边界-2026-08-01.md
  - local:.obsidian/plugins/realclaudian/manifest.json
  - local:.obsidian/plugins/realclaudian/data.json
  - local:user_codex_config_redacted_inspection_2026-08-01
  - https://github.com/YishenTu/claudian/blob/main/README.md
  - https://github.com/YishenTu/claudian/blob/main/CLAUDE.md
  - https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers
  - https://learn.chatgpt.com/docs/config-file/config-reference#configtoml
  - https://api-docs.deepseek.com/quick_start/pricing/
  - https://api-docs.deepseek.com/guides/tool_calls
  - https://openrouter.ai/docs/api/reference/responses/overview
schema_version: temporal-governance-v2
---

# 运营成长知识库 AI 运行时选型评估 v0.1

## 结论

首版不把底座从`Claude Code + DeepSeek`整体替换成`Codex + DeepSeek`。

这里必须区分两条一直并行的路线：用户自己的Personal OS一直以Codex为主要AI运行时；准备对外交付的运营成长知识库，此前一直按`Obsidian + Claudian + Claude Code运行时 + DeepSeek模型`设计。本评估只讨论是否改变第二条路线，不是在给用户自用知识库更换底座。

推荐结构：

```text
知识库本体：Obsidian + Markdown，可在不配置AI时使用
交互外壳：Claudian
默认用户侧AI：Claude Code运行时 + DeepSeek官方接口
可选高级路径：Codex运行时 + OpenAI模型
实验路径：Codex运行时 + DeepSeek，经兼容网关和黑盒验收后再决定是否转正
制作端：Z总继续使用当前Codex/GPT环境开发产品，不等于用户侧也必须使用同一运行时
```

这不是认为 Claude Code 永远优于 Codex，而是首版必须优先减少协议层、账号层和售后层的不确定性。

## 先拆清楚四层

```text
Obsidian：保存Markdown和附件
Claudian：Obsidian里的聊天、选区、会话和Agent界面
Claude Code / Codex：负责读写文件、调用工具、权限、上下文和任务循环的Agent运行时
DeepSeek：真正生成内容和工具调用决策的模型服务
```

所以`Claude + DeepSeek`与`Codex + DeepSeek`即使使用同一个DeepSeek模型，也不会得到完全相同的行为。中间的Agent运行时会改变系统提示、工具协议、上下文压缩、权限确认、会话恢复和失败处理。

## 本机当前事实

- 用户自用的当前知识库一直以Codex作为主要AI运行时；对外产品此前一直设计为Claude Code运行时承接DeepSeek。两者不是同一个部署对象。
- Claudian插件版本为`2.0.25`，插件本身同时支持Claude Code与Codex等运行时。
- 本vault的Claudian当前选中的实际提供方是`Codex`，不是Claude。
- 本机Codex CLI版本为`0.145.0`；当前Codex使用OpenAI模型，不是DeepSeek。
- 当前配置中没有已验收的Codex直连DeepSeek provider，不能把“可填写自定义模型”写成“DeepSeek已经在Codex里跑通”。
- 未读取、记录或复制任何API密钥值。

## 两种组合的实质区别

| 维度 | Claude Code + DeepSeek | Codex + DeepSeek |
|---|---|---|
| Claudian成熟度 | Claude是Claudian的完整功能提供方 | Codex已支持发送、流式、恢复、分叉、计划、图片、内联编辑、Skills和子Agent，但上游仍标注部分能力不完整 |
| 指令入口 | 原生偏`CLAUDE.md`、Claude Skills/Commands | 原生偏`AGENTS.md`、Codex Skills/Plugins/MCP |
| DeepSeek直连协议 | DeepSeek官方已提供Anthropic格式接口，可少一层网关；仍须做Claude Code黑盒兼容测试 | 官方Codex自定义provider当前只支持Responses API；DeepSeek官方直连主要是Chat Completions/Anthropic格式，不能仅凭OpenAI-compatible字样判定完整兼容 |
| 若经OpenRouter | 可用，但不是必须 | OpenRouter提供Responses API转换，理论上能承接Codex，但当前标为Beta且无服务端会话状态 |
| 数据路径 | 用户设备→DeepSeek | 用户设备→OpenRouter→实际模型服务商，增加一个数据与故障环节 |
| 成本 | DeepSeek官方直付；实际成本还受Agent提示和工具循环影响 | DeepSeek模型费之外还要核对网关计费、路由和失败重试；不能只比较模型单价 |
| 售后复杂度 | Obsidian、Claudian、Claude Code、DeepSeek四层 | 再增加Codex provider配置和可能的协议网关，首版排障面更大 |

## 当前协议判断

1. Codex官方确实支持自定义model provider，包括`base_url`、认证和请求头。
2. 但当前Codex文档把`model_providers.<id>.wire_api`限定为`responses`。
3. DeepSeek官方提供OpenAI格式与Anthropic格式，并支持工具调用；其OpenAI格式文档展示的是`chat.completions`，不能自动等同于Responses API。
4. OpenRouter提供Responses API，但明确标注为Beta和stateless，因此适合作为实验适配层，不适合未经回归就作为免费产品的小白默认链路。
5. DeepSeek旧别名`deepseek-chat`与`deepseek-reasoner`已进入弃用切换期，首版不能把这两个名称永久写死；模型名称必须独立放进可更新配置。

## 对首版产品的建议

### 1. 知识库本体必须与模型解耦

核心目录、模板、身份资料、行动记录、时间先后规则和写回白名单都放在Markdown中。AI没配置时，用户仍然能够打开、记录、查看和使用。

### 2. 只维护一份核心规则

建议设置一个真实规则源，例如：

```text
00_开始这里/AI协作与写回规则.md
```

`AGENTS.md`和`CLAUDE.md`只做薄适配，均指向同一规则源，避免两套文件长期漂移。

### 3. 不把API密钥装进交付包

交付物只能提供配置入口和检查脚本。每位用户必须使用自己的密钥；不得共享Z总的密钥，也不得把密钥写入同步目录、示例截图或会话记录。

### 4. 前台不强调技术组合

用户看到的应该是“运营成长知识库”和“可选AI助手”，不是Claude、Codex、Responses API和网关。技术栈只放在安装说明和故障排查中。

### 5. Codex路线先作为兼容实验

如果要验证Codex + DeepSeek，使用同一份克隆测试vault、同一个DeepSeek模型和同一批任务，不直接改正式母版。

## 转正前黑盒验收

两条运行时各完成以下任务：

1. 首次安装至完成第一次有效回答所需分钟数。
2. 从五份散乱资料生成索引，但不得凭空补身份。
3. 正确区分当前事实与历史事实。
4. 用户明确要求后写入白名单目录；未授权时不写。
5. 连续修改三份互链Markdown且不破坏YAML与Wiki-links。
6. 遇到冲突事实时先询问，不自行选边。
7. 失败后能够恢复会话，不重复或污染文件。
8. 记录总耗时、API输入输出token、费用、工具失败数和人工救援次数。

建议转正门槛：

```text
8项全部完成
身份/时间事实误写 = 0
破坏文件 = 0
人工技术救援 <= 1次
首次安装 <= 15分钟
重复运行3轮没有偶发性协议错误
```

在达到门槛以前，不能仅凭一次能聊天就把Codex + DeepSeek写成默认交付。

## 当前待用户确认

- 首版是否接受`Claude Code + DeepSeek`继续作为默认用户侧AI路径。
- 是否把Codex定义为“有OpenAI/Codex账号用户的可选路径”，而不是强行与DeepSeek绑定。
- 免费知识库首次无AI也能获得的明确结果是什么。

## 外部依据

- [Claudian README：多Provider、隐私与本地存储说明](https://github.com/YishenTu/claudian/blob/main/README.md)
- [Claudian架构状态：Claude与Codex能力边界](https://github.com/YishenTu/claudian/blob/main/CLAUDE.md)
- [Codex自定义模型提供方](https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers)
- [Codex config.toml字段参考](https://learn.chatgpt.com/docs/config-file/config-reference#configtoml)
- [DeepSeek模型、协议与价格](https://api-docs.deepseek.com/quick_start/pricing/)
- [DeepSeek工具调用](https://api-docs.deepseek.com/guides/tool_calls)
- [OpenRouter Responses API Beta](https://openrouter.ai/docs/api/reference/responses/overview)
