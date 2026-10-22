---
type: design_contract
layer: products
status: active
validity: superseded
retrieval: on_demand
effective_from: 2026-08-05
effective_to: 2026-08-05
superseded_by: 30_输出/作品/小微服务生意经营诊断Agent_本地Web原型-2026-08-04/复古未来主义霓虹像素经营沙盘-视觉样张合同-v0.1-2026-08-05.md
updated: 2026-08-05
confidence: confirmed
privacy: private
version: thinkpair-pixel-v5
---

# ThinkPair Pixel Shop Journey

## 体验合同

页面不是传统长落地页，而是一条单路由、状态驱动的三幕体验：

1. 建店：依次收集店名、城市/商圈、经营类型、面积、经营年限、团队人数；每确认一项，右侧同机位像素小店推进一帧。
2. 诊断：小店建成后居中，四类痛点环绕出现。痛点只是入口，必须由真实 AI 核对经营事实。
3. 判断：只有 AI 确认问题成立后，才生成六维经营图、一个核心判断和一个优先动作。

离线时只允许本地建店、选择痛点和填写资料；诊断按钮、六维结果和行动判断保持锁定。未知维度显示为空，不用 0 或 50 填补。

## 视觉合同

- 源风格帧：`artifacts/pixel-v5/source-style-frame.png`
- 用户参考：`C:/Users/62574/Desktop/网站素材文件夹/微信图片_20260805095419_298_1.jpg` 等 9 张像素城市与街边小店图。
- 画面：高精度电影级像素艺术、固定机位、湿地反射、城市天际线、霓虹黄昏、温暖店内灯光。
- 配色：深钴蓝与石油蓝作为场景基底，珊瑚粉做天空层次，琥珀色做店铺焦点，青色做系统状态。
- UI：克制的米白工作台 + 深色沉浸场景；不使用游戏 HUD 复刻，不使用品牌化游戏纹理。
- 文案：面向经营者本人，不出现“演示、样例、AI 帮用户”等第三方旁观口吻。

## 布局合同

- 桌面：左侧工作台约 36%，右侧场景约 64%，当前幕保持一屏完成。
- 手机：场景置顶约 36–43svh，交互面板在下方自然滚动；痛点卡改为 2×2。
- 判断幕：核心判断和唯一动作在左，六维图在右；手机端先文案后图表。

## 动效合同

- 回答字段：完整场景帧交叉淡入并轻微推近，确保真实画面改变而非进度条装饰。
- 建店完成：整幕淡出/移入诊断幕。
- 痛点：四卡分时弹入，选中时只用琥珀描边与轻微位移。
- 判断：六维图在真实 AI 结果返回后一次展开。
- `prefers-reduced-motion` 下取消位移、缩放与长过渡。

## 资产合同

- 7 张同机位 WebP：`public/assets/thinkpair-pixel-v5/shop-stage-0-plot.webp` 至 `shop-stage-6-complete.webp`。
- 原始 PNG 保存于 `artifacts/pixel-v5/source-frames/`，不进入公开静态资源。
- 运行时只使用 WebP，总计约 1.15MB；预加载同一建店序列以避免切帧闪烁。

## AI 合同

- `/api/diagnose`：证据优先的真实 OpenAI Responses API；痛点不是结论，证据不足时只追问一个问题。
- `/api/judge`：严格六维结构化输出；无证据维度为 `null + unscored`；每个非空分数必须有事实依据。
- 请求 `store:false`，输入先脱敏；未配置 `OPENAI_API_KEY` 时返回明确错误，不产生模板答案。
