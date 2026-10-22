---
type: pixel_asset_batch_qa
layer: products
status: review
validity: current
retrieval: on_demand
effective_from: 2026-08-06
updated: 2026-08-06
confidence: confirmed
privacy: private
entity_id: artifact.thinkpair.pixel_library.batch07
claim_key: qa_result
claim_value: three_geometry_matched_facade_state_patches_passed_internal_qa_pending_user_review
schema_version: temporal-governance-v2
---

# Batch 07 QA｜门脸状态差量拼装

## 结论

Batch 07 当前三项通过内部技术与视觉 QA，可提交用户目检：

1. `PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01`：奶茶开门 `v04`；
2. `PXL-FAC-M1-SHUTTER-CLOSED-PATCH-01`：M1 卷帘关闭 `v02`；
3. `PXL-FAC-M2-CLOSED-COVER-PATCH-01`：M2 三口封板关闭 `v02`。

三项均为透明局部 Patch，没有重画整店，ImageGen 调用为 0。全部严格使用 8×8 逻辑网格、低色数、二值 alpha 和透明 RGB 清零；合成后 Patch 之外的母版像素不变。当前主联系表为 `contact-sheets/contact-sheet-batch07-v04.png`。

本批不修改 `web/src`、诊断逻辑、API、页面流程和当前正式资产。内部 QA 通过不等于用户视觉通过、网页接入、产品完成或市场验证。

## 为什么本批不调用 ImageGen

- 三个经营状态都已有同世界母版和明确开口坐标；
- 咖啡门开／卷帘和竞品关闭已有语义参考，但建筑几何不能跨店直接缩放复用；
- 只需对真实门芯、开口和服务口做少量可控像素变化，本地拼装比重新生成整店更稳定；
- 这样能严格落实“像素拼凑优先、不要越做越精细、不同状态不重新设计整家店”。

没有切换 CLI，也没有使用需要 `OPENAI_API_KEY` 的路径。

## 当前版本与母版

| asset_id | 当前版本 | 唯一几何母版 | 母版 SHA-256 | 允许表达的经营事实 |
|---|---|---|---|---|
| PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01 | v04 | source/batch06/pxl-fac-milktea-base-alpha-01-v03.png | `ECE006DAFAC64A2D80149EAD0B34B607233745BFD8817F1902C85AD744B2A5F5` | 入口当前打开／当前可进入／进店节点 |
| PXL-FAC-M1-SHUTTER-CLOSED-PATCH-01 | v02 | source/batch02/pxl-shl-m1-empty-01-v05.png | `BA245EC4771AB6199FD1A523F7D216F5B9905F231C894A2B3B19C2FD447F0BDE` | 入口关闭／当前非营业 |
| PXL-FAC-M2-CLOSED-COVER-PATCH-01 | v02 | source/batch02/pxl-shl-m2-empty-01-v05.png | `740CFD03585A6B52BA6FC202929204E4986BBD4D519E21E7D78BA87379348AA9` | 三个服务口封闭／停止服务 |

## 版本谱系

| 资产 | 版本 | 结果 | 原因 |
|---|---|---|---|
| 奶茶开门 | v01 | FAIL | 覆盖门柱和地台，整体像黑色门亭；不是局部门芯变化 |
| 奶茶开门 | v02 | FAIL | 范围缩小但仍像关闭的深灰绿单门，开门语义不成立 |
| 奶茶开门 | v03 | CONDITIONAL_PASS 后被取代 | 门叶和暗入口已分离，但右下暖棕楔可能像断裂门板或门口障碍 |
| 奶茶开门 | v04 | PASS／当前入口 | 门叶加宽一个逻辑格并删除暖棕楔；不扩大修改范围 |
| M1 卷帘 | v01 | FAIL | 覆盖范围过大，侵入不该变化的母版结构 |
| M1 卷帘 | v02 | PASS／当前入口 | 卷帘只覆盖真实开口，柱、招牌、门楣和门槛保留 |
| M2 封板 | v01 | FAIL | 大面积墙体遮住立柱与岛柜结构，像重画整店 |
| M2 封板 | v02 | PASS／当前入口 | 三块封板只覆盖三个真实服务口，顶棚、立柱、台面和柜体不变 |

所有版本均保留，没有覆盖旧文件。当前调用必须显式使用 S1 v04、M1 v02、M2 v02。

## 技术检查

机器记录：`qa/batch07-metrics-v04.json`。

| asset_id | 尺寸／逻辑尺寸 | 不透明色 | alpha | 透明区 RGB | alpha bbox | 连通组件 | Source SHA-256 | Web SHA-256 | 结论 |
|---|---|---:|---|---|---|---:|---|---|---|
| PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01 v04 | 1536×1024／192×128 | 5 | 仅 0/255 | 清零 | 704,656–824,912 | 1 | `A44C364DB04580FE7E5E6D40909163696ED4F9ED838E9B6CAB64988C1EC30B69` | `064F077B568AA70B366201487748BAD7C8977AF36BCA91CABDE94934CB796EE0` | PASS |
| PXL-FAC-M1-SHUTTER-CLOSED-PATCH-01 v02 | 1112×776／139×97 | 6 | 仅 0/255 | 清零 | 136,336–968,688 | 1 | `37DFBD39DC17B20615548D8B4E18382D8B02DB9824ED76C719A7AF362ABC73DD` | `9BD6A3016B457914E2552F556399ED4024BAAF45A3CBFAD7B2D3CC4F74FF07FB` | PASS |
| PXL-FAC-M2-CLOSED-COVER-PATCH-01 v02 | 1176×688／147×86 | 5 | 仅 0/255 | 清零 | 120,240–1048,408 | 3 | `3A97DCFFCDB00B347DA2F8B035654C17C454863FE4FE7006EAED29F83A006588` | `1B29A8A81D5BACB1D26509A8C6AB90AE221D5FE61B3C596ED822F4A915969751` | PASS |

补充检查：

- 3/3 最近邻缩小到逻辑画布再放大，与源图逐像素一致；
- 3/3 无抗锯齿、半透明边、白边、色幕残留或透明区脏色；
- 3/3 Patch 覆盖区合成无缩放、模糊和错位；
- 3/3 Patch 外母版 `outside_diff = 0`，没有重画整店；
- Video PNG 与 Source PNG 哈希相同；
- 三项复杂度低于母版，没有越做越精细。

## 逐项视觉与经营语义 QA

| asset_id | 视觉检查 | 经营语义 | 结论 |
|---|---|---|---|
| 奶茶开门 v04 | 暖木门叶和右侧连续暗入口清楚；门叶、门把和门洞只在原门框内；门槛连续，无破损／障碍歧义 | 可表达入口已打开和进店可达；不能证明已有顾客进店、客流上升、成交或经营正常 | PASS |
| M1 卷帘 v02 | 卷帘贴合开口；六种颜色全部来自 M1 母版；无锈迹、污渍和复古处理 | 可表达入口关闭或当前非营业；不能证明永久闭店、破产或撤店 | PASS_WITH_NOTE：永久状态须外层证据标签 |
| M2 三口封板 v02 | 三块盖板各自贴合服务口；保留顶棚、立柱、台面和柜体；五种颜色全部来自 M2 母版 | 可表达服务口封闭／停止服务；单看可能是普通实心面板，闭店时段、暂停和永久退出须由外层标签区分 | PASS_WITH_NOTE：需配状态标签 |

## 固定母合同检查

- 清新明亮、非棕黄复古：3/3 通过；
- 粗像素、不过细：3/3 通过，严格 8×8；
- 深棕／深灰轮廓、米白／灰绿／浅木低饱和色盘：3/3 通过；
- 门脸比例、视角和主体结构稳定：3/3 通过；
- 只改变指定经营对象，不重新设计整家店：3/3 通过；
- 无文字、店名、数字、商标、水印和伪文字：3/3 通过；
- 非 Minecraft、非体素 3D、非儿童卡通、非霓虹赛博朋克、非照片马赛克：3/3 通过；
- 不包含咖啡机、健身器材、库存、工位、收银台、货架或座位：3/3 通过。

## 联系表

- 当前用户目检入口：`contact-sheets/contact-sheet-batch07-v04.png`；
- SHA-256：`D384395CC838AF86D97D57342DF49D4ABE9AA6A7F00DE5BF86B460AB833A1F4C`；
- `contact-sheet-batch07-v01.png` 至 `v03.png` 只保留生产与返修谱系，不作为当前目检入口。

## 网站、直播与短视频用途

- 网站：`web/batch07/` 的透明 WebP 可叠加到对应母版，适合即时门开／门关状态切换；本轮没有接入网页；
- 直播：`video/batch07/` 的全尺寸透明 PNG 可在讲解“进店可达、当前非营业、服务停止”时即时显影；
- 9:16 短视频：可把母版与 Patch 放在画面中下部做前后切换，并在外层使用可控文字或 SVG 标明“已确认／可能／待核实”；
- S1 门开可和现有进店顾客、路线层组合，但门开本身不等于顾客已进店；
- M1／M2 关闭态须由 HTML／SVG 标签区分营业时段结束、临时暂停和永久闭店，不能让位图替代证据等级。

## 下一批建议与停止线

Batch 07 到此停止扩批，等待用户目检。下一批最值得做的不是新整店或内部设备，而是先根据 Batch 04–07 的用户反馈选择一个最小缺口：

1. 若门开语义通过，优先把现有顾客进店动作、门开 Patch 和路线层组合成可复用镜头模板；
2. 若人物仍显得单一，再补一个门前驻足／回头的成人 NPC 动作，而不是重画店；
3. 只有现有 S1/M1/M2/L1/R1 和网页五类行业门脸覆盖不了真实镜头时，才新增一个门脸轮廓。

本批不继续生产咖啡机、健身器材、库存、工位、座位或其他店内对象。

## 状态边界

本批证明的是：三个门脸状态 Patch 的源文件、网页／视频副本、联系表、哈希和 QA 已完整保存在当前“总”知识库，并形成可提交用户目检的候选。它不证明用户已经接受视觉，不证明候选已经接入网页，也不证明产品完成、真实经营者采用、收费或市场验证。
