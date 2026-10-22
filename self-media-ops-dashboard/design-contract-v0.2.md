---
type: design_contract
layer: output
status: archived
validity: superseded
retrieval: on_demand
effective_from: 2026-07-30
effective_to: 2026-07-30
confidence: confirmed
privacy: private
product: self_media_operations_dashboard
version: v0.2
superseded_by: design-contract.md
---

# 自媒体运营看板高保真设计合同 v0.2

## Design target

- Product: 降噪实验室自媒体运营看板模板
- Screen: 转化漏斗首页
- Surface and viewport: 桌面端工作界面，1440 × 1024 CSS px，deviceScaleFactor 1
- Intended user: 每周复盘抖音、小红书、B站内容经营结果的个人创作者与小团队负责人
- 30-second outcome: 30 秒内确认触达、线索、付费与实收结果，识别主要来源、近四周变化、当前漏损位置与数据证据边界
- Primary action: 补录数据
- Supporting actions: 切换时间范围、切换平台、查看漏斗阶段明细、确认待核数据、进入内容归因与数据明细

## Visual anchors

- Primary style anchor: `10_Sources/原始材料/小红书账号119729270图片提取-2026-07-30/图片/001_看板设计灵感｜18组配色与排版｜Dashboard_680b7e7f/001.webp`
- Primary anchor role: 控制柔雾暖白画布、低饱和紫粉光感、细字重、宽松留白、轻薄表面与整体空间节奏
- Secondary anchor 1: `10_Sources/原始材料/小红书账号119729270图片提取-2026-07-30/图片/005_设计灵感｜物流绩效看板与社交媒体营销看板_6a117886/002.webp`
- Secondary anchor 1 role: 仅用于社交媒体平台筛选、主图与支持图的分区关系，不继承其左侧栏与默认面积图
- Secondary anchor 2: 不使用
- Secondary anchor 2 role: 不使用
- Negative reference: `10_Sources/原始材料/产品反馈/自媒体运营看板首版方向确认-2026-07-30/自媒体流量转化漏斗视觉草图-2026-07-30.jpg`
- Rejected traits: 大块平铺浅紫卡片、三种平台色在六层漏斗中等强度重复、默认饼图和折线图气质、所有模块同等抢眼、字号偏重、图表与页面缺少统一材质、依赖装饰性圆角而没有品牌记忆点

## Information hierarchy

- Visual hero: 左侧约 64% 宽度的六阶段分段漏斗轨道，强调“有效线索”阶段和阶段单位变化
- First eye-line: 页面标题、四个核心结果与漏斗英雄区
- Second eye-line: 右上有效线索来源环图及平台筛选
- Third eye-line: 右下近四周线索趋势和数据证据完整度
- Deliberately de-emphasized: 导入来源、数据质量说明、跨平台未去重声明、更新时间
- Off-screen or later routes: 内容归因、单条内容明细、原始证据、口径设置、数据导入历史

## Visual tokens

- Grid and margins: 12 列网格；桌面外边距 28px；主内容 8+4 列；列间距 18px；顶栏 64px
- Spacing scale: 4 / 8 / 12 / 18 / 24 / 32 / 48 / 64px
- Chinese type family and weights: `"PingFang SC", "Microsoft YaHei", "Noto Sans SC", sans-serif`；300/400/500/600
- Numeric type family and weights: `"Inter", "SF Pro Display", "Segoe UI", sans-serif`；300/400/500/600，启用 tabular-nums
- Type scale: 44/48 页面结果数字；34/42 页面标题；28/34 图表总数；18/26 模块标题；14/22 正文；12/18 元信息；10/14 图表辅助标签
- Canvas color: `#F4F2F8` 暖灰紫画布，叠加不影响可读性的低对比柔雾背景资产
- Surface colors: 主表面 `rgba(255,255,255,.78)`；支持表面 `rgba(255,255,255,.58)`；强调表面 `rgba(236,231,255,.82)`
- Primary accent: ultraviolet `#6D4CFF`，只控制选中态、英雄漏斗焦点和关键趋势
- Data category colors: 抖音 `#6D4CFF`；小红书 `#EF8A98`；B站 `#69BFC0`；默认降低到 58%–78% 明度/透明度，禁止全页满饱和重复
- State colors: confirmed `#2F746A` + 实心圆；estimated `#9A6B25` + 半实心圆；unknown `#70727A` + 空心圆；conflict `#B8485D` + 菱形；missing `#9B9DA6` + 虚线
- Radius: 页面级英雄面 28px；支持面 22px；按钮 12px；胶囊 999px
- Border: `1px solid rgba(50,45,72,.09)`；选中态 `rgba(109,76,255,.28)`；禁止多层粗描边
- Shadow, blur, and texture: `0 22px 70px rgba(49,39,82,.09)`；支持面 `0 8px 28px rgba(49,39,82,.06)`；背景柔雾仅作环境资产；表面 `backdrop-filter: blur(18px)`；不使用厚重发光
- Icon family and stroke: Phosphor Icons，regular/16–20px；交互图标统一 1.5px 视觉线重
- Memorable brand move: 从漏斗入口向“有效线索”收束的一条半透明紫色转化光束，配合酸性黄绿 `#C8FF45` 的单点阶段刻度；黄绿只出现于当前漏损/焦点，不作为平台色

## Chart system

- Hero chart and purpose: 六阶段 segmented stage rails，回答“触达如何变成线索、沟通和订单，当前漏损发生在哪里”；混合单位，不宣称同一人群 cohort 转化
- Supporting chart 1 and purpose: 三平台有效线索环图，回答“当前有效线索主要来自哪里”
- Supporting chart 2 and purpose: 三平台近四周有效线索折线，回答“来源变化是持续增长还是单周波动”
- Stroke and marker language: 主趋势 2.5px 实线 + 6px 实心圆；次趋势 1.5px 低饱和线 + 4px 圆；环图统一 10px 视觉分隔；漏斗焦点段 1px 内高光
- Grid and axis language: 折线仅保留 3 条 `rgba(57,51,75,.08)` 水平网格；隐藏 y 轴轴线；x 轴 11px 灰紫；零基线从 0 开始
- Label and annotation language: 漏斗左侧阶段名、轨道内平台数值、右侧总数+单位；折线末点直接标注平台和数值；环图中心显示 26 人与“有效线索”
- Hover and selection: 漏斗 hover 显示平台数、证据状态与可比较口径；点击阶段锁定；平台胶囊跨过滤环图和折线；tooltip 为轻薄白色表面
- Empty and missing states: 0 使用真实零；missing 使用虚线空轨并显示“待补录”；unknown 不绘制为 0；conflict 在数值旁显示菱形并进入待确认区

## Data semantics

- Event units: 内容触达为平台事件次数，显示“次”
- Person units: 新增关注、有效线索、深度沟通按平台记录数近似为“人”，不保证跨平台去重
- Order units: 首次付费与升级续费为订单数，显示“单”
- Revenue units: 实收人民币元，显示“¥”，不与订单数混用
- Conversion denominators: 仅显示语义可比的关注→有效线索、有效线索→深度沟通、首次付费→升级续费；触达→关注只显示阶段量，不标精确人群转化率
- Cross-source deduplication rule: 演示数据不做跨平台身份去重；同一用户在多个平台可能重复计入，页面固定声明
- Evidence states: confirmed / estimated / unknown / conflict / missing，均使用文字+形状，不能只靠颜色
- Demo-data label: 顶栏固定显示“演示数据 · 更新于 2026-07-30 14:20”，页脚再次声明“所有数值均为演示数据”

## Interaction

- Default time range: 近 4 周
- Filters: 近 4 周/近 12 周；全部/抖音/小红书/B站；全部证据/已确认/待确认
- Primary interaction flow: 点击“补录数据”→选择截图/CSV/手动录入→预览提取字段→确认或标记未知→本地更新图表→返回首页看到更新结果
- Drill-down target: 当前选中漏斗阶段的侧边明细抽屉，包含平台来源、内容标题、证据状态、更新时间与原始记录入口
- Keyboard and focus expectations: 所有按钮、胶囊、标签页和抽屉可 Tab 到达；`:focus-visible` 使用 2px 紫色外环；Esc 关闭抽屉/弹窗
- Responsive fallback: 1024–1199px 保留漏斗英雄并把右栏叠到下方；小于 768px 改为单列，漏斗每阶段变为横向堆叠条，平台标签移入展开明细，优先保留四个结果和英雄图

## Working UI versus sales image

- Working UI priorities: 快速读数、口径可信、长时间使用舒适、筛选和补录可操作、未知不伪装成零
- Sales image priorities: 使用通过验收的工作界面截图，强化“开包即用、离线本地、三平台、漏斗复盘”卖点
- Elements allowed only in sales image: 产品卖点标注线、设备框、价格、促销 CTA、背景舞台、配色与字体样本、功能编号

## Implementation

- Existing runtime or template: 新建 Product Design desktop prototype Vite + React + TypeScript 模板，作为独立自媒体行业模板，不覆盖现有一人公司通用 Web 原型
- Chart implementation: Recharts 自定义主题；漏斗使用语义化 DOM + CSS clip-path 轨道，不使用手绘 SVG；所有交互图标来自 `@phosphor-icons/react`
- Token implementation: CSS custom properties 集中在 `:root`，图表颜色和尺寸通过组件常量引用同一合同
- Fonts and asset sources: 本机系统中文字体栈 + Inter/Segoe UI；背景柔雾资产由 ImageGen 目标图确定，不使用第三方品牌 Logo
- Realistic data source: `自媒体运营看板首版用户逻辑合同-v0.1-2026-07-30.md` 的演示数据；所有页面明确标注演示数据

## QA acceptance

- Primary reference viewport: 1440 × 1024 CSS px，deviceScaleFactor 1；目标图与实现截图同尺寸比较
- Thumbnail test: 缩放至 25% 时左侧漏斗仍是唯一英雄，环图和折线明显退后，标题与四结果仍可识别
- Long-label test: “由公开内容进入私信后转企业微信的有效线索”等 20–28 汉字标签不溢出，必要时双行省略并可 hover 查看全文
- Zero, missing, and extreme-value test: 续费平台 0、某周 B站 missing、单平台 95% 极端占比、100,000+ 触达均不破坏布局，unknown 不当作 0
- Reference-comparison passes: 至少一轮宏观构图/氛围对比、一轮微观字体/对齐/圆角/图表细节对比，并保存同屏 comparison 图
- Accessibility checks possible from implementation: 键盘路径、focus-visible、按钮可访问名称、对比度、缩放 125%、prefers-reduced-motion、弹窗 Esc 与焦点回收
