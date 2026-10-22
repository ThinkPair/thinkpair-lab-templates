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
entity_id: artifact.thinkpair.pixel_library.batch06
claim_key: qa_result
claim_value: four_current_web_facades_archived_with_current_candidates_passed_internal_qa_pending_user_review
schema_version: temporal-governance-v2
---

# Batch 06 QA｜网页现用行业门脸归库与粗像素统一

## 结论

Batch 06 已把当前网页使用、但此前没有集中登记的 4 个行业门脸归入素材库：

1. `PXL-FAC-MILKTEA-BASE-ALPHA-01`：当前候选 `v03`；
2. `PXL-FAC-FLOWER-BASE-ALPHA-01`：当前候选 `v07`；
3. `PXL-FAC-GYM-BASE-ALPHA-01`：当前候选 `v03`；
4. `PXL-FAC-BEAUTY-BASE-ALPHA-01`：当前候选 `v03`。

四项已经达到可提交用户目检的内部 QA 门：正立面、8×8 粗像素、清新低饱和、透明边缘和经营语义均成立。健身与花店内部视觉 QA 为 `PASS`；奶茶与美业为 `CONDITIONAL_PASS`，原因是两张双层临街骨架的差异度仍需用户判断，美业侧灯箱在小尺寸下也要防止产生伪文字联想。

当前网页仍读取原 `v01`。本批没有修改 `web/src`、诊断逻辑、API 或页面流程；内部 QA 不等于用户验收、视觉锁定、网页接入、产品完成或市场验证。

## 素材是否都在知识库

是。交付链所需文件都保存在当前“总”知识库的 `pixel-library-v0.1` 中：

- 网页现用 `v01` 原文件逐字节归档：`source/batch06/raw/*-v01.png`；
- 唯一一次 ImageGen 原始洋红底结果：`source/batch06/raw/pxl-fac-flower-base-alpha-01-v06-imagegen-chroma.png`；
- 当前源图：奶茶／健身／美业 `source/batch06/*-v03.png`，花店 `source/batch06/*-v07.png`；
- 网页副本：`web/batch06/`；
- 直播／9:16 副本：`video/batch06/`；
- 联系表、提示词、机器指标和本 QA 也都在素材库内。

Codex 生成缓存中仍可能存在同内容冗余文件，但正式交付、追溯和复用不依赖 Temp 或 `CODEX_HOME`。

## 盘点与生产判断

- 当前实际网页项目为 `30_输出/作品/ThinkPair_Web_Codex_独立重跑-2026-08-05/web/`；旧 `像素经营沙盘_Web原型-2026-08-05/web/` 为空目录，不作为页面事实源；
- 当前源码已经引用咖啡、奶茶、花店、健身和美业五张 `storefronts-v4` 静态门脸；
- 咖啡门脸与 Batch 04 已归库透明母版哈希一致，因此没有重复处理；
- 当前“客户为什么越来越少”链的人物、客流、竞品和咖啡门脸动态已有候选，真正缺口不是再生成店内物件或一批新整店；
- 所以本批以归档和像素拼装为主，只在花店首轮候选明确失败后定向调用一次内置 ImageGen。

## 版本谱系

| 版本 | 作用 | 当前地位 |
|---|---|---|
| v01 | 当前网页正在使用的原始完整门脸 | 原样归档；保留网页事实，不代表符合当前粗像素母合同 |
| v02 | 四张门脸首次本地粗化 | 8×8 技术成立，但暗面和棕红偏重，只保留生产谱系 |
| v03 | 四张门脸清新粗像素候选 | 奶茶、健身、美业继续作为当前候选；花店因过密、偏复古被独立视觉 QA 判为 `FAIL` |
| 花店 v04／v05 | 对 v03 做纯本地减法 | 过度扁平、丢失建筑层次，不作为当前入口 |
| 花店 v06 | 单次内置 ImageGen 结果经本地去背景、降色、8×8 校准 | 结构与清新度已恢复；内部深黑线仍偏重，只保留中间谱系 |
| 花店 v07 | 在 v06 上仅软化内部黑线、降低金黄饱和和清理雨棚零星紫色 | 当前花店候选；不改建筑、不增细节，内部视觉 QA `PASS` |

所有版本均保留，未覆盖网页原文件。Batch 06 实际调用内置 ImageGen 1 次；没有切换 CLI、没有使用需要 `OPENAI_API_KEY` 的路径。

## 技术检查

当前候选共用 `192×128` 逻辑画布并以最近邻放大；主源尺寸为 1536×1024，网页副本为 768×512。逐张缩小再最近邻放大与原文件逐像素一致，8×8 全局块一致率为 100%。

| asset_id | 当前版本 | Source SHA-256 | 主体色＋透明 | alpha | 透明区 RGB | alpha bbox | 技术结论 |
|---|---|---|---:|---|---|---|---|
| PXL-FAC-MILKTEA-BASE-ALPHA-01 | v03 | `ECE006DAFAC64A2D80149EAD0B34B607233745BFD8817F1902C85AD744B2A5F5` | 28＋1 | 仅 0/255 | 清零 | 304,72–1240,952 | PASS |
| PXL-FAC-FLOWER-BASE-ALPHA-01 | v07 | `C44D0A717DC7C1478A81A619965F723014309A0BC62121F373D2EEF0524F999C` | 29＋1 | 仅 0/255 | 清零 | 320,40–1208,984 | PASS |
| PXL-FAC-GYM-BASE-ALPHA-01 | v03 | `16C738E2722DDB392428542BADEF7E95728341C3B19579E621E2FB2FD6F7E5D7` | 28＋1 | 仅 0/255 | 清零 | 296,160–1240,848 | PASS |
| PXL-FAC-BEAUTY-BASE-ALPHA-01 | v03 | `3EB3031B1BE4F44AD8DAC2B023E027711D523D92F5A1FEC1E8B7630E3EF7AB5D` | 22＋1 | 仅 0/255 | 清零 | 304,72–1200,944 | PASS |

花店 `v07` 的补充事实：

- 只有 1 个连通主体；
- 精确深灰外轮廓 `#2F3738` 占主体逻辑像素 3.74%，已与奶茶 4.15%、健身 4.14%、美业 4.21% 对齐；
- 相比 `v06` 改动 3118 个逻辑像素，改动集中在线色和浅木色，不改变外轮廓、花材数量或建筑结构；
- WebP SHA-256：`C6027A97CE6DED2018490772AD5917F38C7C88E4C6315B0AECAD676FA6C0C8A8`；Video PNG 与 Source PNG 哈希相同；
- ImageGen 原始洋红底 SHA-256：`11936309283D66EE6F6C058B4727C1BE382A2F67C256D1BDA48FF3F92602F377`；
- 完整机器记录：`batch06-metrics-v02.json` 与 `batch06-flower-v07-metrics.json`。

## 逐项视觉与经营语义 QA

| asset_id | 人工视觉检查 | 对应经营事实 | 结论 |
|---|---|---|---|
| PXL-FAC-MILKTEA-BASE-ALPHA-01 | 米白、灰绿和明亮雨棚清楚；入口与招牌留白可读，仍是窄幅双层临街骨架 | 高频外带、门前取餐、短停客流 | CONDITIONAL_PASS：粗像素与色盘成立，和美业的建筑差异待用户看 |
| PXL-FAC-FLOWER-BASE-ALPHA-01 | 米白墙、蓝灰玻璃、灰绿雨棚和浅木粉灰成立；两窗花束与两侧花盆可读，没有恢复库存堆积 | 橱窗吸引、外部少量陈列、到店转化 | PASS：清新非复古、粗像素、行业识别和同世界一致性通过 |
| PXL-FAC-GYM-BASE-ALPHA-01 | 四项中最现代；宽入口、横向比例和大面积冷蓝灰玻璃清楚，没有器械 | 会员到店、入口宽度、大型／楼上场馆到达 | PASS：差异最稳定 |
| PXL-FAC-BEAUTY-BASE-ALPHA-01 | 粉灰、米白和柔和窗光成立，入口相对收窄；没有美容椅或工位 | 预约到店、私密入口、服务门店氛围 | CONDITIONAL_PASS：行业氛围成立；与奶茶轮廓差异、侧灯箱伪文字联想待目检 |

## 固定母合同检查

- 正面或轻微平视：4/4 通过；
- 建筑比例、门窗与招牌留白稳定：4/4 通过；
- 像素密度不继续变细：4/4 通过，严格 8×8；
- 清新低饱和米白、浅木、灰绿、冷蓝灰和柔和砖红：4/4 通过；
- 深棕／深灰像素轮廓：4/4 通过；
- 无可读店名、数值、商标和水印：4/4 通过；
- 非 Minecraft、非体素 3D、非儿童卡通、非霓虹赛博朋克、非照片马赛克：4/4 通过；
- 不包含咖啡机、健身器械、库存、工位、收银台或座位：4/4 通过；
- alpha 仅 0/255、透明区 RGB 为 0、无色幕边和半透明脏边：4/4 通过。

花店上沿砖带和对称两层结构仍有传统街铺气质，但已经不构成复古风问题；该轻微风险保留给用户目检。

## 联系表

- 当前四项主联系表：`contact-sheets/contact-sheet-batch06-v06.png`，SHA-256 `710713325C111892C89619C43F28174ED50C7984DCEC7D121D9BF5E600A9662C`；
- 花店 `v06`／`v07` 最终微调对照：`contact-sheets/contact-sheet-batch06-flower-refinement-v04.png`，SHA-256 `4843A627999DDC5FCB3E923E2E6529B50FB31FD720F19705E9C4C959105BF7BA`；
- 网页 `v01` 与首轮 `v03` 对照：`contact-sheets/contact-sheet-batch06-style-comparison-v02.png`，仅保留生产谱系；
- `contact-sheet-batch06-v01.png` 至 `v05.png` 均是中间记录，不作为当前目检入口。

## 网站、直播与短视频用途

- 网站：奶茶／健身／美业使用 `web/batch06/*-v03.webp`、花店使用 `web/batch06/*-v07.webp` 作为未来替换候选；当前页面仍使用原 `v01`；
- 直播：对应 `video/batch06/` 透明 PNG 可作为横版沙盘行业切换底层，店名、状态与数据另用 HTML／SVG／直播覆盖层；
- 9:16 短视频：透明门脸可置于竖屏中部或下半部，周围保留 NPC、顾客、客流和字幕空间；
- 四张都只是“正常经营基线门脸”，不能直接冒充新开、老化、闭店或客流变化。

## 下一批最值得生产什么

先停止扩批并等待用户目检。若本批通过，下一批优先用已有像素拼装而不是重画整店：

1. S1 临街店中央门开启 Patch；
2. M1 商场沿边店闭店卷帘 Patch；
3. M2 岛柜闭店罩／封闭板 Patch。

只有现有门脸确实覆盖不了外带小档口时才新增 S2；P1 项目工作室等到项目交付诊断链出现真实镜头再做。下一批仍不生产店内设备。

## 状态边界

本批证明的是：四张网页现用门脸的正式源文件、候选、副本、提示词、联系表和 QA 都已经保存在当前知识库，并形成可提交用户目检的粗像素候选。它不证明用户已经接受视觉，不证明候选已接入网页，也不证明行业产品完成或获得市场验证。
