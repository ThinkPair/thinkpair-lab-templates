---
type: asset_qa
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

# Batch 04 QA｜门脸差量与人物动作

## 结论

Batch 04 当前版本已完成内部技术与视觉 QA，可以作为用户目检候选。本结论不等于用户已经通过、不等于网页已经接入，也不等于产品完成、上线锁定或市场验证。

- 经营资产：8 项；其中 6 项本地拼装、2 项分别调用内置 ImageGen。
- 技术派生：1 项透明咖啡门脸底层，不计入 8 项经营资产。
- 当前联系表：`contact-sheets/contact-sheet-batch04-v06.png`。
- 当前范围：只有 NPC、顾客动作、门脸与门脸可见动态；没有新增店内设备。
- 网页变更：无；本批没有修改 `web/src`。

## 当前候选逐项验收

| asset_id | 当前版本 | 人物比例／几何 | 粗像素与轮廓 | 色盘与世界观 | alpha／背景 | 经营状态 | 结论 |
|---|---:|---|---|---|---|---|---|
| PXL-FAC-COFFEE-DOOR-OPEN-PATCH-01 | v01 | 锁定 M1 门洞 | 未增加细节 | 沿用 M1 | 二值 alpha；透明 RGB 清零 | 开门／进店节点可读 | PASS |
| PXL-FAC-COFFEE-WINDOW-DARK-PATCH-01 | v01 | 只覆盖既有玻璃 | 保留窗框轮廓 | 冷灰绿暗化，不做棕黑 | 二值 alpha；透明 RGB 清零 | 熄灯／非营业时段可读 | PASS |
| PXL-FAC-COFFEE-SHUTTER-CLOSED-PATCH-01 | v01 | 锁定 M1 门洞 | 8px 横向卷帘 | 中性灰绿 | 二值 alpha；透明 RGB 清零 | 更准确为入口暂停营业 | PASS_WITH_NOTE |
| PXL-CMP-NEW-OVERLAY-01 | v03 | 正常竞品为唯一几何母版 | 只保留红绸，无门板拼块 | 低饱和砖红 | 二值 alpha；透明 RGB 清零 | 新竞品开业可读 | PASS |
| PXL-CMP-AGED-OVERLAY-01 | v03 | 只改变雨棚与绿植 | 没有规则补丁或微噪声 | 冷灰绿褪色，非棕黄复古 | 二值 alpha；透明 RGB 清零 | 渐进老化较克制，需用户重点看强度 | PASS_WITH_NOTE |
| PXL-CMP-CLOSED-OVERLAY-01 | v02 | 暗窗边界锁在窗框内 | 卷帘保持粗像素 | 中性冷灰 | 二值 alpha；透明 RGB 清零 | 暗窗＋卷帘表达闭店；外墙灯仍亮 | PASS_WITH_NOTE |
| PXL-CUS-WALK-CYCLE-A-01 | v04 | 成人比例；4 帧脚底统一 `y=1312` | 8×8 网格、29 色；无游离像素 | 米白、灰绿、砖红；与 M2 顾客同世界 | 二值 alpha；透明 RGB 清零 | 路过客流循环可读；不解释为首次进店 | PASS |
| PXL-NPC-DIAG-OWNER-POINT-01 | v02 | 成人约 1:5；头部不再偏大 | 8×8 网格、29 色 | 黑发、蓝灰衬衫、卡其裤；同一诊断负责人 | 二值 alpha；透明 RGB 清零 | 指向证据／解释动作可读 | PASS_WITH_NOTE：像不像本人仍待用户确认 |
| PXL-FAC-COFFEE-BASE-ALPHA-01 | v01 | 与 M1 建筑一致 | 不重绘 | 完整继承 M1 | 二值 alpha；透明 RGB 清零 | 技术底层，不单独表达经营状态 | PASS |

## 当前源文件尺寸与哈希

| 文件 | 尺寸 | alpha bbox | SHA-256 |
|---|---:|---|---|
| `source/batch04/pxl-fac-coffee-base-alpha-01-v01.png` | 1536×1024 | `(299,70,1222,953)` | `9934BF9AB7FB0200C22664ACBE31D39AF1F0BD3CADC7A6CF19E1CD41AB161AA0` |
| `source/batch04/pxl-fac-coffee-door-open-patch-01-v01.png` | 1536×1024 | `(695,648,823,911)` | `F065D3350B01B87433836E9CD4A1F3CA19702728C7DD22EEBAAC271ED77A0E36` |
| `source/batch04/pxl-fac-coffee-window-dark-patch-01-v01.png` | 1536×1024 | `(456,617,1075,818)` | `B9898D286D0282DC219A84D808648B7628001F2DC47BFEDE8B51357391E5F849` |
| `source/batch04/pxl-fac-coffee-shutter-closed-patch-01-v01.png` | 1536×1024 | `(691,615,821,909)` | `5341121429EF9F0DC8FB58461042646BDFD08DCAA0EFD9EADE228CDA55BBFE64` |
| `source/batch04/pxl-cmp-new-overlay-01-v03.png` | 1536×1024 | `(659,689,918,780)` | `672345BCE4AC3551EA12E0E1691A0E9BF6B1C5EBC38EB62882A99D45FA673371` |
| `source/batch04/pxl-cmp-aged-overlay-01-v03.png` | 1536×1024 | `(307,408,1215,884)` | `AC213D4A3CB39266824DEFC44111B0C55B08712913C202554BE236393D44D182` |
| `source/batch04/pxl-cmp-closed-overlay-01-v02.png` | 1536×1024 | `(395,505,1122,862)` | `1F67817FEEC309B23DB2AF8C12B5F8C5FA375FE5DF7D4017695CCDFC288F332D` |
| `source/batch04/pxl-cus-walk-cycle-a-01-v04.png` | 4096×1536 | `(248,160,3800,1312)` | `0C9932811E5090E01F9E9E144AF63B1189D0C0AD403F81E12E1ED8F4D8F3DABC` |
| `source/batch04/pxl-npc-diag-owner-point-01-v02.png` | 1024×1536 | `(120,192,728,1304)` | `B14037511D21A028B4A9DA9B22194ACAC20A808DA4D1776F5D4DD578A83D7BCE` |

顾客 4 帧均为 `1024×1536`、二值 alpha、透明 RGB 清零，脚底基线一致：

| 帧 | alpha bbox | SHA-256 |
|---|---|---|
| f01 v04 | `(248,160,768,1312)` | `90070A51E5CF7CA3E548632272628CEF2F8C0EF8F87047F25AB135DB1E6D04B2` |
| f02 v04 | `(264,160,648,1312)` | `7522ABC6CA1E33B05CC801403227F2805B243517E596C1E9478F10CA775D4F04` |
| f03 v04 | `(248,160,768,1312)` | `63FE3C843AE241537BD87441484D8A071EA0EDDE0477F662CB6F2A0D7ADA4845` |
| f04 v04 | `(288,160,728,1312)` | `86F736FC1E80C4DBA0E91EEC111FA7AE7F55507C602762DAFF89212C5AF4C921` |

## 视觉返修记录

1. 初始人物 v01 出现不透明黑底，判定 FAIL；v02 修复 alpha。
2. 顾客 v02 仍有游离像素，v03 修复未改变结果；v04 按最大连通主体清理，判定 PASS。
3. 竞品新开 v01／v02 分别存在替换范围过大和门板暗红块；v03 只保留红绸，判定 PASS。
4. 竞品老化 v01 跨墙面形成矩形褪色，v02 的规则灰条仍像补丁；v03 只做雨棚与绿植整对象褪色，判定 PASS_WITH_NOTE。
5. 竞品闭店 v01 的外墙灯区域出现暗色矩形；v02 移除该处理，只保留窗格暗化和卷帘，判定 PASS_WITH_NOTE。
6. `view_image` 对当前 9 项联系表、3 张竞品全尺寸预览、4 帧顾客和诊断 NPC 完成逐项检查；另由独立只读 Agent 复查，结论一致。

## 使用建议

- 网站优先：门开、暗窗、咖啡卷帘、竞品新开／老化／闭店 6 个全画布差量层；顾客四帧 WebP 精灵表；诊断 NPC WebP。
- 直播／短视频优先：4 张顾客独立 PNG 帧、诊断 NPC 全尺寸 PNG、竞品三态差量层，用于同一门脸前后对照。
- 需要配 HTML／SVG 标记：老化强度、是否确认闭店、具体客流数、店名和经营结论；不要把这些文字烘入位图。

## 用户目检重点

1. 诊断 NPC 的脸型和整体感觉是否像本人；
2. 竞品老化 v03 是否足够可读，还是需要更强但仍清新的状态；
3. 咖啡门洞卷帘是否应只解释为“暂停营业”；
4. 竞品闭店外墙灯保留点亮是否可以接受。

用户目检前，Batch 04 状态保持“内部 QA 通过、待用户目检候选”。
