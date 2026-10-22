from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VAULT = Path(r"C:\Users\ASUS\Desktop\总")
LIBRARY = VAULT / "30_输出" / "作品" / "像素经营沙盘_Web原型-2026-08-05" / "assets" / "pixel-library-v0.1"
CURRENT_WEB = VAULT / "30_输出" / "作品" / "ThinkPair_Web_Codex_独立重跑-2026-08-05" / "web" / "public" / "assets" / "thinkpair" / "storefronts-v4"

SOURCE = LIBRARY / "source" / "batch06"
RAW = SOURCE / "raw"
WEB = LIBRARY / "web" / "batch06"
VIDEO = LIBRARY / "video" / "batch06"
SHEETS = LIBRARY / "contact-sheets"
QA = LIBRARY / "qa"

ASSETS = {
    "milktea": "pxl-fac-milktea-base-alpha-01",
    "flower": "pxl-fac-flower-base-alpha-01",
    "gym": "pxl-fac-gym-base-alpha-01",
    "beauty": "pxl-fac-beauty-base-alpha-01",
}

OUTPUT_VERSION = "v03"
SHEET_REVISION = "v02"

# Shared low-saturation fresh palette. The exact source architecture is retained;
# only color count and logical pixel density are constrained.
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


def safe_copy(source: Path, target: Path) -> None:
    if target.exists():
        if sha256(source) != sha256(target):
            raise FileExistsError(f"Refusing to overwrite different file: {target}")
        return
    shutil.copy2(source, target)


def nearest_palette(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    r, g, b = rgb
    return min(
        PALETTE,
        key=lambda c: (r - c[0]) ** 2 + (g - c[1]) ** 2 + (b - c[2]) ** 2,
    )


def fit_to_logical(source: Image.Image) -> Image.Image:
    """Fit the complete source canvas into a 192x128 logical canvas."""
    logical = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    scale = min(192 / source.width, 128 / source.height)
    size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    reduced = source.resize(size, Image.Resampling.NEAREST)
    x = (192 - size[0]) // 2
    y = (128 - size[1]) // 2
    logical.alpha_composite(reduced, (x, y))
    return logical


def coarse_candidate(source: Image.Image) -> Image.Image:
    logical = fit_to_logical(source.convert("RGBA"))
    pixels = logical.load()
    mask = [[False for _ in range(logical.width)] for _ in range(logical.height)]

    for y in range(logical.height):
        for x in range(logical.width):
            r, g, b, a = pixels[x, y]
            if a < 56:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            mask[y][x] = True
            pr, pg, pb = nearest_palette((r, g, b))
            pixels[x, y] = (pr, pg, pb, 255)

    # One-logical-pixel silhouette outline keeps the facades readable beside NPCs.
    outline = PALETTE[0]
    for y in range(logical.height):
        for x in range(logical.width):
            if not mask[y][x]:
                continue
            neighbours = (
                x == 0 or not mask[y][x - 1],
                x == logical.width - 1 or not mask[y][x + 1],
                y == 0 or not mask[y - 1][x],
                y == logical.height - 1 or not mask[y + 1][x],
            )
            if any(neighbours):
                pixels[x, y] = (*outline, 255)

    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def freshen_candidate(candidate: Image.Image, key: str) -> Image.Image:
    """Lift large dark planes without changing geometry or adding detail."""
    logical = candidate.resize((192, 128), Image.Resampling.NEAREST)
    pixels = logical.load()
    mask = [[pixels[x, y][3] == 255 for x in range(logical.width)] for y in range(logical.height)]
    interior_shadow = {
        "milktea": (76, 110, 105),
        "flower": (82, 108, 101),
        "gym": (73, 105, 116),
        "beauty": (105, 101, 111),
    }[key]
    lift = {
        "milktea": (238, 242, 233),
        "flower": (241, 237, 226),
        "gym": (234, 240, 238),
        "beauty": (244, 235, 232),
    }[key]

    for y in range(logical.height):
        for x in range(logical.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            boundary = (
                x == 0 or not mask[y][x - 1]
                or x == logical.width - 1 or not mask[y][x + 1]
                or y == 0 or not mask[y - 1][x]
                or y == logical.height - 1 or not mask[y + 1][x]
            )
            if boundary:
                pixels[x, y] = (*PALETTE[0], 255)
                continue
            luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if luminance < 76:
                pixels[x, y] = (*interior_shadow, 255)
                continue
            amount = 0.12 if luminance < 150 else 0.06
            if r > g * 1.16 and r > b * 1.10 and luminance < 155:
                amount += 0.08
            pixels[x, y] = (
                round(r * (1 - amount) + lift[0] * amount),
                round(g * (1 - amount) + lift[1] * amount),
                round(b * (1 - amount) + lift[2] * amount),
                255,
            )
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def font(size: int) -> ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\msyh.ttc"),
        Path(r"C:\Windows\Fonts\simhei.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def contain(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int]]:
    x0, y0, x1, y1 = box
    max_w, max_h = x1 - x0, y1 - y0
    scale = min(max_w / image.width, max_h / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    return resized, (x0 + (max_w - size[0]) // 2, y0 + (max_h - size[1]) // 2)


def make_final_sheet(finals: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1800, 1280), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((70, 42), "Batch 06｜当前网页四类门脸的粗像素统一候选", fill=(47, 55, 56), font=font(38))
    draw.text((72, 94), "本地派生 · 192×128 逻辑画布 · 8×8 像素块 · ImageGen 0 次", fill=(91, 105, 103), font=font(22))
    labels = {
        "milktea": "01 奶茶门脸｜高频外带",
        "flower": "02 花店门脸｜外部陈列",
        "gym": "03 健身门脸｜宽入口",
        "beauty": "04 美业门脸｜预约私密",
    }
    boxes = [(70, 160, 870, 680), (930, 160, 1730, 680), (70, 720, 870, 1240), (930, 720, 1730, 1240)]
    for (key, image), box in zip(finals.items(), boxes):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=22, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
        draw.text((x0 + 24, y0 + 18), labels[key], fill=(47, 55, 56), font=font(26))
        placed, pos = contain(image, (x0 + 20, y0 + 62, x1 - 20, y1 - 20))
        canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


def make_comparison_sheet(raws: dict[str, Image.Image], finals: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1900, 1660), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((70, 38), "Batch 06｜v01 网页现用原版 vs v03 清新粗像素候选", fill=(47, 55, 56), font=font(38))
    draw.text((370, 102), "v01 当前网页原版（仅归档）", fill=(124, 89, 75), font=font(24))
    draw.text((1240, 102), "v03 统一候选（待目检）", fill=(73, 111, 102), font=font(24))
    labels = {"milktea": "奶茶", "flower": "花店", "gym": "健身", "beauty": "美业"}
    row_y = [150, 515, 880, 1245]
    for key, y0 in zip(ASSETS, row_y):
        draw.text((40, y0 + 135), labels[key], fill=(47, 55, 56), font=font(30))
        left_box = (130, y0, 930, y0 + 330)
        right_box = (970, y0, 1770, y0 + 330)
        for box in (left_box, right_box):
            draw.rounded_rectangle(box, radius=18, fill=(253, 252, 248), outline=(205, 211, 203), width=2)
        raw, raw_pos = contain(raws[key], (left_box[0] + 15, left_box[1] + 15, left_box[2] - 15, left_box[3] - 15))
        final, final_pos = contain(finals[key], (right_box[0] + 15, right_box[1] + 15, right_box[2] - 15, right_box[3] - 15))
        canvas.paste(raw.convert("RGB"), raw_pos, raw.getchannel("A"))
        canvas.paste(final.convert("RGB"), final_pos, final.getchannel("A"))
    canvas.save(target, optimize=True)


def image_metrics(path: Path) -> dict[str, object]:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    colors = image.getcolors(maxcolors=20_000_000)
    transparent_rgb_nonzero = 0
    for r, g, b, a in image.getdata():
        if a == 0 and (r or g or b):
            transparent_rgb_nonzero += 1
    return {
        "path": str(path.relative_to(LIBRARY)).replace("\\", "/"),
        "size": [image.width, image.height],
        "sha256": sha256(path),
        "alpha_extrema": list(alpha.getextrema()),
        "partial_alpha_pixels": sum(histogram[1:255]),
        "opaque_colors": len({color[:3] for _count, color in (colors or []) if len(color) == 4 and color[3] == 255}),
        "rgba_colors": len(colors or []),
        "transparent_rgb_nonzero": transparent_rgb_nonzero,
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
    }


def main() -> None:
    for directory in (SOURCE, RAW, WEB, VIDEO, SHEETS, QA):
        directory.mkdir(parents=True, exist_ok=True)

    raws: dict[str, Image.Image] = {}
    finals: dict[str, Image.Image] = {}
    metrics: list[dict[str, object]] = []

    for key, stem in ASSETS.items():
        current = CURRENT_WEB / f"{stem}-v01.png"
        raw = RAW / current.name
        final = SOURCE / f"{stem}-{OUTPUT_VERSION}.png"
        web = WEB / f"{stem}-{OUTPUT_VERSION}.webp"
        video = VIDEO / f"{stem}-{OUTPUT_VERSION}.png"

        safe_copy(current, raw)
        if final.exists() or web.exists() or video.exists():
            raise FileExistsError(f"Refusing to overwrite Batch 06 output for {stem}")

        original = Image.open(current).convert("RGBA")
        candidate = freshen_candidate(coarse_candidate(original), key)
        candidate.save(final, optimize=True)
        safe_copy(final, video)
        candidate.resize((768, 512), Image.Resampling.NEAREST).save(web, "WEBP", lossless=True, method=6)

        raws[key] = original
        finals[key] = candidate
        metrics.append(image_metrics(raw))
        metrics.append(image_metrics(final))
        metrics.append(image_metrics(web))
        metrics.append(image_metrics(video))

    final_sheet = SHEETS / f"contact-sheet-batch06-{SHEET_REVISION}.png"
    comparison_sheet = SHEETS / f"contact-sheet-batch06-style-comparison-{SHEET_REVISION}.png"
    if final_sheet.exists() or comparison_sheet.exists():
        raise FileExistsError("Refusing to overwrite Batch 06 contact sheet")
    make_final_sheet(finals, final_sheet)
    make_comparison_sheet(raws, finals, comparison_sheet)
    metrics.extend((image_metrics(final_sheet), image_metrics(comparison_sheet)))

    metrics_path = QA / f"batch06-metrics-{SHEET_REVISION}.json"
    if metrics_path.exists():
        raise FileExistsError(f"Refusing to overwrite {metrics_path}")
    metrics_path.write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
