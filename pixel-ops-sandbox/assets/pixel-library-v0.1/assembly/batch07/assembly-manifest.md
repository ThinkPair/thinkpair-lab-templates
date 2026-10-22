---
type: asset_assembly_manifest
layer: products
status: review
validity: current
retrieval: on_demand
effective_from: 2026-08-06
updated: 2026-08-06
confidence: confirmed
privacy: private
schema_version: temporal-governance-v2
---

# Batch 07 拼装清单｜门脸状态差量

## 生产边界

本批只生产门脸外部可见状态，不扩新行业或新店型，不重画整店，也不生成店内设备。三项均为本地像素拼装，ImageGen 调用 0 次；没有切换 CLI/API 路径，没有修改 `web/src`、诊断逻辑、API、页面流程或当前正式资产。

## 当前拼装版本

三项 Patch 都保持与各自母版相同的全画布尺寸和 `(0,0)` 锚点，合成时直接叠加，不得裁边后猜测偏移。

| asset_id | 当前版本 | 唯一几何母版 | 逻辑差量范围 | alpha bbox | 图层顺序 | 经营事实 |
|---|---|---|---|---|---|---|
| PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01 | v04 | source/batch06/pxl-fac-milktea-base-alpha-01-v03.png | 门芯 `[88,82,103,114)`／192×128 | `(704,656,824,912)` | 奶茶母版之上、人物与路线之下 | 入口打开／当前可进入；不证明顾客已进店 |
| PXL-FAC-M1-SHUTTER-CLOSED-PATCH-01 | v02 | source/batch02/pxl-shl-m1-empty-01-v05.png | 开口 `[17,42,121,86)`／139×97 | `(136,336,968,688)` | M1 母版之上、状态标签之下 | 入口关闭／当前非营业；不证明永久闭店 |
| PXL-FAC-M2-CLOSED-COVER-PATCH-01 | v02 | source/batch02/pxl-shl-m2-empty-01-v05.png | 三口 `[15,30,56,51)`、`[62,30,79,51)`、`[84,30,131,51)`／147×86 | `(120,240,1048,408)` | M2 母版之上、状态标签之下 | 服务口封闭／停止服务；不区分暂停与永久退出 |

## 版本谱系

- 奶茶 v01：覆盖范围过大，像黑色门亭；视觉失败；
- 奶茶 v02：像关闭单门，开门语义不成立；视觉失败；
- 奶茶 v03：门叶／暗入口成立，但右下暖棕楔可能像门口障碍；由 v04 取代；
- 奶茶 v04：门叶加宽一个逻辑格并删除暖棕楔，bbox 不变；当前入口；
- M1 v01：覆盖开口之外的母版结构；视觉失败；M1 v02 为当前入口；
- M2 v01：大墙面遮住立柱与岛柜结构；视觉失败；M2 v02 为当前入口。

旧版本全部保留，不得覆盖，也不得与当前候选混用。

## 合成顺序

```text
环境底板
  → 对应唯一几何门脸母版
  → Batch 07 状态 Patch
  → 顾客／NPC／门前客流
  → SVG 路线、箭头、经营半径与证据等级
  → HTML/CSS 数值、店名、报告文字和状态标签
```

M1 和 M2 的关闭图层必须配合可控状态标签；位图自身不能区分营业时段结束、临时暂停、永久闭店、破产或撤店。奶茶门开如需表达“实际进店”，必须继续叠加顾客动作或路线。

## 输出用途

- 网站：`web/batch07/` 为透明无损 WebP；只表示可供接入，不表示已经接入；
- 直播／9:16：`video/batch07/` 为全尺寸透明 PNG；
- 合成预览：`assembly/batch07/preview-*.png`；
- 当前统一目检入口：`contact-sheets/contact-sheet-batch07-v04.png`；
- 完整技术与视觉结论：`qa/batch07-qa.md`。
