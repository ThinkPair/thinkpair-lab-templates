from __future__ import annotations

import hashlib
import json
import shutil
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


VAULT = Path(r"C:\Users\ASUS\Desktop\总")
LIBRARY = VAULT / "30_输出" / "作品" / "像素经营沙盘_Web原型-2026-08-05" / "assets" / "pixel-library-v0.1"
SOURCE = LIBRARY / "source" / "batch06"
WEB = LIBRARY / "web" / "batch06"
VIDEO = LIBRARY / "video" / "batch06"
SHEETS = LIBRARY / "contact-sheets"
QA = LIBRARY / "qa"

STEM = "pxl-fac-flower-base-alpha-01"
INPUT = SOURCE / f"{STEM}-v06.png"
FINAL = SOURCE / f"{STEM}-v07.png"
WEB_FINAL = WEB / f"{STEM}-v07.webp"
VIDEO_FINAL = VIDEO / f"{STEM}-v07.png"
MAIN_SHEET = SHEETS / "contact-sheet-batch06-v06.png"
COMPARE_SHEET = SHEETS / "contact-sheet-batch06-flower-refinement-v04.png"
METRICS = QA / "batch06-flower-v07-metrics.json"

OUTLINE = (47, 55, 56)
SOFT_OUTLINE = (61, 70, 70)
PALE_WOOD = (199, 168, 137)
SAGE = (144, 172, 126)
DEEP_SAGE = (100, 137, 91)
PURPLES = {(169, 153, 177), (127, 112, 143)}


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


def contain(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int]]:
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / image.width, (y1 - y0) / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    return resized, (x0 + (x1 - x0 - size[0]) // 2, y0 + (y1 - y0 - size[1]) // 2)


def soften_flower(source: Image.Image) -> Image.Image:
    logical = source.convert("RGBA").resize((192, 128), Image.Resampling.NEAREST)
    pixels = logical.load()
    mask = [[pixels[x, y][3] == 255 for x in range(logical.width)] for y in range(logical.height)]

    for y in range(logical.height):
        for x in range(logical.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue

            rgb = (r, g, b)
            is_boundary = (
                x == 0 or not mask[y][x - 1]
                or x == logical.width - 1 or not mask[y][x + 1]
                or y == 0 or not mask[y - 1][x]
                or y == logical.height - 1 or not mask[y + 1][x]
            )
            if rgb == OUTLINE and not is_boundary:
                rgb = SOFT_OUTLINE
            elif rgb in {(202, 169, 91), (234, 207, 137)}:
                rgb = PALE_WOOD
            elif y < 80 and rgb in PURPLES:
                rgb = SAGE if rgb == (169, 153, 177) else DEEP_SAGE
            pixels[x, y] = (*rgb, 255)

    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def make_main_sheet(finals: dict[str, Image.Image]) -> None:
    canvas = Image.new("RGB", (1800, 1280), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((70, 42), "Batch 06｜四类行业门脸粗像素候选", fill=(47, 55, 56), font=font(38))
    draw.text((72, 94), "花店 v07 统一线色 · 其余 v03 · 8×8 像素块", fill=(91, 105, 103), font=font(22))
    labels = {
        "milktea": "01 奶茶 v03｜高频外带",
        "flower": "02 花店 v07｜清新陈列",
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
    canvas.save(MAIN_SHEET, optimize=True)


def make_comparison(old: Image.Image, current: Image.Image) -> None:
    canvas = Image.new("RGB", (1280, 760), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((60, 36), "Batch 06｜花店线色微调对照", fill=(47, 55, 56), font=font(38))
    labels = ["v06 定向修正", "v07 统一线色候选"]
    boxes = [(50, 130, 610, 710), (670, 130, 1230, 710)]
    for label, image, box in zip(labels, (old, current), boxes):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=20, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
        draw.text((x0 + 20, y0 + 16), label, fill=(47, 55, 56), font=font(24))
        placed, pos = contain(image, (x0 + 18, y0 + 58, x1 - 18, y1 - 18))
        canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(COMPARE_SHEET, optimize=True)


def connected_components(logical: Image.Image) -> int:
    alpha = logical.getchannel("A")
    mask = [[alpha.getpixel((x, y)) == 255 for x in range(logical.width)] for y in range(logical.height)]
    seen: set[tuple[int, int]] = set()
    components = 0
    for y in range(logical.height):
        for x in range(logical.width):
            if not mask[y][x] or (x, y) in seen:
                continue
            components += 1
            queue = deque([(x, y)])
            seen.add((x, y))
            while queue:
                cx, cy = queue.popleft()
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < logical.width and 0 <= ny < logical.height and mask[ny][nx] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
    return components


def main() -> None:
    for target in (FINAL, WEB_FINAL, VIDEO_FINAL, MAIN_SHEET, COMPARE_SHEET, METRICS):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")

    old = Image.open(INPUT).convert("RGBA")
    current = soften_flower(old)
    current.save(FINAL, optimize=True)
    shutil.copy2(FINAL, VIDEO_FINAL)
    current.resize((768, 512), Image.Resampling.NEAREST).save(WEB_FINAL, "WEBP", lossless=True, method=6)

    finals = {
        "milktea": Image.open(SOURCE / "pxl-fac-milktea-base-alpha-01-v03.png").convert("RGBA"),
        "flower": current,
        "gym": Image.open(SOURCE / "pxl-fac-gym-base-alpha-01-v03.png").convert("RGBA"),
        "beauty": Image.open(SOURCE / "pxl-fac-beauty-base-alpha-01-v03.png").convert("RGBA"),
    }
    make_main_sheet(finals)
    make_comparison(old, current)

    logical = current.resize((192, 128), Image.Resampling.NEAREST)
    rebuilt = logical.resize((1536, 1024), Image.Resampling.NEAREST)
    alpha = current.getchannel("A")
    logical_colors = Counter(logical.getdata())
    opaque_pixels = sum(count for color, count in logical_colors.items() if color[3] == 255)
    exact_outline = logical_colors.get((*OUTLINE, 255), 0)
    mean_brightness = sum(ImageStat.Stat(logical.convert("RGB"), mask=logical.getchannel("A")).mean) / (3 * 255)
    metrics = {
        "input_path": str(INPUT.relative_to(LIBRARY)).replace("\\", "/"),
        "input_sha256": sha256(INPUT),
        "path": str(FINAL.relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(current.size),
        "sha256": sha256(FINAL),
        "eight_by_eight_exact": list(current.getdata()) == list(rebuilt.getdata()),
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colors": len({color[:3] for color in logical_colors if color[3] == 255}),
        "rgba_colors": len(logical_colors),
        "transparent_rgb_nonzero": sum(1 for r, g, b, a in current.getdata() if a == 0 and (r or g or b)),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "connected_components": connected_components(logical),
        "exact_outline_pixels": exact_outline,
        "exact_outline_share_of_opaque": round(exact_outline / opaque_pixels, 6),
        "mean_brightness": round(mean_brightness, 6),
        "web_sha256": sha256(WEB_FINAL),
        "video_sha256": sha256(VIDEO_FINAL),
        "contact_sheet_sha256": sha256(MAIN_SHEET),
        "comparison_sheet_sha256": sha256(COMPARE_SHEET),
    }
    METRICS.write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
