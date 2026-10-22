---
type: asset_assembly_manifest
layer: products
status: review
validity: current
retrieval: on_demand
effective_from: 2026-08-05
updated: 2026-08-05
confidence: confirmed
privacy: private
schema_version: temporal-governance-v2
---

# Batch 04 拼装清单｜门脸差量与人物动作

## 生产边界

本批只生产 NPC、顾客动作、门脸和门脸外部可见动态。没有新增咖啡机、健身器材、库存、座位、收银台或其他店内对象，也没有修改 `web/src`、诊断逻辑、API、页面流程或既有正式资产。

8 项经营资产中，6 项为本地像素拼装，2 项调用内置 ImageGen 生成缺失人物动作后再压回粗像素网格。另有 1 项不计入经营资产数量的透明门脸技术底层。

## 几何母版

| 对象 | 唯一几何母版 | 允许参考 | 禁止做法 |
|---|---|---|---|
| 咖啡门脸 | `资产证明集/M1-01-咖啡店基础立面-v1.png` | `M2-部件-门开状态-v1.png` 只参考门开 | 不从两张整景直接求全图差分；不重画整店 |
| 竞品门脸 | `source/batch01/pxl-cmp-normal-01-v01.png` | 新开／闭店完整图只作状态参考 | 不把三张几何略有漂移的整店互相溶解 |
| 顾客 A | `资产证明集/M2-顾客A-女青年-走路-v1.png` | 现有进店动作只参考步态 | 不增加手机、杯子、服装或面部细节 |
| 诊断负责人 | `source/batch03/pxl-npc-diag-owner-01-v04.png` | 用户脸型参考只约束黑发、脸型和成人感 | 不改身份、服装、剪贴板或头身比 |

## 当前拼装版本

所有门脸 Patch／Overlay 均为 `1536×1024 RGBA` 全画布，锚点统一为 `(0,0)`；合成时直接叠在对应几何母版上，不需要猜测裁边偏移。

| asset_id | 当前版本 | 母版／来源 | 差量范围 | 图层顺序 | 经营事实 |
|---|---|---|---|---|---|
| PXL-FAC-COFFEE-BASE-ALPHA-01 | v01 | M1 咖啡基础立面 | 建筑主体 alpha bbox `(299,70,1222,953)` | 背景之上、状态层之下 | 技术拼装底层，不单独表达经营结论 |
| PXL-FAC-COFFEE-DOOR-OPEN-PATCH-01 | v01 | M1＋M2 门开参考 | alpha bbox `(695,648,823,911)` | M1 之上 | 营业中／顾客进入节点 |
| PXL-FAC-COFFEE-WINDOW-DARK-PATCH-01 | v01 | M1 | alpha bbox `(456,617,1075,818)` | M1 之上 | 窗灯关闭／非营业时段 |
| PXL-FAC-COFFEE-SHUTTER-CLOSED-PATCH-01 | v01 | M1 门洞 | alpha bbox `(691,615,821,909)` | M1 之上 | 门口暂停营业；不是整店破产结论 |
| PXL-CMP-NEW-OVERLAY-01 | v03 | 正常竞品＋新开参考 | alpha bbox `(659,689,918,780)` | 正常竞品之上 | 新竞品开业并开始分流 |
| PXL-CMP-AGED-OVERLAY-01 | v03 | 正常竞品 | alpha bbox `(307,408,1215,884)` | 正常竞品之上 | 仍营业但雨棚与绿植逐步老化 |
| PXL-CMP-CLOSED-OVERLAY-01 | v02 | 正常竞品 | alpha bbox `(395,505,1122,862)` | 正常竞品之上 | 暗窗＋卷帘表达竞品退出／闭店 |
| PXL-CUS-WALK-CYCLE-A-01 | v04 | M2 顾客 A＋ImageGen 动作源 | 4 帧，每帧 `1024×1536`，脚底统一 `y=1312` | 门脸前景人物层 | 路过客流的连续步行动作 |
| PXL-NPC-DIAG-OWNER-POINT-01 | v02 | 诊断负责人 v04＋ImageGen 动作源 | `1024×1536`，bbox `(120,192,728,1304)` | 门脸旁／报告解释层 | 指向门口、客流或竞品证据 |

## 版本谱系

- `PXL-CMP-NEW-OVERLAY-01`：v01 带亮窗和较大替换范围；v02 仍混入门板暗红块；v03 只保留开业红绸与紧邻轮廓，为当前候选。
- `PXL-CMP-AGED-OVERLAY-01`：v01 有跨墙面矩形褪色；v02 移除墙面块但规则灰条仍像补丁；v03 只保留雨棚与绿植整对象褪色，为当前候选。
- `PXL-CMP-CLOSED-OVERLAY-01`：v01 外墙灯区域出现矩形暗块；v02 只压暗窗格并保留门洞卷帘，为当前候选。
- `PXL-CUS-WALK-CYCLE-A-01`：v01 抠图 alpha 错误；v02 修复透明背景但有游离像素；v03 修复未改变哈希；v04 按逐帧最大连通主体清理，为当前候选。
- `PXL-NPC-DIAG-OWNER-POINT-01`：v01 抠图 alpha 错误；v02 修复透明背景并保持黑发、专业服装、剪贴板与成人比例，为当前候选。

旧版本全部保留用于溯源，不得覆盖，也不得与当前候选混用。

## 输出用途

- 网站：`web/batch04/` 使用透明无损 WebP；门脸差量保持全画布，顾客循环为 `2048×768` 横向精灵表，诊断 NPC 为 `512×768`。
- 直播／9:16：`video/batch04/` 保留透明 PNG；顾客循环同时提供 4 张 `1024×1536` 独立帧，便于逐帧播放或剪辑。
- QA：`assembly/batch04/preview-*.png` 是叠回母版后的全尺寸预览；`contact-sheets/contact-sheet-batch04-v06.png` 是当前统一目检入口。

所有数值、店名、经营半径、路线、箭头、已确认／可能／待核实标记和报告文字仍应由 SVG、CSS 或 HTML 提供，不烘入位图。
