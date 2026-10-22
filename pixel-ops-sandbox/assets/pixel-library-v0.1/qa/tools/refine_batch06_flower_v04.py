from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VAULT = Path(r"C:\Users\ASUS\Desktop\总")
LIBRARY = VAULT / "30_输出" / "作品" / "像素经营沙盘_Web原型-2026-08-05" / "assets" / "pixel-library-v0.1"
SOURCE = LIBRARY / "source" / "batch06"
WEB = LIBRARY / "web" / "batch06"
VIDEO = LIBRARY / "video" / "batch06"
SHEETS = LIBRARY / "contact-sheets"
QA = LIBRARY / "qa"

STEM = "pxl-fac-flower-base-alpha-01"
SOURCE_V03 = SOURCE / f"{STEM}-v03.png"
SOURCE_V04 = SOURCE / f"{STEM}-v05.png"
WEB_V04 = WEB / f"{STEM}-v05.webp"
VIDEO_V04 = VIDEO / f"{STEM}-v05.png"

OTHER_FINALS = {
    "milktea": SOURCE / "pxl-fac-milktea-base-alpha-01-v03.png",
    "gym": SOURCE / "pxl-fac-gym-base-alpha-01-v03.png",
    "beauty": SOURCE / "pxl-fac-beauty-base-alpha-01-v03.png",
}

OUTLINE = (47, 55, 56, 255)
CREAM = (245, 242, 233, 255)
CREAM_SHADE = (215, 207, 194, 255)
GLASS = (134, 177, 174, 255)
GLASS_DARK = (82, 108, 106, 255)
GLASS_LIGHT = (188, 213, 220, 255)
WOOD = (154, 105, 88, 255)
WOOD_LIGHT = (199, 150, 126, 255)
CORAL = (190, 132, 126, 255)
GREEN = (100, 137, 91, 255)
GREEN_LIGHT = (144, 172, 126, 255)
YELLOW = (234, 207, 137, 255)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def font(size: int) -> ImageFont.ImageFont:
    for path in (Path(r"C:\Windows\Fonts\msyh.ttc"), Path(r"C:\Windows\Fonts\simhei.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def clear_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    draw.rectangle(box, fill=(0, 0, 0, 0))


def draw_window(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], flower_row: bool = False) -> None:
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=OUTLINE)
    draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=GLASS_DARK)
    draw.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), fill=GLASS)
    mid_x = (x0 + x1) // 2
    mid_y = (y0 + y1) // 2
    draw.rectangle((mid_x, y0 + 2, mid_x + 1, y1 - 2), fill=OUTLINE)
    draw.rectangle((x0 + 2, mid_y, x1 - 2, mid_y + 1), fill=OUTLINE)
    draw.line((x0 + 5, y0 + 5, x0 + 10, y0 + 3), fill=GLASS_LIGHT, width=1)
    if flower_row:
        baseline = y1 - 5
        draw.rectangle((x0 + 4, baseline, x1 - 4, baseline + 2), fill=WOOD)
        for offset, color in ((6, GREEN_LIGHT), (12, CORAL), (x1 - x0 - 12, YELLOW), (x1 - x0 - 7, GREEN)):
            draw.rectangle((x0 + offset, baseline - 3, x0 + offset + 2, baseline - 1), fill=color)


def draw_planter(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    draw.rectangle((x0, y0 + 3, x1, y1), fill=OUTLINE)
    draw.rectangle((x0 + 1, y0 + 4, x1 - 1, y1 - 1), fill=WOOD)
    draw.rectangle((x0 + 2, y0 + 1, x1 - 2, y0 + 3), fill=GREEN)
    draw.rectangle((x0 + 4, y0, x0 + 6, y0 + 2), fill=GREEN_LIGHT)
    draw.rectangle((x1 - 6, y0, x1 - 4, y0 + 2), fill=CORAL)


def refine_flower() -> Image.Image:
    logical = Image.open(SOURCE_V03).convert("RGBA").resize((192, 128), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(logical)

    # Remove the dense irregular side foliage and bottom pot clusters.
    clear_rect(draw, (31, 78, 43, 123))
    clear_rect(draw, (149, 78, 161, 123))

    # Redraw the ground floor as three calm modules, keeping the original facade positions.
    draw.rectangle((42, 77, 150, 121), fill=OUTLINE)
    draw.rectangle((45, 80, 147, 118), fill=CREAM_SHADE)
    draw.rectangle((45, 80, 47, 118), fill=CORAL)
    draw.rectangle((145, 80, 147, 118), fill=CORAL)
    draw_window(draw, (48, 82, 84, 109), flower_row=True)
    draw_window(draw, (108, 82, 144, 109), flower_row=True)

    # Central door remains in the same opening, with one simple glass panel.
    draw.rectangle((86, 79, 106, 119), fill=OUTLINE)
    draw.rectangle((88, 81, 104, 117), fill=WOOD)
    draw.rectangle((91, 84, 101, 105), fill=GLASS)
    draw.rectangle((91, 108, 101, 115), fill=WOOD_LIGHT)
    draw.rectangle((101, 99, 102, 100), fill=YELLOW)

    # Keep only two small exterior planters as the flower-store recognition cue.
    draw_planter(draw, 49, 108, 66, 118)
    draw_planter(draw, 126, 108, 143, 118)
    draw.rectangle((42, 119, 150, 121), fill=OUTLINE)
    draw.rectangle((46, 119, 146, 120), fill=CREAM_SHADE)

    # Keep the v03 upper facade and awning so the local repair does not flatten the
    # whole building into a different illustration style.

    # Guarantee binary alpha and zero RGB in transparent pixels.
    pixels = logical.load()
    for y in range(logical.height):
        for x in range(logical.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (0, 0, 0, 0) if a == 0 else (r, g, b, 255)
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def contain(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int]]:
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / image.width, (y1 - y0) / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    return resized, (x0 + (x1 - x0 - size[0]) // 2, y0 + (y1 - y0 - size[1]) // 2)


def make_sheet(finals: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1800, 1280), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((70, 42), "Batch 06｜当前网页四类门脸的粗像素统一候选", fill=(47, 55, 56), font=font(38))
    draw.text((72, 94), "花店 v05 局部简化 · 其余 v03 · 8×8 像素块 · ImageGen 0 次", fill=(91, 105, 103), font=font(22))
    labels = {
        "milktea": "01 奶茶门脸 v03｜高频外带",
        "flower": "02 花店门脸 v05｜清爽陈列",
        "gym": "03 健身门脸 v03｜宽入口",
        "beauty": "04 美业门脸 v03｜预约私密",
    }
    boxes = [(70, 160, 870, 680), (930, 160, 1730, 680), (70, 720, 870, 1240), (930, 720, 1730, 1240)]
    for (key, image), box in zip(finals.items(), boxes):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=22, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
        draw.text((x0 + 24, y0 + 18), labels[key], fill=(47, 55, 56), font=font(26))
        placed, pos = contain(image, (x0 + 20, y0 + 62, x1 - 20, y1 - 20))
        canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


def make_comparison(original: Image.Image, old: Image.Image, current: Image.Image, target: Path) -> None:
    canvas = Image.new("RGB", (1900, 760), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((60, 36), "Batch 06｜花店局部返修对照", fill=(47, 55, 56), font=font(38))
    labels = ["v01 网页原版", "v03 粗化但仍拥挤", "v05 只简化一层"]
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
    for target in (SOURCE_V04, WEB_V04, VIDEO_V04):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    flower = refine_flower()
    flower.save(SOURCE_V04, optimize=True)
    shutil.copy2(SOURCE_V04, VIDEO_V04)
    flower.resize((768, 512), Image.Resampling.NEAREST).save(WEB_V04, "WEBP", lossless=True, method=6)

    finals = {
        "milktea": Image.open(OTHER_FINALS["milktea"]).convert("RGBA"),
        "flower": flower,
        "gym": Image.open(OTHER_FINALS["gym"]).convert("RGBA"),
        "beauty": Image.open(OTHER_FINALS["beauty"]).convert("RGBA"),
    }
    sheet = SHEETS / "contact-sheet-batch06-v04.png"
    flower_compare = SHEETS / "contact-sheet-batch06-flower-refinement-v02.png"
    for target in (sheet, flower_compare):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    make_sheet(finals, sheet)
    make_comparison(
        Image.open(SOURCE / "raw" / f"{STEM}-v01.png").convert("RGBA"),
        Image.open(SOURCE_V03).convert("RGBA"),
        flower,
        flower_compare,
    )

    logical = flower.resize((192, 128), Image.Resampling.NEAREST)
    rebuilt = logical.resize((1536, 1024), Image.Resampling.NEAREST)
    alpha = flower.getchannel("A")
    colors = flower.getcolors(maxcolors=2_000_000) or []
    metrics = {
        "path": str(SOURCE_V04.relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(flower.size),
        "sha256": sha256(SOURCE_V04),
        "eight_by_eight_exact": list(flower.getdata()) == list(rebuilt.getdata()),
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colors": len({color[:3] for _count, color in colors if color[3] == 255}),
        "rgba_colors": len(colors),
        "transparent_rgb_nonzero": sum(1 for r, g, b, a in flower.getdata() if a == 0 and (r or g or b)),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "web_sha256": sha256(WEB_V04),
        "video_sha256": sha256(VIDEO_V04),
        "contact_sheet_sha256": sha256(sheet),
        "comparison_sheet_sha256": sha256(flower_compare),
    }
    target = QA / "batch06-flower-v05-metrics.json"
    if target.exists():
        raise FileExistsError(f"Refusing to overwrite {target}")
    target.write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
