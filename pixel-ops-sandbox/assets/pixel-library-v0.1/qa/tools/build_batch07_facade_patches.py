from __future__ import annotations

import hashlib
import json
import shutil
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VAULT = Path(r"C:\Users\ASUS\Desktop\总")
LIBRARY = VAULT / "30_输出" / "作品" / "像素经营沙盘_Web原型-2026-08-05" / "assets" / "pixel-library-v0.1"
SOURCE = LIBRARY / "source" / "batch07"
WEB = LIBRARY / "web" / "batch07"
VIDEO = LIBRARY / "video" / "batch07"
ASSEMBLY = LIBRARY / "assembly" / "batch07"
SHEETS = LIBRARY / "contact-sheets"
QA = LIBRARY / "qa"

BASES = {
    "s1": LIBRARY / "source" / "batch06" / "pxl-fac-milktea-base-alpha-01-v03.png",
    "m1": LIBRARY / "source" / "batch02" / "pxl-shl-m1-empty-01-v05.png",
    "m2": LIBRARY / "source" / "batch02" / "pxl-shl-m2-empty-01-v05.png",
}

ASSETS = {
    "s1": "pxl-fac-milktea-door-open-patch-01-v01",
    "m1": "pxl-fac-m1-shutter-closed-patch-01-v01",
    "m2": "pxl-fac-m2-closed-cover-patch-01-v01",
}


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


def draw_s1_door_patch() -> Image.Image:
    logical = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (47, 55, 56, 255)
    deep_green = (76, 110, 105, 255)
    soft_gray = (95, 104, 102, 255)
    wood = (136, 114, 101, 255)
    pale_wood = (201, 172, 143, 255)
    threshold = (216, 209, 196, 255)

    # Cover exactly the existing central door bay, then show a dark interior and
    # one door leaf opened toward the left. This patch is geometry-specific to
    # the current milk-tea facade and changes no other facade pixel.
    draw.rectangle((84, 77, 106, 116), fill=outline)
    draw.rectangle((87, 80, 103, 113), fill=soft_gray)
    draw.rectangle((89, 82, 102, 112), fill=outline)
    draw.rectangle((91, 84, 102, 111), fill=(61, 70, 70, 255))
    draw.rectangle((93, 86, 100, 109), fill=deep_green)

    # Angled open leaf; deliberately broad and low-detail at the 8 px grid.
    draw.polygon([(84, 78), (91, 82), (91, 111), (84, 115)], fill=outline)
    draw.polygon([(86, 81), (89, 83), (89, 108), (86, 111)], fill=wood)
    draw.polygon([(87, 84), (89, 85), (89, 96), (87, 96)], fill=deep_green)
    draw.point((89, 99), fill=pale_wood)

    draw.rectangle((84, 114, 106, 116), fill=outline)
    draw.rectangle((86, 114, 104, 115), fill=threshold)
    return logical.resize((1536, 1024), Image.Resampling.NEAREST)


def draw_m1_shutter_patch() -> Image.Image:
    logical = Image.new("RGBA", (139, 97), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (45, 54, 57, 255)
    deep = (79, 94, 99, 255)
    mid = (111, 128, 132, 255)
    light = (190, 190, 181, 255)
    highlight = (214, 213, 202, 255)

    # One wide rolling shutter closes the complete mall-edge storefront opening.
    draw.rectangle((13, 35, 125, 88), fill=outline)
    draw.rectangle((16, 38, 122, 85), fill=deep)
    draw.rectangle((18, 40, 120, 83), fill=light)
    for y in range(42, 83, 4):
        draw.rectangle((18, y, 120, y), fill=mid)
        if y + 1 <= 83:
            draw.rectangle((18, y + 1, 120, y + 1), fill=highlight)
    draw.rectangle((15, 35, 123, 38), fill=outline)
    draw.rectangle((18, 36, 120, 37), fill=mid)
    draw.rectangle((15, 84, 123, 88), fill=outline)
    draw.rectangle((18, 84, 120, 85), fill=mid)
    return logical.resize((1112, 776), Image.Resampling.NEAREST)


def draw_m2_cover_patch() -> Image.Image:
    logical = Image.new("RGBA", (147, 86), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logical)
    outline = (45, 54, 57, 255)
    sage = (55, 75, 62, 255)
    seam = (94, 68, 52, 255)
    light = (234, 232, 222, 255)
    mid = (214, 213, 202, 255)

    # Three quiet, industry-neutral closure panels: enough to read as a closed
    # kiosk without becoming construction hoarding or an indoor equipment scene.
    draw.rectangle((8, 20, 138, 56), fill=outline)
    draw.rectangle((11, 23, 135, 53), fill=mid)
    draw.rectangle((12, 24, 48, 52), fill=light)
    draw.rectangle((51, 24, 95, 52), fill=mid)
    draw.rectangle((98, 24, 134, 52), fill=light)
    draw.rectangle((48, 23, 51, 53), fill=seam)
    draw.rectangle((95, 23, 98, 53), fill=seam)
    draw.rectangle((10, 20, 136, 23), fill=outline)
    draw.rectangle((12, 21, 134, 22), fill=sage)
    draw.rectangle((10, 52, 136, 56), fill=outline)
    draw.rectangle((12, 52, 134, 53), fill=sage)
    draw.rectangle((72, 50, 75, 53), fill=outline)
    return logical.resize((1176, 688), Image.Resampling.NEAREST)


def contain(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int]]:
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / image.width, (y1 - y0) / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    return resized, (x0 + (x1 - x0 - size[0]) // 2, y0 + (y1 - y0 - size[1]) // 2)


def composite(base: Image.Image, patch: Image.Image) -> Image.Image:
    result = base.convert("RGBA").copy()
    result.alpha_composite(patch.convert("RGBA"))
    return result


def save_patch(key: str, patch: Image.Image) -> dict[str, Path]:
    stem = ASSETS[key]
    source_path = SOURCE / f"{stem}.png"
    video_path = VIDEO / f"{stem}.png"
    web_path = WEB / f"{stem}.webp"
    for target in (source_path, video_path, web_path):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")
    patch.save(source_path, optimize=True)
    shutil.copy2(source_path, video_path)
    if key == "s1":
        web_image = patch.resize((768, 512), Image.Resampling.NEAREST)
    else:
        web_image = patch
    web_image.save(web_path, "WEBP", lossless=True, method=6)
    return {"source": source_path, "video": video_path, "web": web_path}


def make_contact_sheet(bases: dict[str, Image.Image], previews: dict[str, Image.Image], target: Path) -> None:
    canvas = Image.new("RGB", (1900, 1500), (244, 242, 235))
    draw = ImageDraw.Draw(canvas)
    draw.text((62, 38), "Batch 07｜门脸状态差量拼装", fill=(47, 55, 56), font=font(40))
    draw.text((64, 92), "只增加开门／闭店对象 · 不重画整店 · ImageGen 0 次", fill=(91, 105, 103), font=font(23))
    rows = [
        ("01 S1 奶茶｜关门基线", "开门 Patch｜进店可达", "s1"),
        ("02 M1 商场沿边｜开口基线", "卷帘关闭｜暂停营业", "m1"),
        ("03 M2 商场岛柜｜开放基线", "封闭板关闭｜闭店时段", "m2"),
    ]
    for index, (left_label, right_label, key) in enumerate(rows):
        y0 = 150 + index * 440
        left_box = (60, y0, 920, y0 + 390)
        right_box = (980, y0, 1840, y0 + 390)
        for box, label, image in (
            (left_box, left_label, bases[key]),
            (right_box, right_label, previews[key]),
        ):
            x0, by0, x1, by1 = box
            draw.rounded_rectangle(box, radius=20, fill=(253, 252, 248), outline=(205, 211, 203), width=3)
            draw.text((x0 + 22, by0 + 16), label, fill=(47, 55, 56), font=font(25))
            placed, pos = contain(image, (x0 + 18, by0 + 56, x1 - 18, by1 - 18))
            canvas.paste(placed.convert("RGB"), pos, placed.getchannel("A"))
    canvas.save(target, optimize=True)


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


def metrics_for(key: str, patch: Image.Image, files: dict[str, Path], preview_path: Path) -> dict[str, object]:
    logical_size = (patch.width // 8, patch.height // 8)
    logical = patch.resize(logical_size, Image.Resampling.NEAREST)
    rebuilt = logical.resize(patch.size, Image.Resampling.NEAREST)
    colors = Counter(logical.getdata())
    alpha = patch.getchannel("A")
    return {
        "asset_id": ASSETS[key].rsplit("-v01", 1)[0].upper(),
        "source_base": str(BASES[key].relative_to(LIBRARY)).replace("\\", "/"),
        "source_base_sha256": sha256(BASES[key]),
        "path": str(files["source"].relative_to(LIBRARY)).replace("\\", "/"),
        "size": list(patch.size),
        "logical_size": list(logical_size),
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
        "preview_path": str(preview_path.relative_to(LIBRARY)).replace("\\", "/"),
        "preview_sha256": sha256(preview_path),
    }


def main() -> None:
    for directory in (SOURCE, WEB, VIDEO, ASSEMBLY, SHEETS, QA):
        directory.mkdir(parents=True, exist_ok=True)

    sheet = SHEETS / "contact-sheet-batch07-v01.png"
    metrics_path = QA / "batch07-metrics-v01.json"
    for target in (sheet, metrics_path):
        if target.exists():
            raise FileExistsError(f"Refusing to overwrite {target}")

    patches = {
        "s1": draw_s1_door_patch(),
        "m1": draw_m1_shutter_patch(),
        "m2": draw_m2_cover_patch(),
    }
    bases = {key: Image.open(path).convert("RGBA") for key, path in BASES.items()}
    previews = {key: composite(bases[key], patches[key]) for key in patches}

    files: dict[str, dict[str, Path]] = {}
    preview_paths: dict[str, Path] = {}
    for key, patch in patches.items():
        files[key] = save_patch(key, patch)
        preview_path = ASSEMBLY / f"preview-{ASSETS[key]}.png"
        if preview_path.exists():
            raise FileExistsError(f"Refusing to overwrite {preview_path}")
        previews[key].save(preview_path, optimize=True)
        preview_paths[key] = preview_path

    make_contact_sheet(bases, previews, sheet)
    metrics = {
        "imagegen_calls": 0,
        "contact_sheet": str(sheet.relative_to(LIBRARY)).replace("\\", "/"),
        "contact_sheet_sha256": sha256(sheet),
        "assets": [metrics_for(key, patches[key], files[key], preview_paths[key]) for key in ("s1", "m1", "m2")],
    }
    metrics_path.write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
