from __future__ import annotations

import hashlib
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
)


STEMS = {
    "s1": "pxl-fac-milktea-door-open-patch-01-v02",
    "m1": "pxl-fac-m1-shutter-closed-patch-01-v02",
    "m2": "pxl-fac-m2-closed-cover-patch-01-v02",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def draw_s1_v02() -> Image.Image:
    logical = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (47, 55, 56, 255)
    interior = (61, 70, 70, 255)
    deep_green = (76, 110, 105, 255)
    wood = (136, 114, 101, 255)
    pale_wood = (201, 172, 143, 255)

    # Only replace the door core. Existing frame and threshold remain visible.
    draw.rectangle((88, 80, 102, 112), fill=outline)
    draw.rectangle((90, 82, 100, 110), fill=interior)
    draw.rectangle((92, 84, 99, 108), fill=deep_green)

    # Narrow angled leaf opening to the left, contained inside the original bay.
    draw.polygon([(88, 81), (92, 84), (92, 108), (88, 111)], fill=outline)
    draw.polygon([(89, 83), (91, 85), (91, 106), (89, 108)], fill=wood)
    draw.point((91, 98), fill=pale_wood)
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def draw_m1_v02() -> Image.Image:
    logical = Image.new("RGBA", (139, 97), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (45, 54, 57, 255)
    deep = (56, 67, 72, 255)
    dark_gray_green = (79, 94, 99, 255)
    mid = (111, 128, 132, 255)
    light = (190, 190, 181, 255)
    highlight = (214, 213, 202, 255)

    # Geometry follows the actual M1 opening; no side column or sign overlap.
    draw.rectangle((17, 42, 120, 85), fill=outline)
    draw.rectangle((19, 45, 118, 83), fill=dark_gray_green)
    draw.rectangle((20, 46, 117, 82), fill=light)
    for y in range(48, 82, 4):
        draw.rectangle((20, y, 117, y), fill=mid)
        draw.rectangle((20, y + 1, 117, y + 1), fill=highlight)
    draw.rectangle((17, 42, 120, 45), fill=outline)
    draw.rectangle((20, 43, 117, 44), fill=deep)
    draw.rectangle((17, 83, 120, 85), fill=outline)
    draw.rectangle((20, 83, 117, 83), fill=deep)
    return logical.resize((1112, 776), Image.Resampling.NEAREST)


def draw_m2_v02() -> Image.Image:
    logical = Image.new("RGBA", (147, 86), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (45, 54, 57, 255)
    sage = (55, 75, 62, 255)
    seam = (190, 190, 181, 255)
    light = (234, 232, 222, 255)
    mid = (214, 213, 202, 255)

    # Close only the three real service openings. Canopy, pillars, counter and
    # outer silhouette remain untouched so the layer stays composable.
    panels = [
        ((15, 30, 55, 50), light),
        ((62, 30, 78, 50), mid),
        ((84, 30, 130, 50), light),
    ]
    for (x0, y0, x1, y1), fill in panels:
        draw.rectangle((x0, y0, x1, y1), fill=outline)
        draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=fill)
        draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y0 + 3), fill=sage)
        draw.rectangle((x0 + 2, y1 - 3, x1 - 2, y1 - 2), fill=seam)
    draw.rectangle((69, 47, 72, 50), fill=outline)
    return logical.resize((1176, 688), Image.Resampling.NEAREST)


def save_patch(key: str, patch: Image.Image) -> dict[str, Path]:
    stem = STEMS[key]
    paths = {
        "source": SOURCE / f"{stem}.png",
        "video": VIDEO / f"{stem}.png",
        "web": WEB / f"{stem}.webp",
    }
    for target in paths.values():
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    patch.save(paths["source"], optimize=True)
    shutil.copy2(paths["source"], paths["video"])
    web_image = patch.resize((768, 512), Image.Resampling.NEAREST) if key == "s1" else patch
    web_image.save(paths["web"], "WEBP", lossless=True, method=6)
    return paths


def make_sheet(bases: dict[str, Image.Image], previews: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1900, 1500), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((62, 38), "Batch 07｜门脸状态差量拼装 v02", fill=(47, 55, 56), font=font(40))
    draw.text((64, 92), "只覆盖真实门芯／门洞／服务口 · 不重画整店 · ImageGen 0 次", fill=(91, 105, 103), font=font(23))
    rows = [
        ("01 S1 奶茶｜关门基线", "开门 Patch v02｜进店可达", "s1"),
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


def asset_metrics(key: str, patch: Image.Image, files: dict[str, Path], preview: Path) -> dict[str, object]:
    logical = patch.resize((patch.width // 8, patch.height // 8), Image.Resampling.NEAREST)
    rebuilt = logical.resize(patch.size, Image.Resampling.NEAREST)
    colors = Counter(logical.getdata())
    alpha = patch.getchannel("A")
    return {
        "asset_id": STEMS[key].rsplit("-v02", 1)[0].upper(),
        "version": "v02",
        "source_base": str(BASES[key].relative_to(LIBRARY)).replace("\\", "/"),
        "source_base_sha256": sha256(BASES[key]),
        "path": str(files["source"].relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(patch.size),
        "logical_size": list(logical.size),
        "sha256": sha256(files["source"]),
        "web_size": list(Image.open(files["web"]).size),
        "web_sha256": sha256(files["web"]),
        "video_sha256": sha256(files["video"]),
        "eight_by_eight_exact": list(patch.getdata()) == list(rebuilt.getdata()),
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colors": len({color[:3] for color in colors if color[3] == 255}),
        "rgba_colors": len(colors),
        "transparent_rgb_nonzero": sum(1 for r, g, b, a in patch.getdata() if a == 0 and (r or g or b)),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "connected_components": connected_components(logical),
        "preview_path": str(preview.relative_to(LIBRARY)).replace("\\", "/"),
        "preview_sha256": sha256(preview),
    }


def main() -> None:
    sheet = SHEETS / "contact-sheet-batch07-v02.png"
    metrics_path = QA / "batch07-metrics-v02.json"
    for target in (sheet, metrics_path):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")

    patches = {"s1": draw_s1_v02(), "m1": draw_m1_v02(), "m2": draw_m2_v02()}
    bases = {key: Image.open(path).convert("RGBA") for key, path in BASES.items()}
    previews = {key: composite(bases[key], patches[key]) for key in patches}

    files: dict[str, dict[str, Path]] = {}
    preview_paths: dict[str, Path] = {}
    for key, patch in patches.items():
        files[key] = save_patch(key, patch)
        preview_path = ASSEMBLY / f"preview-{STEMS[key]}.png"
        if preview_path.exists():
            raise FileExistsError(f"Refusing to overwrite {preview_path}")
        previews[key].save(preview_path, optimize=True)
        preview_paths[key] = preview_path

    make_sheet(bases, previews, sheet)
    payload = {
        "imagegen_calls": 0,
        "v01_status": "rejected_intermediate_geometry",
        "contact_sheet": str(sheet.relative_to(LIBRARY)).replace("\\", "/"),
        "contact_sheet_sha256": sha256(sheet),
        "assets": [asset_metrics(key, patches[key], files[key], preview_paths[key]) for key in ("s1", "m1", "m2")],
    }
    metrics_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
