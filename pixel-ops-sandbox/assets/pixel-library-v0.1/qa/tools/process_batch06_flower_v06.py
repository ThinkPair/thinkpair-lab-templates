from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VAULT = Path(r"C:\Users\ASUS\Desktop\总")
LIBRARY = VAULT / "30_输出" / "作品" / "像素经营沙盘_Web原型-2026-08-05" / "assets" / "pixel-library-v0.1"
SOURCE = LIBRARY / "source" / "batch06"
RAW = SOURCE / "raw"
WEB = LIBRARY / "web" / "batch06"
VIDEO = LIBRARY / "video" / "batch06"
SHEETS = LIBRARY / "contact-sheets"
QA = LIBRARY / "qa"

STEM = "pxl-fac-flower-base-alpha-01"
CHROMA = RAW / f"{STEM}-v06-imagegen-chroma.png"
FINAL = SOURCE / f"{STEM}-v06.png"
WEB_FINAL = WEB / f"{STEM}-v06.webp"
VIDEO_FINAL = VIDEO / f"{STEM}-v06.png"

PALETTE = [
    (47, 55, 56), (61, 70, 70), (76, 85, 84),
    (245, 242, 233), (233, 228, 216), (215, 207, 194), (190, 181, 166),
    (111, 82, 68), (137, 101, 82), (169, 132, 105), (199, 168, 137),
    (183, 112, 93), (149, 82, 69),
    (174, 204, 190), (134, 177, 160), (88, 132, 119), (62, 96, 88),
    (188, 213, 220), (137, 177, 188), (91, 132, 145), (66, 96, 106),
    (220, 178, 170), (194, 132, 126), (160, 96, 91),
    (234, 207, 137), (202, 169, 91),
    (144, 172, 126), (100, 137, 91), (67, 99, 69),
    (169, 153, 177), (127, 112, 143),
    (232, 235, 229),
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def nearest_palette(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    r, g, b = rgb
    return min(PALETTE, key=lambda c: (r - c[0]) ** 2 + (g - c[1]) ** 2 + (b - c[2]) ** 2)


def remove_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _a = pixels[x, y]
            magenta = r > 170 and b > 150 and g < 115 and (r + b) / 2 - g > 85
            pixels[x, y] = (0, 0, 0, 0) if magenta else (r, g, b, 255)
    return rgba


def coarse_standard(image: Image.Image) -> Image.Image:
    alpha_bbox = image.getchannel("A").getbbox()
    if not alpha_bbox:
        raise ValueError("No foreground after chroma removal")
    crop = image.crop(alpha_bbox)
    scale = min(118 / crop.width, 118 / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    reduced = crop.resize(size, Image.Resampling.NEAREST)
    logical = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    logical.alpha_composite(reduced, ((192 - size[0]) // 2, (128 - size[1]) // 2))

    pixels = logical.load()
    mask = [[False for _ in range(logical.width)] for _ in range(logical.height)]
    for y in range(logical.height):
        for x in range(logical.width):
            r, g, b, a = pixels[x, y]
            if a < 128:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            mask[y][x] = True
            pixels[x, y] = (*nearest_palette((r, g, b)), 255)

    outline = PALETTE[0]
    for y in range(logical.height):
        for x in range(logical.width):
            if not mask[y][x]:
                continue
            if (
                x == 0 or not mask[y][x - 1]
                or x == logical.width - 1 or not mask[y][x + 1]
                or y == 0 or not mask[y - 1][x]
                or y == logical.height - 1 or not mask[y + 1][x]
            ):
                pixels[x, y] = (*outline, 255)
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def font(size: int) -> ImageFont.ImageFont:
    for path in (Path(r"C:\Windows\Fonts\msyh.ttc"), Path(r"C:\Windows\Fonts\simhei.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def contain(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int]]:
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / image.width, (y1 - y0) / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    return resized, (x0 + (x1 - x0 - size[0]) // 2, y0 + (y1 - y0 - size[1]) // 2)


def make_sheet(finals: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1800, 1280), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((70, 42), "Batch 06｜四类行业门脸粗像素候选", fill=(47, 55, 56), font=font(38))
    draw.text((72, 94), "花店 v06 定向修正 · 其余 v03 · 8×8 像素块", fill=(91, 105, 103), font=font(22))
    labels = {
        "milktea": "01 奶茶 v03｜高频外带",
        "flower": "02 花店 v06｜清新陈列",
        "gym": "03 健身 v03｜宽入口",
        "beauty": "04 美业 v03｜预约私密",
    }
    boxes = [(70, 160, 870, 680), (930, 160, 1730, 680), (70, 720, 870, 1240), (930, 720, 1730, 1240)]
    for (key, image), box in zip(finals.items(), boxes):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=22, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
        draw.text((x0 + 24, y0 + 18), labels[key], fill=(47, 55, 56), font=font(26))
        placed, pos = contain(image, (x0 + 20, y0 + 62, x1 - 20, y1 - 20))
        canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


def make_flower_comparison(original: Image.Image, old: Image.Image, current: Image.Image, target: Path) -> None:
    canvas = Image.new("RGB", (1900, 760), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((60, 36), "Batch 06｜花店最终返修对照", fill=(47, 55, 56), font=font(38))
    labels = ["v01 网页原版", "v03 粗化仍偏拥挤", "v06 定向修正候选"]
    images = [original, old, current]
    boxes = [(50, 130, 610, 710), (670, 130, 1230, 710), (1290, 130, 1850, 710)]
    for label, image, box in zip(labels, images, boxes):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=20, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
        draw.text((x0 + 20, y0 + 16), label, fill=(47, 55, 56), font=font(24))
        placed, pos = contain(image, (x0 + 18, y0 + 58, x1 - 18, y1 - 18))
        canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


def main() -> None:
    for target in (FINAL, WEB_FINAL, VIDEO_FINAL):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    flower = coarse_standard(remove_chroma(Image.open(CHROMA)))
    flower.save(FINAL, optimize=True)
    shutil.copy2(FINAL, VIDEO_FINAL)
    flower.resize((768, 512), Image.Resampling.NEAREST).save(WEB_FINAL, "WEBP", lossless=True, method=6)

    finals = {
        "milktea": Image.open(SOURCE / "pxl-fac-milktea-base-alpha-01-v03.png").convert("RGBA"),
        "flower": flower,
        "gym": Image.open(SOURCE / "pxl-fac-gym-base-alpha-01-v03.png").convert("RGBA"),
        "beauty": Image.open(SOURCE / "pxl-fac-beauty-base-alpha-01-v03.png").convert("RGBA"),
    }
    sheet = SHEETS / "contact-sheet-batch06-v05.png"
    comparison = SHEETS / "contact-sheet-batch06-flower-refinement-v03.png"
    for target in (sheet, comparison):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    make_sheet(finals, sheet)
    make_flower_comparison(
        Image.open(RAW / f"{STEM}-v01.png").convert("RGBA"),
        Image.open(SOURCE / f"{STEM}-v03.png").convert("RGBA"),
        flower,
        comparison,
    )

    logical = flower.resize((192, 128), Image.Resampling.NEAREST)
    rebuilt = logical.resize((1536, 1024), Image.Resampling.NEAREST)
    alpha = flower.getchannel("A")
    colors = flower.getcolors(maxcolors=2_000_000) or []
    metrics = {
        "raw_path": str(CHROMA.relative_to(LIBRARY)).replace("\\", "/"),
        "raw_sha256": sha256(CHROMA),
        "path": str(FINAL.relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(flower.size),
        "sha256": sha256(FINAL),
        "eight_by_eight_exact": list(flower.getdata()) == list(rebuilt.getdata()),
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colors": len({color[:3] for _count, color in colors if color[3] == 255}),
        "rgba_colors": len(colors),
        "transparent_rgb_nonzero": sum(1 for r, g, b, a in flower.getdata() if a == 0 and (r or g or b)),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "web_sha256": sha256(WEB_FINAL),
        "video_sha256": sha256(VIDEO_FINAL),
        "contact_sheet_sha256": sha256(sheet),
        "comparison_sheet_sha256": sha256(comparison),
    }
    target = QA / "batch06-flower-v06-metrics.json"
    if target.exists():
        raise FileExistsError(f"Refusing to overwrite {target}")
    target.write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
