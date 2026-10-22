---
type: design_contract
layer: output
status: active
validity: current
retrieval: on_demand
effective_from: 2026-07-30
confidence: confirmed
privacy: private
product: self_media_operations_dashboard
version: v0.5
---

# 自媒体经营链路看板设计合同 v0.5

## Content experiment extension

- Visual thesis: 延续雾白、雾蓝、鼠尾草与编辑黑的工作台语言，把历史回测做成一张克制的实验账本，不新增“AI大屏”或爆款仪表盘。
- Content plan: 先给三期同窗口结果和样本边界，再比较盲化回测分与实际分发，最后进入单条内容的维度、证据和下一条真盲测说明。
- Interaction thesis: 从“内容归因”进入“历史回测”，行级选择联动右侧实验检查器；桌面使用同屏主从布局，移动端按摘要、样本、详情顺序自然下落。
- Semantic boundary: 三期评分统一标为`retrospective_blinded_score`，只用于初始化 rubric；真实数据来自现有证据台账。发布前未锁定的评分不得显示为预测命中率，第四期才进入 prospective blind prediction。

## Design target

- Product: 降噪实验室自媒体经营看板
- Screen: 经营链路首页
- Surface and viewport: 桌面端工作界面，1440 × 1024 CSS px，deviceScaleFactor 1
- Intended user: 每周复盘抖音、小红书、B站内容经营结果的个人创作者与小团队负责人
- 30-second outcome: 30 秒内看清内容触达如何逐步沉淀为有效线索、深度沟通、首次付费和升级续费，并识别线索来源与近四周累计变化
- Primary action: 补数据
- Supporting actions: 切换平台、查看阶段明细、查看线索来源、切换趋势时间范围、进入内容归因与数据明细

## Visual anchors

- Primary style anchor: `reference/self-media-dashboard-visual-target-v0.5-2026-07-30.png`
- Primary anchor role: 完整控制雾白画布、雾蓝英雄区、鼠尾草绿辅助区、黑色编辑感字体、酸性青柠焦点、留白和整体产品成熟度
- Secondary anchor 1: `C:/Users/ASUS/AppData/Local/Temp/codex-clipboard-9e48e5d0-75a9-4948-8e36-39a04787700e.png`
- Secondary anchor 1 role: 只负责六级经营链路、平台分段、阶段体量比、右侧线索来源环图和近四周趋势的信息逻辑
- Secondary anchor 2: `C:/Users/ASUS/AppData/Local/Temp/codex-clipboard-ef1c15d7-fbf6-41a0-ab76-7b6f2569008d.png`
- Secondary anchor 2 role: 只确认阶段命名为“内容触达、新增关注、有效线索、深度沟通、首次付费、升级续费”，不采用其移动端裁切和紫色漏斗
- Negative reference: `reference/self-media-dashboard-visual-target-2026-07-30.png`
- Rejected traits: 紫粉渐变、玻璃拟态、漂浮卡片墙、传统大色块梯形漏斗、图表默认主题、AI替用户判断、把阶段体量比误写成用户转化率

## Information hierarchy

- Visual hero: 左侧约 64% 宽度的六级经营链路阶段轨道，内部按抖音、小红书、B站稳定顺序分段
- First eye-line: “经营链路”标题，以及由数据文件派生的内容触达、有效线索、首次付费、升级续费四个结果数字；全空时统一显示“—”
- Second eye-line: 六个阶段的总量、单位、平台构成与五个“相邻阶段比”
- Third eye-line: 右上有效线索来源环图和右下近4周累计有效线索趋势
- Deliberately de-emphasized: 发布量、点赞量、粉丝总量、单条内容明细与数据证据状态
- Off-screen or later routes: 内容归因、数据明细、证据台账、补录审核和经营建议

## Visual tokens

- Grid and margins: 12 列网格，左右 32px，列间 20px；左英雄区 8 列，右辅助区 4 列；顶部导航 72px
- Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64px
- Chinese type family and weights: MiSans、HarmonyOS Sans SC、PingFang SC、Microsoft YaHei；正文 400，标签 500，标题 600
- Numeric type family and weights: Satoshi、Outfit、Segoe UI；结果数字 500，阶段总数 500
- Type scale: 11 / 12 / 14 / 16 / 20 / 28 / 44 / 60px
- Canvas color: 冷调雾白 `#F2F4EF`
- Surface colors: 英雄雾蓝 `#DDE7EB`、辅助鼠尾草 `#DCE7DF`、暖石色 `#E6E4D7`、基础白 `#F8F9F6`
- Primary accent: 酸性青柠 `#DFFF42`，只用于当前阶段、主按钮和相邻阶段比
- Data category colors: 抖音深靛蓝 `#5662A8`、小红书砖珊瑚 `#DF7F7C`、B站灰青 `#5A9991`
- State colors: 已确认 `#2F7D65`、估算 `#C58B28`、缺失 `#B8BDB6`、冲突 `#C85555`
- Radius: 英雄区 20px，辅助区 18px，控件 10px，胶囊 999px
- Border: 1px `rgba(23,26,24,.10)`，只用于必要分隔和控件
- Shadow, blur, and texture: 不用玻璃、发光或背景渐变；仅使用 0 10px 30px `rgba(23,26,24,.05)` 的极轻表面阴影
- Icon family and stroke: Phosphor Icons，regular 或 medium，1.5–1.75px 视觉描边
- Memorable brand move: 酸性青柠“经营脊柱”连接六个阶段比，并在“有效线索”阶段形成发光焦点

## Chart system

- Hero chart and purpose: 六级分段阶段轨道，回答“内容经营体量正在在哪一级沉淀和流失”；每层内按平台占比编码，层宽使用压缩尺度表达阶段关系
- Supporting chart 1 and purpose: 三分类有效线索来源环图，回答“当前有效线索记录主要来自哪个平台”
- Supporting chart 2 and purpose: 三条近4周累计有效线索折线，回答“各平台累计线索记录是否持续增长”
- Stroke and marker language: 阶段轨道以细密圆点或连续微段组成；折线 2.5 / 2 / 2px，圆点 4px；环图分段间保留 3px 雾白间隙
- Grid and axis language: 折线仅 4 条低对比水平网格，无外框；横轴使用完整周区间，纵轴从 0 开始
- Label and annotation language: 阶段总数右对齐，平台数值直接标在段上方；折线末点直标平台名和累计值；百分比统一写“相邻阶段比”
- Hover and selection: 悬停阶段显示定义、单位、证据状态和平台构成；点击平台可联动弱化其他平台；环图与折线共用选择状态
- Empty and missing states: 未取得的数据使用空心段、虚线缺口和“未补录”，不将缺失值渲染为 0

## Data semantics

- Event units: 内容触达为平台播放或曝光事件次数，同一人多次观看会重复计数
- Person units: 新增关注、有效线索、深度沟通当前按平台记录近似为人，同一身份跨平台可能重复
- Order units: 首次付费与升级续费按已确认订单计数，退款订单不进入确认值
- Revenue units: 本首页不展示收入金额；收入留在经营趋势与数据明细
- Conversion denominators: 所有五个百分比只表示后一级总量 ÷ 前一级总量的“相邻阶段比”，不宣称同一批用户的严格转化率
- Cross-source deduplication rule: 演示数据尚未跨平台身份去重；平台筛选只改变观察范围，不改变历史归因
- Evidence states: 已确认、估算、待核、缺失、冲突；首页数字默认汇总已确认与明确标注的估算值
- Data-status label: 顶栏根据数据合同显示“空白模板 / 部分数据 / 实际数据 / 数据有冲突”；底部固定注明“缺失不作 0；阶段量比不代表用户级转化率”

## Local data package contract

- Runtime source: 预构建页面只读取 `app/data/current-data.js` 中的 `window.DASHBOARD_DATA`；该文件只能由包内校验器从 `01_看板数据.md` 的首个 JSON 代码块生成。
- AI boundary: DeepSeek 只编译指定笔记中已出现的事实，只修改数据页；不写 HTML/CSS/JS，不填总量、占比、阶段量比、图形宽度或经营决策。
- Derivation: 阶段总量只在三平台值全部已知时完整计算；局部数据只显示“≥已知值”，不参与完整阶段量比。
- Null and zero: `null` 是未知，`0` 是已确认为零；两者视觉、校验和公式均不同。
- Failure behavior: JSON 语法、schemaVersion、阶段 id、平台 id 或非负数校验失败时，不覆盖上一次合法数据。
- Local-only delivery: 预构建包优先通过只绑定 `127.0.0.1` 的本地服务打开；Node.js 不可用时使用纯 PowerShell HTTP 服务，不需要 npm 安装或公网部署。

## Interaction

- Default time range: 近4个完整周
- Filters: 全部、抖音、小红书、B站；近4周与近12周
- Primary interaction flow: 先看四个结果数字，再沿经营脊柱阅读六级阶段，点击平台或阶段查看构成与证据，最后查看来源环图和累计趋势
- Drill-down target: 单阶段平台构成抽屉、单平台内容归因、数据明细与补录审核
- Keyboard and focus expectations: 所有筛选、阶段和主要按钮可键盘聚焦；焦点环为 2px 青柠外框并保留 3px 间距；抽屉和弹窗支持 ESC 关闭
- Responsive fallback: 低于 1180px 时右侧辅助图移到英雄区下方；低于 760px 时阶段名称、数值和轨道改为单列卡片，图表保持可横向阅读

## Working UI versus sales image

- Working UI priorities: 数据口径可信、层级清晰、点击与筛选可用、长标签不截断、缺失值不伪装
- Sales image priorities: 使用通过 QA 的工作界面截图重新包装，不直接使用当前工作界面作为社交媒体海报
- Elements allowed only in sales image: 设备框、综合色卡、字体样本、功能标注和营销文案

## Implementation

- Existing runtime or template: Vite + React 负责一次性构建，日常使用为无依赖的预构建本地包；保留原有 Sites 打包链，但本交付不发布公网
- Chart implementation: Recharts 环图与折线；经营链路使用语义化按钮、CSS Grid 和可访问的分段轨道
- Token implementation: `src/styles.css` 中的 CSS variables 统一管理画布、表面、字体、间距、圆角、阴影与状态
- Fonts and asset sources: 系统中文字体栈、现有 Phosphor Icons，不新增光栅装饰资产
- Data source: 交付包默认为全 `null` 的空白数据合同；只有经过 DeepSeek 整理、人工确认并通过本地校验的数据才进入看板

## QA acceptance

- Primary reference viewport: 1440 × 1024 CSS px，deviceScaleFactor 1
- Thumbnail test: 缩放到 25% 时仍能辨认四个结果数字、一个主链路、一个来源环图和一个趋势图
- Long-label test: “跨平台身份未去重”“升级续费”等标签不换行破版
- Zero, missing, and extreme-value test: 平台 0 值、阶段缺失、单平台极端占比和长周区间不破坏轨道、环图与折线
- Reference-comparison passes: 至少完成一次宏观构图、一次微观字体与图表、一次数据口径压力测试；参考图和实现截图必须在同一比较输入中检查
- Accessibility checks possible from implementation: 对比度、焦点可见、键盘操作、ESC 关闭、图表 aria-label、颜色之外的平台标签与减少动态效果偏好
