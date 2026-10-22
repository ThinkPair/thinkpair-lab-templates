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

# Batch 03 拼装清单｜经营状态链

> 当前范围覆盖：花材库存、美容工位和健身有氧状态均属店内对象，已退出当前产品。本页只保留历史拼装来源，不再作为网站、直播或短视频调用清单。

## 原则

Batch 03 不重画完整店铺。每条状态链先锁定一个正常经营母版，只替换花材数量、工位占用数量或设备使用人数。精确数字、状态名称、箭头和警报标记留给 HTML/SVG/CSS。

所有输出都仍是透明模块，不是网页接入文件。网页和视频目录中的副本只表示适合调用。

## 状态链来源

| 状态链 | 锁定母版 | 母版 SHA-256 | 本批新增状态 | 生产方式 |
|---|---|---|---|---|
| 花材库存 | `source/batch02/pxl-kit-flower-display-01-v05.png` | `593362589A7B212DE5906B4238725B741FF84B2D7FBBA55890D4777C3F3DF385` | 库存少、积压 | 在同一工作台和花桶几何上本地删减／复制花材 |
| 美容工位 | `source/batch02/pxl-kit-beauty-station-01-v05.png`；`source/batch02/pxl-sta-beauty-station-used-01-v05.png` | 空闲 `BD1399842C6F3992C37D1CBB7CA28E79ABCEFA10A46420BC41F13BBA3AAB60FA`；使用 `89EA8B8EF3B4795E964233484A167AFA55979D627C8A9604FC68DFC13B07D8EC` | 3/3 满载、等待压力 | 满载由同一使用态等距重复；等待人物单独生成，合成时置于 R1 等待区 |
| 健身有氧 | `source/batch02/pxl-kit-gym-cardio-01-v05.png`；`source/batch02/pxl-sta-gym-cardio-used-01-v05.png` | 空闲 `C8594386B8E03D304E8798916A34C8462D43AC82FAA670C2A4DB9EF2A406128B`；1/3 `82BB8A153A37A5B0C108DEB5B42A96F7AC9D6FF06FE865A259B70BEB4971C067` | 2/3、3/3 | 只生成缺失人物来源，再将人物拼回精确的 v05 跑步机底层 |

## 选定输出

| asset_id | 选定文件 | SHA-256 | 复用规则 |
|---|---|---|---|
| PXL-STA-FLOWER-STOCK-LOW-01 | `source/batch03/pxl-sta-flower-stock-low-01-v01.png` | `9F42FE06D1F0A4483F0E734D1AE697C55D1160A2C6C44EC3243E8095489B5E79` | 与正常态同位置同尺寸；应用层叠加“库存少”标签 |
| PXL-STA-FLOWER-STOCK-BACKLOG-01 | `source/batch03/pxl-sta-flower-stock-backlog-01-v01.png` | `C916D814A978B725D8BF413125C70CB86C1281BE2A600B37A184F6D088D9EE5D` | 与正常态同位置同尺寸；应用层叠加“积压”标签，避免被误读为旧花 |
| PXL-STA-BEAUTY-STATION-FULL-01 | `source/batch03/pxl-sta-beauty-station-full-01-v02.png` | `7DBFD47AFCEDF7B5DEE309A7A288E63A56DA702936BC84ABA7E745F086487E2E` | 使用 v02；不得误选较松散的 v01 |
| PXL-STA-BEAUTY-WAITING-01 | `source/batch03/pxl-sta-beauty-waiting-01-v01.png` | `462622F8F25928C5FF7BD49FF3C8C83CE931784FE5EB40B4B2EB53193299C881` | 作为通用预约等待人物组；必须与 R1 美容场景或明确行业上下文合成 |
| PXL-STA-GYM-CARDIO-TWO-USED-01 | `source/batch03/pxl-sta-gym-cardio-two-used-01-v01.png` | `83C83C7A6E8B9C9ECCE6D651E5053D71C2AAAD5E8502855B0F491907D429C4D9` | 替换 1/3 状态层；保持三台机器整体位置一致 |
| PXL-STA-GYM-CARDIO-FULL-01 | `source/batch03/pxl-sta-gym-cardio-full-01-v01.png` | `104E78E659268D33B2D50EFA4B2F5F4F007C73C2C0DC481083F0F2C7BDE5F627` | 替换 2/3 状态层；等待人物另叠加，不烘焙进本资产 |

## 推荐层级

### 花材库存

1. L0：S1 或 M2 店型母壳；
2. L1：库存少／正常／积压三选一；
3. L2：花艺师包花、顾客与客流；
4. L3：HTML/SVG 库存数字、损耗率、确认状态。

### 美容预约

1. L0：R1 预约工作室母壳；
2. L1：空闲、单工位使用或 3/3 满载三选一；
3. L2：等待人物组；
4. L3：HTML/SVG 预约数、等候时间、已确认／待核实标签。

### 健身有氧

1. L0：L1 或 M1 场地母壳；
2. L1：0/3、1/3、2/3、3/3 四选一；
3. L2：入口、力量器械与额外等待人物；
4. L3：HTML/SVG 利用率、峰值时段和状态标记。

## 诊断负责人边界

`PXL-NPC-DIAG-OWNER-01 v04` 是重点诊断主角色，不属于上述状态链，也不作为普通顾客或店员的像素密度母版。合成时与普通 NPC 统一脚底基线和显示高度；对话框、结论标记和报告文字全部由 HTML/SVG 生成。

## 验收状态

6 个经营状态已通过内部技术 QA，仍待用户视觉目检。未修改网页源码，未开始下一批。
