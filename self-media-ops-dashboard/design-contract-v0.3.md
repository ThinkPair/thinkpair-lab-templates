---
type: design_contract
layer: output
status: archived
validity: invalidated
retrieval: on_demand
effective_from: 2026-07-30
effective_to: 2026-07-30
privacy: private
invalidation_reason: 与用户已明确保留“漏斗＋饼状图＋线型图”的方向冲突，且把本轮选中的视觉目标误标成负面参考；不得覆盖design-contract.md
relative_time_scope: anchored_to_record
---

# 高级经营看板设计契约 v0.3

> [!warning] 已失效
> 本稿与用户已明确的“漏斗＋饼状图＋线型图”方向冲突，也不是本轮实现依据。当前合同以[[design-contract]]为准。

## Design target

- Product: 降噪实验室本地经营助手
- Screen: 经营总览首页视觉方向稿
- Surface and viewport: 桌面端 1440×1024，首屏完整展示，不为移动端缩放稿
- Intended user: 不熟悉数据分析、但需要快速看清内容经营结果的个体创业者
- 30-second outcome: 30 秒内看清近 8 周有没有形成有效线索和现金结果、哪一个平台贡献最大、经营势能正在增强还是减弱
- Primary action: 补数据
- Supporting actions: 切换时间范围、查看单个平台、进入内容或收入明细

## Visual anchors

- Primary style anchor: `10_Sources/原始材料/小红书账号119729270图片提取-2026-07-30/图片/001_看板设计灵感｜18组配色与排版｜Dashboard_680b7e7f/011.webp`
- Primary anchor role: 强参照其成熟 creator-business 产品骨架——左侧主经营对象、右侧平台对象、柔和分区色、克制荧光点睛和非卡片墙式编排
- Secondary anchor 1: `10_Sources/原始材料/小红书账号119729270图片提取-2026-07-30/图片/018_设计灵感｜5组数据分析看板DASHBOARD_6920401d/004.webp`
- Secondary anchor 1 role: 只借其大尺度主趋势图、直接标注、稀疏网格和数字主次，不借其紫色方案
- Secondary anchor 2: 不使用
- Secondary anchor 2 role: 不使用，避免平均化多个参考
- Negative reference: `30_输出/作品/自媒体运营看板_Web原型-2026-07-30/reference/self-media-dashboard-visual-target-2026-07-30.png`
- Rejected traits: 漏斗占据首页、紫粉渐变、平均大小的白卡片、圆环图充当视觉英雄、所有指标同等重要、AI替用户下结论、报表感和模板感

## Information hierarchy

- Visual hero: 占页面约 55% 的“近 8 周经营结果”组合趋势图，柱形表示实收，单线表示有效线索
- First eye-line: 有效线索、首次付费、实收、升级续费四个结果数字；数字靠排版分组，不拆成四张等权卡
- Second eye-line: 主趋势图、最新值直标和酸性青柠当前期游标
- Third eye-line: 抖音、小红书、B站三个平台经营面板，显示发布、触达、有效线索、实收和迷你趋势
- Deliberately de-emphasized: 发布量、播放量、点赞量、粉丝量等过程数据
- Off-screen or later routes: 详细转化链、内容明细、线索明细、收入流水、AI问数与经营建议

## Visual tokens

- Grid and margins: 12 列网格，左右 32px，列间 20px；左主区 7 列，右平台区 5 列
- Spacing scale: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64px
- Chinese type family and weights: MiSans、HarmonyOS Sans SC、PingFang SC、Microsoft YaHei；正文 400，标签 500，标题 600
- Numeric type family and weights: Satoshi、Outfit、Segoe UI；指标 500，关键结果 600
- Type scale: 12 / 14 / 16 / 20 / 28 / 44 / 64px
- Canvas color: 冷调雾白 `#F2F4EF`
- Surface colors: 主图雾蓝 `#DDE7EB`、平台浅鼠尾草 `#DCE7DF`、结果暖石色 `#E6E4D7`、基础白 `#F8F9F6`
- Primary accent: 酸性青柠 `#DFFF42`，只用于当前期、选择态和关键数据
- Data category colors: 深靛蓝 `#5662A8`、砖珊瑚 `#DF7F7C`、灰青 `#5A9991`
- State colors: 确认 `#2F7D65`、估算 `#C58B28`、缺失 `#B8BDB6`、冲突 `#C85555`
- Radius: 英雄区 20px，辅助区 16px，胶囊控件 999px
- Border: 1px `rgba(23,26,24,.10)`，只用于控件和必要分隔
- Shadow, blur, and texture: 不使用玻璃和发光；仅用极轻 0 10px 30px `rgba(23,26,24,.06)` 建立表面层级
- Icon family and stroke: Lucide，1.75px 圆角描边
- Memorable brand move: 一条酸性青柠“本期游标”贯穿标题进度与主图当前周，形成可追踪的经营时间脊柱

## Chart system

- Hero chart and purpose: 每周实收柱形 + 有效线索单线的双轴组合图，用于判断经营结果是否同步增强；轴标题明确写“实收 ¥ / 有效线索 人”
- Supporting chart 1 and purpose: 三个平台各自 8 周迷你折线，比较贡献节奏，不显示坐标轴
- Supporting chart 2 and purpose: 底部窄型经营链路“内容发布 → 触达 → 有效线索 → 付费 → 续费”，仅作结果关系导航，不宣称跨平台严格同 cohort 转化率
- Stroke and marker language: 主线 3px，平台迷你线 2px；默认不显示点，仅在最新值和事件处出现实心点
- Grid and axis language: 仅 4 条低对比水平网格；无图表外框；月份与周区间采用短标签
- Label and annotation language: 最新值直接标在线尾；首页不叠加经营事件，避免事件日期与周区间发生误读，事件留在单周明细
- Hover and selection: 悬停一周时显示实收、线索、当周动作和数据状态；点击平台面板过滤主图
- Empty and missing states: 缺失周保留空位和虚线连接，明确写“未补录”，不插值伪装完整数据

## Data semantics

- Event units: 内容发布、触达、播放为事件次数，触达不等同于独立用户
- Person units: 有效线索按可识别联系人计数，同一平台内去重
- Order units: 首次付费与升级续费按已确认支付订单计数
- Revenue units: 实收为已到账人民币金额，不含未支付意向金额
- Conversion denominators: 平台内转化率使用该平台已去重有效线索为分母；跨平台链路默认只展示数量关系，不展示伪精确转化率
- Cross-source deduplication rule: 手机号或微信号一致视为同一人；无法跨平台识别时标为“未跨平台去重”
- Evidence states: 已确认、估算、待核、缺失、冲突五种状态，重要结果默认只汇总已确认值
- Demo-data label: 顶栏固定展示“演示数据”，不与真实经营记录混淆

## Interaction

- Default time range: 近 8 周
- Filters: 全部平台、抖音、小红书、B站；近 4 周、近 8 周、近 12 周
- Primary interaction flow: 先看结果数字，再沿主图定位变化周，点击平台面板或事件进入对应明细
- Drill-down target: 单周经营记录、单个平台内容与线索、收入流水
- Keyboard and focus expectations: 所有筛选和跳转可键盘聚焦，焦点环使用 2px 青柠外框并保留 3px 间距
- Responsive fallback: 低于 1100px 时平台区移到主图下方；低于 760px 时改为结果数字、主图、平台横向卡片的单列阅读

## Working UI versus sales image

- Working UI priorities: 真实可读、单位明确、状态可追溯、长标签不截断、缺失值不伪装
- Sales image priorities: 首屏层级、综合色块比例、主趋势图势能、品牌时间游标和三平台辨识度
- Elements allowed only in sales image: 极轻背景颗粒和装饰性标题标记；正式界面不使用与数据无关的光晕

## Implementation

- Existing runtime or template: 当前 Vite + React 原型，只在视觉方向确认后改动
- Chart implementation: Recharts 自定义组合图和迷你线图；经营链路使用语义化 HTML/CSS
- Token implementation: CSS variables 集中定义颜色、圆角、间距、字体和状态
- Fonts and asset sources: 本地系统中文字体栈，Lucide 图标，不使用未经授权的品牌插画
- Realistic data source: 现有降噪实验室演示经营数据；所有演示值在界面中明确标识

## QA acceptance

- Primary reference viewport: 1440×1024
- Thumbnail test: 缩放到 20% 时仍能辨认结果数字、一个主趋势图、三个平台区和青柠时间游标
- Long-label test: “升级续费订单”“未跨平台去重”等 8 至 10 字标签不换行破版
- Zero, missing, and extreme-value test: 0 收入、连续两周缺失、单周收入十倍峰值均不破坏图表比例和标签
- Reference-comparison passes: 至少完成 1440 宽和 1280 宽两轮截图，对照主参照检查综合色块比例、留白、字号、英雄区和平台区权重
- Accessibility checks possible from implementation: 文本与背景对比度、键盘焦点、颜色之外的状态标识、图表 aria-label 和减少动态效果偏好
