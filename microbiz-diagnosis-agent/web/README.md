---
type: product_readme
layer: products
status: active
validity: current
retrieval: on_demand
effective_from: 2026-08-04T23:49:18+08:00
recorded_at: 2026-08-04T23:49:18+08:00
updated: 2026-08-05
last_reviewed: 2026-08-05
confidence: confirmed
privacy: private
entity_id: product.micro_service_diagnosis_agent
claim_key: product.micro_service_diagnosis_agent.local_web_readme
claim_value: v0.1
schema_version: temporal-governance-v2
source_refs:
  - ../产品与直播实验合同-v0.1-2026-08-04.md
  - ../本地Web原型验收记录-2026-08-04.md
---

# ThinkPair 小微服务生意经营诊断｜本地Web v0.1

用户可以直接说出经营问题，也可以从客户、成交、复购和利润四类信号进入。诊断顺序固定为：确认问题是否成立 → 分开外部盘与内部盘证据 → 保留未知与替代解释 → 只给一个可验收动作。

## 本地启动

环境要求：Node.js 22.13或更高版本。

```powershell
npm install
npm run dev
```

本机访问：`http://localhost:3000/`。

## 连接 AI

复制 `.env.example` 为 `.env.local`，填入服务端使用的 `OPENAI_API_KEY`，然后重启本地服务。模型默认使用 `gpt-5.6-terra`，也可以通过 `OPENAI_MODEL` 调整。

密钥只在服务端读取，不会写进浏览器页面。未配置或连接失败时，网页会明确显示“AI 未连接”或“AI 暂不可用”，仍可使用诊断框架记录事实，但不会冒充 AI 输出。

## 验证

```powershell
npm test
```

测试会先完成生产构建，再运行诊断逻辑与渲染结果断言。

## 当前边界

- 只在本机运行，没有公网交付链接。
- 不含登录、支付、会员、云数据库、自动抓取或正式联网数据源。
- AI 只依据本轮提交的匿名化问题、材料和最近对话，不会冒充已核验外部市场。
- 手动输入的外部信息不会被冒充为联网核验结果。
- 本地技术验收通过不等于真实用户采用、市场需求或收费成立。

产品范围见[产品与直播实验合同](../产品与直播实验合同-v0.1-2026-08-04.md)，详细结果见[本地Web原型验收记录](../本地Web原型验收记录-2026-08-04.md)。
