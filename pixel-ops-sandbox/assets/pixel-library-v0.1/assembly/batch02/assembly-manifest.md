---
type: pixel_asset_assembly_manifest
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

# Batch 02 像素拼装清单

> 当前范围覆盖：这些拼装场景因包含店内设备，不进入当前门脸产品；本页只保留复用和版本谱系。需要时只能拆取门脸壳、NPC 或构图证据。

## 拼装口径

- 所有样景先在 `192×128` 逻辑画布上拼装，再以最近邻放大 8 倍为 `1536×1024`。
- ImageGen 过细源稿只保留为 `v01`；`v02` 是 4×4 网格中间校准稿；`v03` 完成 8×8 逻辑像素技术校准。用户随后要求从棕黄复古纠偏到清新明亮，当前原子资产目检版本为 14 个 `v05` 和 S1 的 alpha 保真 `v06`，当前样景为 `scenes/*-v03`。
- `PXL-SHL-S1-NEUTRAL-01` 由已通过的 Batch 01 竞品正立面局部清空橱窗得到，没有重新生成建筑。
- 环境墙面、地面、地砖线和遮罩为本地精确绘制；店名、数值、标签、路线和诊断文字均未烘焙进场景位图。
- 本清单只证明素材可拼装，不代表网页已经接入，也不代表视觉已获用户最终确认。

## 同壳复用证据

| 复用组 | 共同母壳 | SHA-256 | 使用样景 |
|---|---|---|---|
| S1 临街组 | `source/batch02/pxl-shl-s1-neutral-01-v06.png` | `DBFACAC37BDF24FE541D3EC417C057EAF0D49C769D4B5056E506BE4F3BE2C134` | 临街奶茶、临街花店 |
| M1 商场沿边组 | `source/batch02/pxl-shl-m1-empty-01-v05.png` | `BA245EC4771AB6199FD1A523F7D216F5B9905F231C894A2B3B19C2FD447F0BDE` | 商场咖啡、商场健身房 |
| M2 商场岛柜组 | `source/batch02/pxl-shl-m2-empty-01-v05.png` | `740CFD03585A6B52BA6FC202929204E4986BBD4D519E21E7D78BA87379348AA9` | 岛柜奶茶、岛柜花店 |

上述三组不是“画得相似”，而是拼装时读取同一母壳文件。行业变化只来自 L2 行业套件和 L4 人物／使用状态。

## 八张样景的层级

| scene_id | L0 环境 | L1 母壳 | L2 行业套件 | L3/L4 状态与人物 | 选定源文件 | 拼装 QA |
|---|---|---|---|---|---|---|
| SCN-S1-MILKTEA-NORMAL-01 | 临街中性墙面与人行道 | S1 中性壳 | 奶茶服务工作站 | 两名通行／驻足成年人 | `source/batch02/scenes/scn-s1-milktea-normal-v03.png` | 业务拼装通过；母壳几何待目检 |
| SCN-M1-COFFEE-NORMAL-01 | 商场走廊 | M1 沿边空壳 | 咖啡服务工作站 | 店员正常交付动作 | `source/batch02/scenes/scn-m1-coffee-normal-v03.png` | 业务拼装通过；母壳几何待目检 |
| SCN-M2-MILKTEA-NORMAL-01 | 商场走廊 | M2 岛柜空壳 | 奶茶服务工作站 | 店员＋两名外部顾客 | `source/batch02/scenes/scn-m2-milktea-normal-v03.png` | 业务拼装通过；顶棚几何待目检 |
| SCN-S1-FLOWER-NORMAL-01 | 临街中性墙面与人行道 | 与奶茶样景完全相同的 S1 壳 | 花店陈列包装站 | 花艺师包花＋一名路人 | `source/batch02/scenes/scn-s1-flower-normal-v03.png` | 业务拼装通过；母壳几何待目检 |
| SCN-M2-FLOWER-NORMAL-01 | 商场走廊 | 与奶茶岛柜完全相同的 M2 壳 | 花店陈列包装站 | 花艺师包花＋一名顾客 | `source/batch02/scenes/scn-m2-flower-normal-v03.png` | 业务拼装通过；顶棚几何待目检 |
| SCN-L1-GYM-NORMAL-01 | 大型场馆公共通道 | L1 大型场馆空壳 | 力量器械 | 中间跑步机使用态 | `source/batch02/scenes/scn-l1-gym-normal-v03.png` | 条件通过：玻璃后的器械识别度仍待目检 |
| SCN-M1-GYM-NORMAL-01 | 商场走廊 | 与咖啡样景完全相同的 M1 壳 | 健身入口、力量器械 | 中间跑步机使用态 | `source/batch02/scenes/scn-m1-gym-normal-v03.png` | 业务拼装通过；母壳几何待目检 |
| SCN-R1-BEAUTY-NORMAL-01 | 预约工作室公共通道 | R1 三工位空壳 | 美容工位 | 一名顾客＋一名服务人员的使用态 | `source/batch02/scenes/scn-r1-beauty-normal-v03.png` | 业务拼装通过；框体样式待目检 |

## 固定层序

1. L0 环境底色、墙面、地面与地砖线；
2. L1A 母壳后层或空室；
3. L2 行业设备；
4. L3 使用状态；
5. L4A 店内人物；
6. L1B 柜台、玻璃框、立柱等前遮挡；
7. L4B 公共区域顾客；
8. L5 网站侧 SVG／CSS／HTML 信息层，本轮未写入位图也未接入网页。

## 版本边界

- `v01`：ImageGen 生成源稿，因像素密度过细被用户指出后降级，不进入正式拼装。
- `v02`：4×4 网格／48 色的中间校准稿，不作为当前目检候选。
- `v03`：8×8 逻辑网格／最多 32 个主体色阶，保留为粗像素技术基线；旧棕黄版本不再作为当前视觉候选。
- `v05`：14 个原子资产的清新明亮调色候选；不改变画布、几何和像素密度。
- `v06`：S1 的 alpha 保真清新调色候选。
- 场景 `v03`：使用上述清新资产重新拼装的当前样景；仍待用户目检，不代表网页接入。
