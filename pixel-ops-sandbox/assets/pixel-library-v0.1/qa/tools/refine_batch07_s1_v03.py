from __future__ import annotations

import json
import shutil
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

from build_batch07_facade_patches import (
    ASSEMBLY,
    BASES,
    LIBRARY,
    QA,
    SHEETS,
    SOURCE,
    VIDEO,
    WEB,
    composite,
    connected_components,
    contain,
    font,
    sha256,
)


S1_STEM = "pxl-fac-milktea-door-open-patch-01-v03"


def draw_s1_v03() -> Image.Image:
    logical = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    interior = (61, 70, 70, 255)
    interior_deep = (47, 55, 56, 255)
    wood = (136, 114, 101, 255)
    brick = (194, 138, 121, 255)
    handle = (201, 172, 143, 255)

    # Exact closed-door core only. Existing facade frame and threshold remain.
    draw.rectangle((88, 82, 102, 113), fill=interior)
    draw.rectangle((96, 84, 102, 111), fill=interior_deep)

    # Left door leaf is visibly angled; the right seven logical columns remain
    # a continuous dark entrance so the state reads as open rather than dark glass.
    draw.polygon([(88, 82), (95, 85), (95, 110), (88, 113)], fill=interior_deep)
    draw.polygon([(89, 84), (93, 86), (93, 109), (89, 111)], fill=wood)
    draw.polygon([(90, 86), (92, 87), (92, 96), (90, 96)], fill=brick)
    draw.rectangle((94, 98, 94, 100), fill=handle)

    # One coarse floor cue inside the doorway, without adding objects or texture.
    draw.polygon([(94, 108), (102, 106), (102, 111), (94, 111)], fill=wood)
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def make_sheet(bases: dict[str, Image.Image], previews: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1900, 1500), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((62, 38), "Batch 07｜门脸状态差量拼装", fill=(47, 55, 56), font=font(40))
    draw.text((64, 92), "S1 开门 v03 · M1/M2 关闭 v02 · 不重画整店 · ImageGen 0 次", fill=(91, 105, 103), font=font(23))
    rows = [
        ("01 S1 奶茶｜关门基线", "开门 Patch v03｜门叶＋暗入口", "s1"),
        ("02 M1 商场沿边｜开口基线", "卷帘关闭 v02｜暂停营业", "m1"),
        ("03 M2 商场岛柜｜开放基线", "三口封板 v02｜闭店时段", "m2"),
    ]
    for index, (left_label, right_label, key) in enumerate(rows):
        y0 = 150 + index * 440
        for box, label, image in (
            ((60, y0, 920, y0 + 390), left_label, bases[key]),
            ((980, y0, 1840, y0 + 390), right_label, previews[key]),
        ):
            x0, by0, x1, by1 = box
            draw.rounded_rectangle(box, radius=20, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
            draw.text((x0 + 22, by0 + 16), label, fill=(47, 55, 56), font=font(25))
            placed, pos = contain(image, (x0 + 18, by0 + 56, x1 - 18, by1 - 18))
            canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


def main() -> None:
    source = SOURCE / f"{S1_STEM}.png"
    video = VIDEO / f"{S1_STEM}.png"
    web = WEB / f"{S1_STEM}.webp"
    preview = ASSEMBLY / f"preview-{S1_STEM}.png"
    sheet = SHEETS / "contact-sheet-batch07-v03.png"
    metrics_path = QA / "batch07-metrics-v03.json"
    for target in (source, video, web, preview, sheet, metrics_path):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")

    s1_patch = draw_s1_v03()
    s1_patch.save(source, optimize=True)
    shutil.copy2(source, video)
    s1_patch.resize((768, 512), Image.Resampling.NEAREST).save(web, "WEBP", lossless=True, method=6)

    bases = {key: Image.open(path).convert("RGBA") for key, path in BASES.items()}
    m1_patch = Image.open(SOURCE / "pxl-fac-m1-shutter-closed-patch-01-v02.png").convert("RGBA")
    m2_patch = Image.open(SOURCE / "pxl-fac-m2-closed-cover-patch-01-v02.png").convert("RGBA")
    previews = {
        "s1": composite(bases["s1"], s1_patch),
        "m1": composite(bases["m1"], m1_patch),
        "m2": composite(bases["m2"], m2_patch),
    }
    previews["s1"].save(preview, optimize=True)
    make_sheet(bases, previews, sheet)

    logical = s1_patch.resize((192, 128), Image.Resampling.NEAREST)
    rebuilt = logical.resize((1536, 1024), Image.Resampling.NEAREST)
    colors = Counter(logical.getdata())
    alpha = s1_patch.getchannel("A")
    previous = json.loads((QA / "batch07-metrics-v02.json").read_text(encoding="utf-8"))
    current_s1 = {
        "asset_id": "PXL-FAC-MILKTEA-DOOR-OPEN-PATCH-01",
        "version": "v03",
        "source_base": str(BASES["s1"].relative_to(LIBRARY)).replace("\\", "/"),
        "source_base_sha256": sha256(BASES["s1"]),
        "path": str(source.relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(s1_patch.size),
        "logical_size": list(logical.size),
        "sha256": sha256(source),
        "web_size": list(Image.open(web).size),
        "web_sha256": sha256(web),
        "video_sha256": sha256(video),
        "eight_by_eight_exact": list(s1_patch.getdata()) == list(rebuilt.getdata()),
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colors": len({color[:3] for color in colors if color[3] == 255}),
        "rgba_colors": len(colors),
        "transparent_rgb_nonzero": sum(1 for r, g, b, a in s1_patch.getdata() if a == 0 and (r or g or b)),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "connected_components": connected_components(logical),
        "preview_path": str(preview.relative_to(LIBRARY)).replace("\\", "/"),
        "preview_sha256": sha256(preview),
    }
    payload = {
        "imagegen_calls": 0,
        "rejected_versions": {
            "s1": ["v01", "v02"],
            "m1": ["v01"],
            "m2": ["v01"],
        },
        "current_versions": {"s1": "v03", "m1": "v02", "m2": "v02"},
        "contact_sheet": str(sheet.relative_to(LIBRARY)).replace("\\", "/"),
        "contact_sheet_sha256": sha256(sheet),
        "assets": [current_s1, previous["assets"][1], previous["assets"][2]],
    }
    metrics_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
