---
type: prompt_library
layer: products
status: review
validity: current
retrieval: on_demand
effective_from: 2026-08-05
updated: 2026-08-06
confidence: confirmed
privacy: private
schema_version: temporal-governance-v2
---

# 像素经营沙盘提示词库 v0.1

## 执行方式

- 生成模式：内置 ImageGen；每个资产单独调用。
- 生成前置门：先确认目标是否属于 NPC、门脸或门脸外部可见动态。能够由现有门脸、人物和客流拼出的画面不调用 ImageGen；咖啡机、健身器材、库存、工位、货架、收银台和店内座位等内部对象直接停止，不因缺失而生成。
- 透明方式：人物与客流优先使用纯色抠图底；Batch 02 因行业设备含灰绿，统一使用 `#FF00FF` 洋红幕，再在本地去背景、清边和裁边；没有切换 CLI/API 路径。
- 参考图角色：现有 M1 咖啡店立面是世界观和像素密度参考；现有顾客 A/B 是成年人物比例、轮廓和色盘参考；竞品状态 02/03 以第一张竞品门店为严格几何母版。
- 所有文字、数值、店名、经营半径、路线、证据标记、六边图、箭头和标签均不进入位图，由 SVG/CSS/HTML 实现。
- 像素密度硬门：用户指出 Batch 02 首轮源稿过细后，禁止再把更密的纹理当作升级。所有新图必须先降到 8×8 逻辑像素网格、最多 32 个主体色阶，再进入候选拼装；`v01/v02` 过细稿只保留溯源。

## 当前母合同 `MC-v04-FACADE-ONLY`

该合同由用户最新“页面只展示门脸”的范围纠偏触发，优先级高于本文件所有早期合同。`MC-v01`、`MC-v02`、`MC-v03-FRESH` 及 Batch 02／03 的内部对象提示词只保留生产谱系，不再授权重生店内设备。

```text
Asset scope: create exactly one of three things only: (1) a mature NPC/customer/staff sprite, (2) a complete storefront facade, or (3) a facade-visible state change of the exact same storefront.
Product view: the product shows the shop from outside as a straight-on front elevation or gentle eye-level facade. If an object would only be useful inside the shop, do not generate it.
Allowed NPC actions: walking past, entering, leaving, pausing at the window, consulting near the entrance, pointing, recording, thinking, serving at the doorway, waiting outside and forming an exterior queue.
Allowed facade types: street storefront, mall inline frontage, mall island/open storefront, upstairs/large-venue frontage and appointment-studio frontage. Industry difference must come from architecture, aperture, entrance, blank sign shape, window rhythm, awning and restrained exterior display—not from machines or interior equipment.
Allowed facade dynamics: empty lot, construction, completed shop, door open/closed, lights on/off, normal/new/closed competitor, maintained/quiet/active exterior, sparse/normal/crowded passing traffic and exterior queue.
Geometry invariant: state variants must preserve the exact facade width, height, roofline, columns, door, windows, sign panel, camera, pixel density and ground line. Change only the named door, light, shutter, exterior maintenance or people layer.
Forbidden interior assets: coffee machine, grinder, drink sealer, register, pickup rack, treadmill, strength equipment, turnstile, beauty chair, mirror station, stock bucket, inventory pile, shelf, cashier counter, indoor seating and any utilization state that requires an interior view.
Information layer: business numbers, store name, inventory, profit, utilization, diagnosis, routes, radius, arrows and confirmed/possible/pending labels must be HTML/SVG/CSS, never bitmap text.
Style: fresh bright coarse mature 2D pixel art; stable 8×8 logical grid, restrained color count, high-key off-white, pale wood, cool blue-gray glass, fresh gray-green and charcoal outlines. No extra micro-detail, sepia, vintage nostalgia, Minecraft, voxel 3D, chibi, neon cyberpunk, logo, brand, watermark or signature.
Stop rule: if the requested image cannot be directly seen or composited in a facade shot, do not generate it; record it as out of scope.
```

## 固定母合同 `MC-v01`

```text
Use case: stylized-concept
Asset type: modular pixel-art business simulation sprite for website, livestream and vertical short video
Style/medium: photo-referenced architectural facade pixel art and mature 2D character pixel art; straight-on front elevation or gentle eye-level side view; same pixel density, dark brown or dark gray pixel outlines, adult proportions and restrained detail as the approved coffee-shop assets
Color palette: low-saturation off-white, wood brown, brick red and gray-green; natural skin tones; no vivid neon
Composition: one isolated asset, complete silhouette, generous padding, no crop, stable ground line, designed to layer over the existing coffee-shop street scene
Scene/backdrop: perfectly flat solid chroma-key background for local background removal; use #00FF00 for people and crowds, and #FF00FF for competitor facades
Background constraints: one uniform color only; no shadows, gradients, texture, reflections, floor plane or lighting variation; do not use the selected key color anywhere in the subject
Text constraints: no text, letters, numbers, shop names, brands, logos, signs, watermark or signatures
Avoid: Minecraft, voxel 3D, isometric room, childlike cartoon, chibi proportions, neon cyberpunk, glossy 3D, photo mosaic filter, blurry anti-pixel painting, decorative objects without a business-state meaning
Continuity: do not redesign the approved main coffee shop; any state variant changes only the named person, crowd density or competitor operating state
```

## Batch 01

### 执行记录

| 提示词版本 | asset_id | 纯色抠图底 | 透明主文件 |
|---|---|---|---|
| P01-v01 | PXL-CUS-ENTER-A-01 | #00FF00 | source/batch01/pxl-cus-enter-a-01-v01.png |
| P02-v01 | PXL-CUS-PAUSE-B-01 | #00FF00 | source/batch01/pxl-cus-pause-b-01-v01.png |
| P03-v01 | PXL-CUS-CONSULT-A-01 | #00FF00 | source/batch01/pxl-cus-consult-a-01-v01.png |
| P04-v01 | PXL-CUS-LEAVE-B-01 | #00FF00 | source/batch01/pxl-cus-leave-b-01-v01.png |
| P05-v01 | PXL-CUS-SEATED-A-01 | #00FF00 | source/batch01/pxl-cus-seated-a-01-v01.png |
| P06-v01 | PXL-STF-SERVE-01 | #00FF00 | source/batch01/pxl-stf-serve-01-v01.png |
| P07-v01 | PXL-TRF-SPARSE-01 | #00FF00 | source/batch01/pxl-trf-sparse-01-v01.png |
| P08-v01 | PXL-TRF-NORMAL-01 | #00FF00 | source/batch01/pxl-trf-normal-01-v01.png |
| P09-v01 | PXL-TRF-CROWDED-01 | #00FF00 | source/batch01/pxl-trf-crowded-01-v01.png |
| P10-v01 | PXL-CMP-NORMAL-01 | #FF00FF | source/batch01/pxl-cmp-normal-01-v01.png |
| P11-v01 | PXL-CMP-NEW-01 | #FF00FF | source/batch01/pxl-cmp-new-01-v01.png |
| P12-v01 | PXL-CMP-CLOSED-01 | #FF00FF | source/batch01/pxl-cmp-closed-01-v01.png |

以上 12 项均为单独调用。P11、P12 以 P10 的竞品门店为状态编辑参考；实际几何连续性通过视觉检查，但不登记为逐像素完全一致。

### `P01-v01`｜`PXL-CUS-ENTER-A-01`

```text
Primary request: create one adult female coffee-shop customer sprite derived from the approved Customer A visual language, turning from a sidewalk walk into entering a doorway to her right; one foot crosses an implied threshold, torso turns toward the shop, one hand reaches naturally toward an unseen door handle; no door and no building included
Business variable: passerby-to-entry conversion; clearly reads as entering rather than merely walking past
Input images: approved coffee facade as world/style reference; approved Customer A as character proportion and palette reference
Constraints: full body; mature adult proportions; preserve the approved white jacket, muted rust top, gray-green trousers and shoulder bag family without copying stray artifacts; no phone-focused pose; apply MC-v01
```

### `P02-v01`｜`PXL-CUS-PAUSE-B-01`

```text
Primary request: create one adult male office-worker customer sprite derived from the approved Customer B visual language, stopped in front of an implied shop window, body angled slightly toward the display, brief observant pause, briefcase lowered naturally; no window and no building included
Business variable: roadside attention and storefront stopping rate; clearly reads as stopping to look rather than walking
Input images: approved coffee facade as world/style reference; approved Customer B as character proportion and palette reference
Constraints: full body; mature adult proportions; preserve muted gray-green jacket, dark trousers and briefcase family; apply MC-v01
```

### `P03-v01`｜`PXL-CUS-CONSULT-A-01`

```text
Primary request: create a compact two-person interaction sprite: the approved-style adult female customer stands at a very small unbranded coffee counter edge and asks a question while an adult barista listens and points to a plain menu area with no writing; the interaction must read as consultation before purchase
Business variable: entry-to-consultation and consultation-to-purchase handoff
Input images: approved coffee facade as world/style reference; approved Customer A and approved operator/expert NPC only as adult scale and pixel-outline references
Constraints: both full figures visible from head to shoe where practical; one small counter edge only; no readable menu, text, logo, price, cash register total or speech bubble; apply MC-v01
```

### `P04-v01`｜`PXL-CUS-LEAVE-B-01`

```text
Primary request: create one adult male office-worker customer sprite turning away from an implied coffee-shop entrance and leaving without a purchase; shoulders slightly withdrawn, empty free hand visible, briefcase still carried, movement direction clearly away from the shop; no door and no building included
Business variable: entry loss or consultation loss; clearly reads as leaving without buying, not arriving
Input images: approved coffee facade as world/style reference; approved Customer B as character proportion and palette reference
Constraints: full body; mature adult proportions; calm and realistic, not melodramatic disappointment; no purchased cup or shopping bag; apply MC-v01
```

### `P05-v01`｜`PXL-CUS-SEATED-A-01`

```text
Primary request: create one adult female coffee-shop customer derived from the approved Customer A visual language, seated naturally on a simple backless wooden café stool, body settled rather than preparing to leave, plain cup resting in one hand and the other hand relaxed
Business variable: in-store dwell and seating use; clearly reads as a customer who entered and stayed
Input images: approved coffee facade as world/style reference; approved Customer A as character proportion and palette reference
Constraints: complete seated silhouette including stool and shoes; mature adult proportions; one minimal stool only; no table, phone focus, text or logo; apply MC-v01
```

### `P06-v01`｜`PXL-STF-SERVE-01`

```text
Primary request: create one adult coffee-shop employee sprite in a muted off-white shirt, wood-brown apron and gray-green trousers, carefully extending one plain takeaway cup toward a customer outside the frame; stable serving posture, both hands naturally resolved
Business variable: consultation-to-delivery handoff and visible service throughput
Input images: approved coffee facade and the barista generated inside PXL-CUS-CONSULT-A-01 as identity, scale, outline and uniform references
Constraints: full body; keep adult identity, uniform colors and proportions consistent with the consultation barista; cup has no logo or writing; apply MC-v01
```

### `P07-v01`｜`PXL-TRF-SPARSE-01`

```text
Primary request: create a single reusable group sprite of exactly two unrelated adult sidewalk pedestrians, spaced far apart on one ground line, both moving naturally past a storefront without interacting
Business variable: sparse roadside traffic
Input images: approved coffee facade and approved Customer A/B as world, adult scale, outline and palette references
Constraints: exactly two people; varied but restrained clothing; no duplicated twins, no children, no staff uniform, no queue; apply MC-v01
```

### `P08-v01`｜`PXL-TRF-NORMAL-01`

```text
Primary request: create a single reusable group sprite of exactly five unrelated adult sidewalk pedestrians on one ground line, natural gaps and mixed walking directions, readable as normal healthy foot traffic rather than a queue
Business variable: normal roadside traffic baseline
Input images: approved coffee facade and approved Customer A/B as world, adult scale, outline and palette references
Constraints: exactly five adults; varied silhouettes and restrained clothing; no duplicated twins, no children, no staff uniform, no line formation; apply MC-v01
```

### `P09-v01`｜`PXL-TRF-CROWDED-01`

```text
Primary request: create a single reusable group sprite of eight adult customers forming a compact but orderly coffee-shop queue, all feet aligned to one ground band, varied poses including waiting and one person checking the line ahead
Business variable: crowded demand and queue congestion
Input images: approved coffee facade and approved Customer A/B as world, adult scale, outline and palette references
Constraints: exactly eight adults; queue must be visually clear without signs or ropes; no children, no duplicated twins, no panic, no festival crowd; apply MC-v01
```

### `P10-v01`｜`PXL-CMP-NORMAL-01`

```text
Primary request: create one original small competing coffee-shop facade as a standalone modular sprite, straight-on front elevation, one storey, blank sign panel, door, two front windows, restrained awning and two small planters; it should belong to the approved main coffee shop's world but have clearly different architecture
Business variable: existing normal competitor in the external market
Input images: approved main coffee facade as pixel density, adult visual tone, outline and palette reference only
Constraints: complete building silhouette; stable orthographic proportions; no people; blank sign; no copied geometry, brand or specific reference-building details; apply MC-v01
```

### `P11-v01`｜`PXL-CMP-NEW-01`

```text
Use case: precise-object-edit
Primary request: change only the operating state of the generated normal competitor facade so it unmistakably reads as newly opened: fresh clean paint, newly installed blank awning, warm interior lights, a modest opening ribbon by the doorway and freshly placed planters
Business variable: newly opened competitor that may divert traffic
Input images: generated PXL-CMP-NORMAL-01 as the edit target and exact geometry master
Invariants: preserve the exact building width, height, roofline, door, windows, sign panel, camera, pixel density, outline, palette family and transparent-cutout composition; add no people and no text; apply MC-v01
```

### `P12-v01`｜`PXL-CMP-CLOSED-01`

```text
Use case: precise-object-edit
Primary request: change only the operating state of the generated normal competitor facade so it unmistakably reads as closed: lights off, roll-down shutter over the entrance, windows dimmed or papered from inside, planters slightly neglected
Business variable: competitor exit or reduced external supply
Input images: generated PXL-CMP-NORMAL-01 as the edit target and exact geometry master
Invariants: preserve the exact building width, height, roofline, door position, windows, sign panel, camera, pixel density, outline, palette family and transparent-cutout composition; no damage, no ruin, no people and no text; apply MC-v01
```

## Batch 02｜母壳、行业套件与使用态

### 执行记录

| 提示词版本 | asset_id | 生成方式 | `v03` 粗像素阶段文件（已降级） |
|---|---|---|---|
| D01-v03 | PXL-SHL-S1-NEUTRAL-01 | 本地派生，不调用 ImageGen | source/batch02/pxl-shl-s1-neutral-01-v03.png |
| B02-P01＋CAL-v03 | PXL-SHL-M1-EMPTY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-shl-m1-empty-01-v03.png |
| B02-P02＋CAL-v03 | PXL-SHL-M2-EMPTY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-shl-m2-empty-01-v03.png |
| B02-P03＋CAL-v03 | PXL-SHL-L1-EMPTY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-shl-l1-empty-01-v03.png |
| B02-P04＋CAL-v03 | PXL-SHL-R1-EMPTY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-shl-r1-empty-01-v03.png |
| B02-P05＋CAL-v03 | PXL-KIT-COF-SERVICE-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-cof-service-01-v03.png |
| B02-P06＋CAL-v03 | PXL-KIT-MILKTEA-SERVICE-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-milktea-service-01-v03.png |
| B02-P07＋CAL-v03 | PXL-KIT-FLOWER-DISPLAY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-flower-display-01-v03.png |
| B02-P08＋CAL-v03 | PXL-KIT-BEAUTY-STATION-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-beauty-station-01-v03.png |
| B02-P09＋CAL-v03 | PXL-KIT-GYM-ENTRY-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-gym-entry-01-v03.png |
| B02-P10＋CAL-v03 | PXL-KIT-GYM-CARDIO-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-gym-cardio-01-v03.png |
| B02-P11＋CAL-v03 | PXL-KIT-GYM-STRENGTH-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-kit-gym-strength-01-v03.png |
| B02-P12＋CAL-v03 | PXL-STF-FLORIST-WRAP-01 | 独立 ImageGen＋粗像素校准 | source/batch02/pxl-stf-florist-wrap-01-v03.png |
| B02-P13＋CAL-v03 | PXL-STA-BEAUTY-STATION-USED-01 | 以空闲工位精确编辑＋粗像素校准 | source/batch02/pxl-sta-beauty-station-used-01-v03.png |
| B02-P14＋CAL-v03 | PXL-STA-GYM-CARDIO-USED-01 | 以三台跑步机精确编辑＋粗像素校准 | source/batch02/pxl-sta-gym-cardio-used-01-v03.png |

当前版本映射：`v04` 是第一轮清新调色中间稿，仅保留比较；14 个新生成原子资产的当前目检候选为 `v05`；S1 因需逐像素保留旧 alpha，当前目检候选为 `v06`。清新场景 `scenes/*-v03` 由这些 `v05/v06` 原子资产拼装。逐项路径与哈希以 `asset-manifest.md` 为准。

### Batch 02 历史母合同 `MC-v02`｜已冻结

该合同记录 Batch 02 已发生的生产。P01–P04 门脸壳仍可作为建筑参考；P05–P14 的店内设备与使用态不得继续调用或重生。

```text
Use case: stylized-concept or precise-object-edit
Asset type: one modular pixel-art business-simulation asset for website, livestream and vertical short video
Primary rule: create only the named shell, equipment set or operating-state change; never redesign an entire store when a reusable shell already exists
View: strict straight-on front elevation or gentle eye-level, stable ground line, no strong isometric perspective
Pixel density: intentionally coarse mature 2D pixel art matching the approved Customer A/B and M1/M2 assets; large readable pixel clusters, simplified material planes and faces, no tiny texture; never become more detailed than the approved references
Palette: low-saturation off-white, warm wood, brick red, gray-green and deep brown/charcoal outlines; compact palette, no neon
Scene/backdrop: perfectly flat solid #FF00FF chroma-key background, no floor, gradient, shadow, reflection or texture; do not use magenta/purple in the subject
Composition: one isolated complete silhouette, generous padding, no crop, reusable as a layer
Text constraints: no words, letters, numbers, menu writing, price, brand, logo, watermark, signature, UI, arrow or diagnostic label
Avoid: Minecraft, voxel 3D, childlike cartoon, chibi, neon cyberpunk, photo mosaic filter, photorealism, glossy 3D render and decorative clutter without an operating meaning
Post-process gate: source generation is never the final asset; convert to an 8×8 logical pixel grid with at most 32 subject colors, hard alpha edge, nearest-neighbor assembly and no chroma residue before QA
```

### 逐资产提示词差量

以下差量只保留生成时的提示词谱系。`v01` 源图因当时缺少足够强的像素密度硬门而被降级；门脸壳若需重做必须使用当前 `MC-v04-FACADE-ONLY`，内部对象不得重生。

#### `B02-P01`｜`PXL-SHL-M1-EMPTY-01`

```text
Create one empty shopping-mall inline storefront shell: wide open aperture, clean side columns, blank fascia, empty back wall and empty floor. No street, counter, shelf, furniture, people, products or industry equipment. Business meaning: mall opening and reusable industry-independent capacity.
```

#### `B02-P02`｜`PXL-SHL-M2-EMPTY-01`

```text
Create one empty shopping-mall island kiosk shell: low counter around three visible sides, clear central staff zone, overhead frame with blank fascia and closed storage panels. It must read as four-direction interception, not a street shop. No machines, products, people or text.
```

#### `B02-P03`｜`PXL-SHL-L1-EMPTY-01`

```text
Create one empty large/upstairs commercial venue frontage: wide glass bays, centered double entry doors, blank fascia and visible empty floor. Leave broad equipment insertion zones. No desk, gate, chairs, gym machines, people or industry objects.
```

#### `B02-P04`｜`PXL-SHL-R1-EMPTY-01`

```text
Create one empty appointment-service studio shell with two or three readable workstation insertion bays and one small empty waiting zone. No chair, mirror, sink, shelf, equipment, curtain, people or industry cue.
```

#### `B02-P05`｜`PXL-KIT-COF-SERVICE-01`

```text
Create one independent normal-operation coffee workstation: long wood/off-white counter, compact espresso machine, grinder, cup stack, pickup ledge and under-counter storage. No people, menu, text, sign, room or storefront.
```

#### `B02-P06`｜`PXL-KIT-MILKTEA-SERVICE-01`

```text
Create one milk-tea service workstation with four visually distinct positions: order/payment, drink making with shaker and cup sealer, pickup shelf, and delivery-order rack. Differentiate by equipment layout, never by labels. No people or full store.
```

#### `B02-P07`｜`PXL-KIT-FLOWER-DISPLAY-01`

```text
Create one flower display and wrapping workstation: grouped floor-height buckets, distinct normal fresh-flower varieties, compact wood wrapping table, paper-roll holder, plain paper, ribbon and safely placed scissors. No person, price tag, wedding scene or full shop.
```

#### `B02-P08`｜`PXL-KIT-BEAUTY-STATION-01`

```text
Create one empty adult beauty appointment workstation: adjustable chair, opaque gray-green mirror panel, small wheeled trolley and compact storage cabinet. It must read as one usable capacity unit, not a medical bed or pink glamour salon. No people or reflection.
```

#### `B02-P09`｜`PXL-KIT-GYM-ENTRY-01`

```text
Create one compact gym entrance module containing exactly one low reception counter, one single-person turnstile and one small open shoe/bag cubby. No person, room, sign, number or loose prop.
```

#### `B02-P10`｜`PXL-KIT-GYM-CARDIO-01`

```text
Create exactly three matching commercial treadmills in one clean horizontal row, identical scale, spacing, direction and ground line, easy to crop or repeat. No person, bottle, towel, UI text, room or extra machine.
```

#### `B02-P11`｜`PXL-KIT-GYM-STRENGTH-01`

```text
Create exactly one squat rack, one adjustable bench and one short two-tier dumbbell rack as a compact strength module. Mechanically plausible, fully visible, no person, loose plate, room, mirror or extra equipment.
```

#### `B02-P12`｜`PXL-STF-FLORIST-WRAP-01`

```text
Create exactly one mature adult florist standing and actively wrapping a low-saturation bouquet with both hands. Muted off-white shirt, wood-brown apron, gray-green trousers, dark shoes. Full body, no workstation, no second person and no decorative background.
```

#### `B02-P13`｜`PXL-STA-BEAUTY-STATION-USED-01`

```text
Precise edit of the empty beauty station: preserve exact equipment geometry and add exactly one seated adult client plus one adult worker delivering a calm non-medical service. Keep one station normally occupied, no extra people, no medical procedure and no redesign.
```

#### `B02-P14`｜`PXL-STA-GYM-CARDIO-USED-01`

```text
Precise edit of the three-treadmill module: preserve all three machines and add exactly one mature adult jogging on the center treadmill; left and right remain empty. Align feet and hands to the machine; no trainer, crowd, bottle, towel or extra equipment.
```

### 本地派生 `D01-v03`

```text
Source: Batch 01 PXL-CMP-NORMAL-01 approved-style facade.
Operation: preserve the exact building, door, windows, awning, planters, sign panel and transparency; replace only the two lower window interiors with neutral dark insertion zones aligned to the coarse pixel grid.
Purpose: allow S1 milk-tea and S1 flower scenes to reuse one exact shell instead of regenerating two storefronts.
```

### 像素密度校准 `CAL-v03`

```text
1. Key the flat #FF00FF background and remove edge spill.
2. Reduce the asset to an 8×8 logical pixel grid.
3. Quantize the new subject to no more than 32 RGBA colors.
4. Convert alpha to hard pixel edges and clear RGB under transparent pixels.
5. Crop only on 8-pixel boundaries with 16-pixel padding.
6. Assemble scenes at 192×128 and enlarge to 1536×1024 with nearest-neighbor only.
```

## 清新明亮历史合同 `MC-v03-FRESH`｜受门脸范围限制

该合同由用户 2026-08-05 的最新视觉纠偏触发，优先级高于 Batch 02 旧 `MC-v02` 中容易被解释成棕黄复古的色盘描述。它不推翻 M1/M2 已通过资产，也不增加像素精细度。

```text
Asset type: modular 2D pixel-art asset for a fresh modern business-simulation world
Primary visual target: clean, bright, contemporary and airy; use the supplied approved M1/M2 assets for pixel density and adult tone, and the two user-provided storefront references only for brightness, blue-gray glass, light neutral surfaces and fresh plant color
Pixel density: preserve the existing coarse 8×8 logical grid and large readable pixel clusters; never add smaller pixels, microtexture, anti-aliased detail or a more realistic rendering level
View: straight-on front elevation or gentle eye-level; stable geometry and ground line; no isometric or dramatic perspective
Palette: high-key off-white and light warm gray, pale natural wood, muted brick-red accents, lively gray-green plants, cool blue-gray glass, charcoal or deep blue-gray outlines
State-edit invariant: for current work, only create facade-visible variants such as construction/completed, door open/closed, lights on/off, normal/new/closed competitor and exterior people count; preserve the exact shell, camera and proportions. Low/normal/backlog inventory, idle/used/full equipment and 0/3–3/3 utilization prompts are historical and frozen.
Text and marks: leave sign panels blank; no words, letters, numbers, price, logo, brand, trademark, watermark, signature or UI
Avoid: sepia, muddy brown-yellow cast, vintage nostalgia, heavy ornamental cornices, retro shopfront styling, excessive facade trim, Minecraft, voxel 3D, childlike cartoon, chibi, neon cyberpunk, glossy 3D and photo-mosaic filtering
Background for cutouts: flat #FF00FF chroma key, no floor, gradient, cast shadow, texture or magenta in the subject
Post-process gate: hard alpha, zero RGB under transparent pixels, no chroma residue; keep source geometry and alpha unchanged for recolor-only versions
```

### 清新调色与拼装协议

#### `LUT-v05`｜14 个粗像素原子资产

```text
Input: the selected 8×8 coarse-pixel source asset.
Operation: apply a deterministic one-to-one palette mapping only. Move muddy brown-yellow midtones toward high-key off-white, pale natural wood, cool blue-gray, fresh gray-green and charcoal while preserving skin, flowers and low-saturation brick-red accents.
Invariants: canvas, bbox, alpha, every silhouette pixel, 8×8 block structure, equipment geometry and color-count ceiling remain unchanged. No resizing, blur, anti-aliasing, dithering, texture, new highlight, new trim or extra detail.
Output: v05 current visual-review candidate plus matching lossless WebP and PNG copies.
```

#### `ALPHA-v06`｜S1 alpha 保真调色

```text
Input: S1 neutral shell and its original alpha channel.
Operation: change RGB only using the fresh palette; copy the alpha channel byte-for-byte.
Hard invariants: preserve all 202 alpha levels, all 5026 semi-transparent edge pixels, canvas, bbox and transparent-area RGB cleanup. Do not harden, feather, blur or redraw the edge.
Output: source/batch02/pxl-shl-s1-neutral-01-v06.png.
```

#### `ASM-v03-FRESH`｜8 张清新拼装样景

```text
Use only the current v05 modules and S1 v06 shell. Preserve the earlier scene coordinates, layer order, camera, scale and 192×128 logical canvas; assemble with nearest-neighbor only and enlarge to 1536×1024.
Do not add new architecture, ornament, people, labels or micro-detail. Keep names, numbers, routes and diagnostics in HTML/SVG/CSS.
Output scenes are visual-review candidates, not webpage integration or user acceptance.
```

## Batch 03｜经营状态链与诊断负责人

### 执行记录

| 提示词版本 | asset_id | 生产方式 | 当前候选 |
|---|---|---|---|
| B03-D01-v01 | PXL-STA-FLOWER-STOCK-LOW-01 | 复用正常花材模块，本地删减花束与保留空桶 | source/batch03/pxl-sta-flower-stock-low-01-v01.png |
| B03-D02-v01 | PXL-STA-FLOWER-STOCK-BACKLOG-01 | 复用正常花材模块，本地复制花材并挤占包装区 | source/batch03/pxl-sta-flower-stock-backlog-01-v01.png |
| B03-D03-v02 | PXL-STA-BEAUTY-STATION-FULL-01 | 复用单工位使用态，本地等距重复为 3/3 | source/batch03/pxl-sta-beauty-station-full-01-v02.png |
| B03-P01＋CAL-v03 | PXL-STA-BEAUTY-WAITING-01 | 单独调用内置 ImageGen 生成缺失人物，再压回 8×8 粗像素 | source/batch03/pxl-sta-beauty-waiting-01-v01.png |
| B03-D04-v01 | PXL-STA-GYM-CARDIO-TWO-USED-01 | 复用 v05 跑步机几何与 1/3 状态，本地拼入缺失人物 | source/batch03/pxl-sta-gym-cardio-two-used-01-v01.png |
| B03-D05-v01 | PXL-STA-GYM-CARDIO-FULL-01 | 复用同一跑步机几何，本地拼成 3/3 | source/batch03/pxl-sta-gym-cardio-full-01-v01.png |
| B03-NPC-P03-v04 | PXL-NPC-DIAG-OWNER-01 | 以专业 NPC 为造型母版、以第二张参考为脸型／黑发参考进行精确编辑 | source/batch03/pxl-npc-diag-owner-01-v04.png |

### 本地状态差量

#### `B03-D01-v01`｜花材库存少

```text
Source: PXL-KIT-FLOWER-DISPLAY-01 v05 normal stock.
Preserve: exact counter, buckets, wrapping table, tools, canvas, viewpoint, 8×8 grid and palette.
Change only: remove most flower bunches and leave many clearly empty buckets; retain a small sellable remainder.
Business meaning: low stock and lost-sales risk, not shop closure.
Do not add text, warning symbols, wilted flowers or a redesigned workstation.
```

#### `B03-D02-v01`｜花材积压

```text
Source: the same v05 normal flower display.
Preserve: exact workstation geometry, camera, outline and pixel density.
Change only: increase the number of flower bunches until buckets are densely occupied and part of the wrapping area is visibly squeezed.
Business meaning: quantity backlog and turnover pressure; not decorative abundance.
Keep numerical inventory, loss rate and alert labels in HTML/SVG rather than the bitmap.
```

#### `B03-D03-v02`｜美容工位 3/3 满载

```text
Source: PXL-STA-BEAUTY-STATION-USED-01 v05.
Operation: repeat the same one-client/one-worker occupied station three times on one baseline with equal spacing.
Preserve each station at the exact source scale; no new people, furniture, mirrors, medical cues or room shell.
Business meaning: all three appointment stations are occupied.
```

#### `B03-D04/D05-v01`｜健身有氧 2/3 与 3/3

```text
Geometry master: PXL-KIT-GYM-CARDIO-01 v05 and PXL-STA-GYM-CARDIO-USED-01 v05.
Keep every treadmill pixel, machine spacing, monitor, rail, belt and baseline unchanged.
Generate only the missing mature adult exerciser concepts when necessary, then locally composite them onto the exact existing treadmill base and reduce them to the same 8×8 coarse grid.
2/3 state: left and center occupied, right empty.
3/3 state: one distinct adult on each treadmill.
No trainer, queue, room, mirror, number, logo or UI; capacity labels remain HTML/SVG.
```

### ImageGen 缺失人物提示词

#### `B03-P01`｜美容等待人物组

```text
Create one compact reusable group sprite of exactly two mature adult appointment customers seated side by side on simple connected modern waiting seats. One customer calmly holds a small unbranded bag on the lap; the other subtly checks a wristwatch. The pose must read as waiting, not chatting, dining or receiving treatment.
Use the approved beauty station v05 only for adult scale, outline thickness, coarse pixel density and the fresh off-white, blue-gray, gray-green and light-wood palette. Do not copy the station, room, chair, mirror or tools.
Full bodies and complete seats visible, straight-on, generous padding, flat #FF00FF background. No room, floor, beauty equipment, text, brand, watermark or extra person. Apply MC-v03-FRESH and CAL-v03.
```

#### `B03-P02`｜健身缺失人物参考

```text
Precise-object edit reference: preserve the exact three-treadmill v05 geometry and the existing center exerciser. Add only one distinct mature adult to the left treadmill and one to the right treadmill, with feet on belts and hands near rails. Use muted gray-green/off-white for the left person and low-saturation brick red/charcoal for the right person.
Do not redraw any treadmill. The ImageGen result is a source for extracting the two missing people; the formal 2/3 and 3/3 assets must be assembled locally on the exact v05 machine base and returned to the 8×8 grid.
```

### 诊断负责人 NPC 精确编辑链

#### `B03-NPC-P01`｜黑发与成人感

```text
Edit the existing approved professional NPC only. Preserve the blue-gray rolled-sleeve shirt, beige trousers, brown shoes, clipboard, standing pose and full-body framing. Change brown hair to natural short black hair and make the face slightly more mature and less childlike. No new outfit, object, text, logo or background.
```

#### `B03-NPC-P02`｜脸型参考迁移

```text
Use the professional NPC as the pose, outfit and responsibility master. Use the user's second pixel-avatar image only as a likeness reference for short black hair, face shape, eyebrows, eyes and natural smile. Do not copy its black sports jacket, shorts, socks, shoes, pose, black background or styling. Keep the clipboard and professional business-diagnosis role.
```

#### `B03-NPC-P03`｜头身比修正

```text
Precise-object edit of the face-transfer draft. Reduce the complete head, including hair, face, ears and jaw, by about 10–12 percent while keeping the body height, shoulder width, limbs, professional outfit, clipboard and feet unchanged. Restore a visible neck and natural shoulder transition. Keep the transferred mature face and short black hair. Target an adult full-body pixel-character ratio close to 1:5, not chibi or large-headed.
```

版本边界：脸型迁移后但头部偏大的 `v03` 只保留在 `source/batch03/raw/`；比例修正后的 `v04` 才是当前目检候选。它仍未获得用户本人最终确认。

## Batch 04｜门脸差量与人物动作

### 执行记录

| 提示词版本 | asset_id | 生产方式 | 当前候选 |
|---|---|---|---|
| B04-D00-v01 | PXL-FAC-COFFEE-BASE-ALPHA-01 | 从已通过 M1 本地提取透明建筑主体 | source/batch04/pxl-fac-coffee-base-alpha-01-v01.png |
| B04-D01-v01 | PXL-FAC-COFFEE-DOOR-OPEN-PATCH-01 | M1 为几何母版、M2 门开只作局部参考 | source/batch04/pxl-fac-coffee-door-open-patch-01-v01.png |
| B04-D02-v01 | PXL-FAC-COFFEE-WINDOW-DARK-PATCH-01 | 只在 M1 玻璃内做冷灰绿暗化 | source/batch04/pxl-fac-coffee-window-dark-patch-01-v01.png |
| B04-D03-v01 | PXL-FAC-COFFEE-SHUTTER-CLOSED-PATCH-01 | 在 M1 门洞按 8px 网格本地绘制卷帘 | source/batch04/pxl-fac-coffee-shutter-closed-patch-01-v01.png |
| B04-D04-v03 | PXL-CMP-NEW-OVERLAY-01 | 正常竞品为几何母版；从新开参考严格提取红绸 | source/batch04/pxl-cmp-new-overlay-01-v03.png |
| B04-D05-v03 | PXL-CMP-AGED-OVERLAY-01 | 正常竞品上只改变雨棚与绿植整对象色盘 | source/batch04/pxl-cmp-aged-overlay-01-v03.png |
| B04-D06-v02 | PXL-CMP-CLOSED-OVERLAY-01 | 正常竞品上只压暗窗格并添加门洞卷帘 | source/batch04/pxl-cmp-closed-overlay-01-v02.png |
| B04-P01-v04＋CAL-v03 | PXL-CUS-WALK-CYCLE-A-01 | 单独调用内置 ImageGen 生成四步动作源，再本地去背景、统一脚底与粗像素 | source/batch04/pxl-cus-walk-cycle-a-01-v04.png |
| B04-P02-v02＋CAL-v03 | PXL-NPC-DIAG-OWNER-POINT-01 | 单独调用内置 ImageGen 编辑诊断负责人指向动作，再本地去背景与粗像素校准 | source/batch04/pxl-npc-diag-owner-point-01-v02.png |

### 本地门脸差量合同

#### `B04-D00/D01-v01`｜透明底层与门开

```text
Geometry master: the user-approved M1 coffee facade.
Extract one full-canvas RGBA facade layer without changing any building pixel, proportion, signboard blank, camera or palette.
For the door-open patch, use M2 door-open only as a local pose reference. Keep M1 as the exact alignment master and output only the changed door/doorway pixels on a 1536×1024 transparent canvas.
No full-image diff, blur, antialiasing, new trim, text, logo or redesign.
```

#### `B04-D02-v01`｜橱窗熄灯

```text
Source: the exact M1 coffee facade.
Change only the existing glass interiors in the left window, door glass and right window toward cool gray-green darkness. Preserve all frames, mullions, wall, brick, plants, signboard and building geometry.
Business meaning: lights off or non-business hours, not abandonment.
Output a full-canvas binary-alpha overlay; transparent RGB must be zero.
```

#### `B04-D03-v01`｜咖啡门洞卷帘

```text
Source geometry: the exact M1 central doorway.
Draw one neutral light gray / gray-green rolling shutter inside the existing door opening on an 8-pixel logical grid. Keep the doorframe and all other facade pixels unchanged.
Business meaning: entrance paused or closed. Do not imply bankruptcy without a separate verified label.
No rust, dirt, micro-texture, text, logo or full-store redesign.
```

#### `B04-D04-v03`｜竞品新开红绸

```text
Geometry master: PXL-CMP-NORMAL-01.
Use PXL-CMP-NEW-01 only as a semantic source. Extract only the saturated opening ribbon and its immediately adjacent dark outline. Exclude all door, window, wall, brick and interior pixels.
Map the ribbon to low-saturation brick red while preserving its coarse outline. Output a full-canvas binary-alpha overlay.
No brightened rectangular panes, floating color blocks, text, logo or geometry replacement.
```

#### `B04-D05-v03`｜竞品渐进老化

```text
Geometry master: PXL-CMP-NORMAL-01.
Change only two existing object classes: fade the metal awning from fresh gray-green toward a cooler desaturated gray-green, and reduce saturation in the two exterior foliage groups.
Preserve cream wall, brick base, windows, door, lamps, signboard and exact silhouette. The state is gradual maintenance aging while still operating.
No brown-yellow dirt, rust, sepia, regular repair bars, rectangular wall masks, micro-noise or redesigned architecture.
```

#### `B04-D06-v02`｜竞品闭店

```text
Geometry master: PXL-CMP-NORMAL-01.
Darken only the two existing glass-pane interiors along their real frame boundaries, then add one neutral gray-green rolling shutter inside the exact central doorway.
Preserve wall, signboard, awning, planters and building silhouette. Output a full-canvas binary-alpha overlay.
Business meaning: competitor exit / closed storefront. Confirmation labels and dates remain HTML/SVG.
No floating lamp rectangles, text, logo, rust, dirt or full-store replacement.
```

### ImageGen 最终人物提示词

#### `B04-P01-v01`｜顾客 A 四帧步行源

```text
Create one horizontal four-frame walk-cycle sprite sheet of the exact same mature adult Customer A shown in the provided approved pixel reference. Preserve her identity, short dark hair, off-white jacket, muted gray-green trousers, low-saturation brick-red accent, dark shoes, adult proportions, coarse dark outline and the same intentionally chunky pixel density.

Show four distinct natural walking phases from the same side-facing direction: contact, passing/down, opposite contact, passing/up. Keep the full body visible in every frame, equal scale, equal baseline and generous separation between frames. Do not add a phone, cup, bag, text, logo, watermark, scenery, floor, shadow or extra person.

Use a perfectly flat solid #FF00FF chroma background. Crisp hard pixel edges only. No antialiasing, gradients, sub-pixel texture, extra face detail, realistic painting, photo mosaic, voxel 3D, Minecraft, chibi, childlike cartoon, neon cyberpunk or retro sepia palette.
```

本地校准 `B04-P01-v04＋CAL-v03`：去除洋红底；四帧分别放入 `1024×1536`；统一脚底 `y=1312`；缩回 8×8 逻辑网格；最多 29 个 RGBA 色；只保留逐帧最大连通人物主体；透明 RGB 清零。ImageGen 源与 v01/v02/v03 中间稿保留，不覆盖。

#### `B04-P02-v01`｜诊断负责人指向动作源

```text
Edit the provided diagnostic-owner pixel character into one clear explanation pose pointing to the viewer's left. Preserve the same person, mature face, natural short black hair, adult approximately 1:5 head-to-body proportion, blue-gray rolled-sleeve shirt, beige trousers, brown shoes, clipboard, full-body scale and professional business-diagnosis role.

Change only the free arm and hand into an open, readable pointing / presenting gesture. Keep the clipboard in the other hand. The pose should feel calm and analytical, not theatrical or accusatory. Full body visible with generous padding.

Use a perfectly flat solid #FF00FF chroma background. Keep the same coarse, intentionally limited pixel density and dark outline as the approved current assets. No new outfit, sportswear, text, logo, watermark, scenery, floor, shadow, extra object, extra person, enlarged head, more facial detail, realistic painting, antialiasing, gradients, Minecraft, voxel 3D, chibi, child cartoon, neon cyberpunk or retro sepia styling.
```

本地校准 `B04-P02-v02＋CAL-v03`：去除洋红底；保持 `1024×1536`；压回 8×8 逻辑网格与 29 个 RGBA 色；二值 alpha；透明 RGB 清零。v01 的错误不透明背景只保留为溯源，v02 为当前候选。

### Batch 04 版本边界

- 门脸状态变化不调用 ImageGen，不重新设计整店；
- `PXL-CMP-NEW-OVERLAY-01` 当前只使用 v03；
- `PXL-CMP-AGED-OVERLAY-01` 当前只使用 v03；
- `PXL-CMP-CLOSED-OVERLAY-01` 当前只使用 v02；
- `PXL-CUS-WALK-CYCLE-A-01` 当前只使用 v04 与四张 f01–f04 v04；
- `PXL-NPC-DIAG-OWNER-POINT-01` 当前只使用 v02；
- ImageGen 共 2 次独立调用，没有混做不同资产，没有切换 CLI 或需要 API Key 的路径。

## Batch 05｜诊断动作与顾客 B 步行循环

Batch 05 是用户单独授权继续生产的候选批，不代表 Batch 04 已通过用户目检。本批只补 3 个已经确认缺失的人物动作，不扩行业、不重画门脸、不生成店内设备。

### 执行记录

| 提示词版本 | asset_id | 生产方式 | 当前候选 |
|---|---|---|---|
| B05-P01-v01＋CAL-v01 | PXL-NPC-DIAG-OWNER-RECORD-01 | 独立调用内置 ImageGen 生成记录姿态，再本地去背景、同色盘粗像素校准 | source/batch05/pxl-npc-diag-owner-record-01-v01.png |
| B05-P02-v01＋CAL-v01 | PXL-NPC-DIAG-OWNER-THINK-01 | 独立调用内置 ImageGen 生成思考姿态，再本地去背景、同色盘粗像素校准 | source/batch05/pxl-npc-diag-owner-think-01-v01.png |
| B05-P03-v01＋CAL-v01 | PXL-CUS-WALK-CYCLE-B-01 | 独立调用内置 ImageGen 生成顾客 B 四步源，再本地切帧、统一脚底与粗像素 | source/batch05/pxl-cus-walk-cycle-b-01-v01.png |

### ImageGen 最终提示词

#### `B05-P01-v01`｜诊断负责人记录事实

```text
Identity-preserving edit of the provided diagnostic-owner pixel character. Keep the exact same mature adult man, natural short black hair, face, approximately 1:5 adult proportion, blue-gray rolled-sleeve shirt, beige trousers, brown shoes, clipboard, professional business-diagnosis role and full-body scale. Use the approved pointing asset only as the coarse-pixel density and outline reference.

Change only the action: raise the clipboard to the abdomen or lower chest, hold it steadily with one hand, and use the other hand to write with one plain dark pen touching the blank paper. Lower the gaze slightly toward the paper. The pose should read as calmly recording customer or storefront facts, not signing a contract, operating a cashier or looking at a phone. Keep the paper blank with no readable marks.

Use a perfectly flat solid #FF00FF chroma background. Full body visible with generous padding. No text, number, checkmark, logo, watermark, floor, shadow, extra person, new outfit, extra detail, enlarged head, chibi, child cartoon, realistic painting, photo mosaic, voxel 3D, Minecraft, neon cyberpunk or retro sepia styling.
```

#### `B05-P02-v01`｜诊断负责人思考判断

```text
Identity-preserving edit of the provided diagnostic-owner pixel character. Keep the exact same mature adult man, natural short black hair, face, approximately 1:5 adult proportion, blue-gray rolled-sleeve shirt, beige trousers, brown shoes, clipboard, professional business-diagnosis role and full-body scale. Use the approved pointing asset only as the coarse-pixel density and outline reference.

Change only the action: hold the clipboard low at one side with one hand and let the fingertips of the free hand touch the chin in a calm analytical thinking pose. Use a subtle downward-side gaze. The emotion is “evidence seen, judgment still forming,” not anxiety, confusion or sadness. Do not add a thought bubble, question mark, light bulb, sweat drop or symbol.

Use a perfectly flat solid #FF00FF chroma background. Full body visible with generous padding. No text, number, logo, watermark, floor, shadow, extra person, new outfit, extra detail, enlarged head, chibi, child cartoon, realistic painting, photo mosaic, voxel 3D, Minecraft, neon cyberpunk or retro sepia styling.
```

#### `B05-P03-v01`｜顾客 B 四帧步行源

```text
Create one horizontal four-frame walk-cycle sprite sheet. Image 1 is the sole identity, outfit and prop reference for Customer B: the same mature male office worker, short brown-black hair, muted gray-green blazer, off-white shirt, dark narrow tie, dark gray trousers, brick-brown shoes and the same dark charcoal briefcase held in the same hand. Image 2 is only a layout, equal-baseline and coarse-pixel-density reference; do not copy or recolor Customer A.

Show four distinct natural left-facing walking phases: contact, passing/down, opposite contact, passing/up. Keep the exact same Customer B, adult proportion, scale, clothing, briefcase size, briefcase hand and dark outline in every frame. Only the limbs and the briefcase's small natural swing may change. Keep every full body visible, on the same baseline, with generous separation.

Use a perfectly flat solid #FF00FF chroma background. No phone, cup, new bag, text, logo, watermark, scenery, floor, shadow, extra person, extra detail, antialiasing, realistic painting, photo mosaic, voxel 3D, Minecraft, chibi, child cartoon, neon cyberpunk or retro sepia styling.
```

### 本地校准 `CAL-v01`

- 洋红 ImageGen 源保留在 `source/batch05/raw/`；软边去背景中间稿未直接进入正式候选，正式图使用二值、像素安全的本地色相抠图；
- 诊断负责人统一放入 `128×192` 逻辑画布，顶部 `y=24`、脚底 `y=163`，再最近邻放大为 `1024×1536`；
- 记录／思考严格复用 Batch 04 指向动作的 28 个主体色，最终为 29 个 RGBA 值；
- 顾客 B 四帧各自放入 `128×192`，顶部 `y=20`、脚底 `y=164`，四帧共用 28 个主体色，再拼为 `4096×1536`；
- 三项 alpha 仅 `0/255`，透明区 RGB 清零，不保留洋红残边，不生成文字；WebP 使用最近邻缩为 1/2，视频保留全尺寸 PNG。

### Batch 05 版本边界

- 当前只使用记录 v01、思考 v01、顾客 B 循环 v01 与 f01–f04 v01；
- 三次为相互独立的内置 ImageGen 调用，没有混做不同资产，没有切换 CLI 或需要 API Key 的路径；
- 记录动作是条件候选：在小尺寸下可能兼读为抱板查看；思考动作在小尺寸下可能略像捂嘴；
- 顾客 B 不是顾客 A 的换色复制，四帧身份、服装和公文包一致；
- Batch 04 与 Batch 05 都保持“内部 QA 后待用户目检”，不写成视觉锁定或网页接入。

## Batch 06｜当前网页门脸归库与本地粗像素统一

Batch 06 由盘点触发：当前网页已经使用奶茶、花店、健身和美业四张透明完整门脸，但它们此前未集中进入素材库，而且原 `v01` 的颜色与像素细节远多于当前人物和 Batch 04／05 的粗像素母合同。因此本批没有再次生成四家店，只归档原版并制作同结构低细节候选。

### 执行记录

| 派生合同 | asset_id | 生产方式 | 当前候选 |
|---|---|---|---|
| B06-LOCAL-COARSE-FRESH-v03 | PXL-FAC-MILKTEA-BASE-ALPHA-01 | 归档网页 v01；本地压缩逻辑像素、限定色盘、清理透明边缘 | source/batch06/pxl-fac-milktea-base-alpha-01-v03.png |
| B06-P01-v06＋B06-CAL-v07 | PXL-FAC-FLOWER-BASE-ALPHA-01 | v03 独立视觉 QA 不通过；只对花店调用 1 次内置 ImageGen，再本地去背景、粗像素化并软化内部线色 | source/batch06/pxl-fac-flower-base-alpha-01-v07.png |
| B06-LOCAL-COARSE-FRESH-v03 | PXL-FAC-GYM-BASE-ALPHA-01 | 归档网页 v01；等比放入标准画布、粗像素与清新蓝灰校准 | source/batch06/pxl-fac-gym-base-alpha-01-v03.png |
| B06-LOCAL-COARSE-FRESH-v03 | PXL-FAC-BEAUTY-BASE-ALPHA-01 | 归档网页 v01；本地粗像素与粉灰低饱和校准、透明 RGB 清零 | source/batch06/pxl-fac-beauty-base-alpha-01-v03.png |

### 本地派生合同 `B06-LOCAL-COARSE-FRESH-v03`

```text
Source identity and architecture: the exact current-web facade v01 for the named industry.
Preserve the complete building silhouette, front-elevation camera, door and window positions, blank sign areas, exterior plants and industry-readable exterior cues. Do not redesign the shop and do not introduce an interior object.

Fit the full facade to one 192×128 logical transparent canvas, then enlarge only by nearest-neighbour to 1536×1024. Use an exact 8×8 global pixel grid, binary alpha, transparent RGB zero and no more than 28 opaque colors. Use a shared fresh low-saturation palette: off-white, pale wood, muted brick coral, gray-green, cool blue-gray and dark charcoal outline. Lift large dark interior planes; do not add micro-texture, antialiasing or extra detail.

No readable text, shop name, number, logo, trademark or watermark. No Minecraft, voxel 3D, child cartoon, neon cyberpunk, retro sepia, photo-mosaic filter, indoor machine, gym equipment, inventory, cashier, workbench, chair or diagnostic label.
```

这不是 ImageGen 提示词，而是可重复执行的本地派生合同。它用于奶茶、健身和美业，也用于花店 ImageGen 结果的最终像素校准。

### 花店定向返修 `B06-P01-v06`

触发原因：花店本地粗化 `v03` 的技术门通过，但独立视觉 QA 判为一层过密、复古感偏重；`v04`／`v05` 的纯本地减法又丢失建筑层次。因此只返修花店，不重做另外三家。实际内置 ImageGen 调用提示词如下：

```text
Edit target: Reference image 1 is the existing flower-shop facade and is the only source of shop identity and basic architecture. Reference image 2 is a fresh, bright storefront style reference; use only its airy brightness, clean off-white surfaces and contemporary mood, never its text or brand. Reference image 3 is another accepted coarse-pixel facade from this same batch; use only its coarse pixel density, restrained palette and straight-on camera, not its industry or facade design.

Create one complete photo-referenced architectural facade pixel-art asset for the same small flower shop. Straight-on front elevation, fixed eye-level view, stable adult architectural proportions. Keep a clear blank sign panel. Simplify the lower floor to two readable display windows, one central entrance and only a few flower clusters plus two exterior planters. Flowers must function as a small exterior industry cue, not dense decoration. Use fresh, bright, low-saturation off-white, pale wood, muted brick coral, gray-green and cool blue-gray, with a dark brown or dark gray pixel outline. Keep the pixel level deliberately coarse and graphic, comparable to an 8-pixel grid; do not increase detail, texture or realism.

No readable text, shop name, number, logo, trademark or watermark. No indoor equipment, counter, furniture, inventory scene or people. Not retro sepia, not ornate vintage, not Minecraft, not voxel 3D, not child cartoon, not neon cyberpunk, not a photo mosaic filter. Output the isolated full facade on a perfectly flat solid #FF00FF chroma background with no shadow, gradient or glow.
```

参考角色：花店网页原版用于建筑身份；用户给出的清新门脸截图只用于明亮、当代、留白气质；健身 `v03` 只用于粗像素密度与批次色盘。三个参考都没有授权复制文字、商标或跨行业结构。

### 花店本地校准 `B06-CAL-v07`

- `v06`：对 ImageGen 洋红底结果去背景，缩到 `192×128` 逻辑画布，限制色盘，再最近邻放大；
- `v07`：只把非外轮廓的 `#2F3738` 内部硬黑线换成 `#3D4646`，把两档偏黄金色收回浅木色，并清掉雨棚上方的零星紫色；
- 保留外轮廓、门窗、招牌留白、花植位置和 8×8 网格，不增加任何像素细节；
- `v07` 精确深色外轮廓占主体逻辑像素 3.74%，与同批另外三张约 4.1% 的水平接近。

Batch 06 实际调用内置 ImageGen 1 次，只用于花店定向返修；没有切换 CLI／API 路径。原始洋红底结果已保存到 `source/batch06/raw/pxl-fac-flower-base-alpha-01-v06-imagegen-chroma.png`，正式交付不依赖 Codex 临时目录。

### Batch 06 版本边界

- `source/batch06/raw/*-v01.png` 是当前网页原版的逐字节归档；网页仍读取这些 `v01` 同内容文件；
- `v02` 是首次粗化中间稿，像素密度已合格，但暗面和棕红仍偏重，只保留生产谱系；
- 奶茶／健身／美业当前目检候选使用 `v03`；花店当前候选使用 `v07`；
- 花店 `v03` 是视觉不通过稿，`v04`／`v05` 是过度扁平的本地返修稿，`v06` 是 ImageGen 后的标准化中间稿，全部保留生产谱系但不作为当前入口；
- 当前网页仍读取四张原 `v01`，没有接入任何 Batch 06 候选；内部 QA 不等于用户视觉通过或风格锁定。

## Batch 07｜同几何门脸状态 Patch

Batch 07 执行“拼装优先”：不生成新整店、不增加店内对象，也不调用 ImageGen。咖啡门开／卷帘和竞品关闭只提供状态语义参考，不能直接缩放套用到不同门脸；每个 Patch 都重新核对当前母版的真实开口坐标，再用母版现有色盘在逻辑画布上绘制。

| 拼装合同 | asset_id | 母版与逻辑坐标 | 当前入口 |
|---|---|---|---|
| B07-D01-v04 | PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01 | 奶茶 v03，`192×128`；只替换门芯 `[88,82,103,114)` | source/batch07/pxl-fac-milktea-door-open-patch-01-v04.png |
| B07-D02-v02 | PXL-FAC-M1-SHUTTER-CLOSED-PATCH-01 | M1 v05，`139×97`；卷帘外框 `[17,42,121,86)` | source/batch07/pxl-fac-m1-shutter-closed-patch-01-v02.png |
| B07-D03-v02 | PXL-FAC-M2-CLOSED-COVER-PATCH-01 | M2 v05，`147×86`；三口 `[15,30,56,51)`、`[62,30,79,51)`、`[84,30,131,51)` | source/batch07/pxl-fac-m2-closed-cover-patch-01-v02.png |

### 奶茶开门拼装合同 `B07-D01-v04`

```text
Base identity and architecture: PXL-FAC-MILKTEA-BASE-ALPHA-01 v03 only.
Work on the exact 192×128 logical canvas. Modify only [88,82,103,114); preserve the existing door frame and threshold from the base facade.

Fill the doorway with a restrained charcoal-gray interior. Draw one coarse warm-wood door leaf hinged on the left, with a slanted top and bottom edge, a single muted brick inset and one light handle cell. Keep logical columns 96..102 as a continuous dark entrance. Do not add a floor wedge, object, person, text, shadow, texture or new outer frame.

Scale only by nearest-neighbour to 1536×1024. Binary alpha, transparent RGB zero, strict 8×8 grid. This patch means only entrance open / currently enterable; it does not prove a customer entered, traffic increased, the shop is operating normally or a transaction occurred.
```

### M1 卷帘关闭拼装合同 `B07-D02-v02`

```text
Base identity and architecture: PXL-SHL-M1-EMPTY-01 v05 only.
Work on the exact 139×97 logical canvas. Cover only the actual opening [17,42,121,86); preserve columns, sign panel, lintel and threshold.

Use only six colors sampled from the M1 base: dark gray outline, gray-green frame, pale neutral shutter and low-frequency horizontal slats. No rust, dirt, stickers, warning tape, text, micro-detail or retro treatment.

Scale only by nearest-neighbour to 1112×776. Binary alpha, transparent RGB zero, strict 8×8 grid. This patch means entrance closed / currently non-operating; it cannot by itself prove permanent closure, bankruptcy or withdrawal.
```

### M2 三口封板拼装合同 `B07-D03-v02`

```text
Base identity and architecture: PXL-SHL-M2-EMPTY-01 v05 only.
Work on the exact 147×86 logical canvas. Cover only the three service openings [15,30,56,51), [62,30,79,51), and [84,30,131,51). Preserve canopy, pillars, counter, cabinet and outer silhouette.

Use five existing M2 colors for clean light panels, gray-green top seams and dark outlines. Keep the three covers as separate connected components. No tarp folds, renovation material, caution tape, text, grime, rust or extra object.

Scale only by nearest-neighbour to 1176×688. Binary alpha, transparent RGB zero, strict 8×8 grid. This patch means service openings closed / service stopped at this moment; an outer HTML or SVG label must distinguish a scheduled closed period, temporary pause and permanent exit.
```

### Batch 07 版本边界

- 奶茶 v01 范围过大、像黑色门亭，v02 像关闭单门，均为视觉失败稿；v03 已形成开门但右下暖棕楔仍有障碍物歧义，现由 v04 取代；
- M1／M2 v01 都覆盖了过多母版结构；当前只使用贴合真实开口的 v02；
- 三项当前版本均严格 8×8、二值 alpha、透明 RGB 清零，Patch 外母版逐像素不变；
- ImageGen 调用为 0，没有切换 CLI 或需要 API Key 的路径；
- 当前联系表为 `contact-sheets/contact-sheet-batch07-v04.png`，三项只到内部 QA 后待用户目检，未接入网页。

## 下一批候选｜等待 Batch 04–07 用户目检

本批到此停止扩批。下一步先看 Batch 04–07 的人物、行业门脸和三个状态 Patch 是否真的保持“清新明亮、不过细”，再决定是否组合现有顾客进店动作与门开状态，或补真正缺失的外部门前动作。只有现有 S1/M1/M2/L1/R1 与五类网页门脸确实覆盖不了目标镜头时，才单独补一个新门脸轮廓。仍不生产咖啡机、健身器材、库存、工位、座位或其他店内对象。
