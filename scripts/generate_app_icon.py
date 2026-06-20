#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_PYTHON = ROOT / ".tools" / "python"
if LOCAL_PYTHON.exists():
    sys.path.insert(0, str(LOCAL_PYTHON))

try:
    from PIL import Image, ImageDraw
except Exception as exc:
    raise SystemExit(f"Pillow is required to generate the app icon: {exc}")


RESOURCE_DIR = ROOT / "Sources" / "DictationCoachApp" / "Resources"
ICONSET_DIR = ROOT / "build" / "AppIcon.iconset"
ICNS_PATH = RESOURCE_DIR / "AppIcon.icns"
BASE_ICON_PATH = ROOT / "build" / "AppIconBase.png"


def rounded_rect(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_icon(size: int) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (235, 239, 238, 255))
    draw = ImageDraw.Draw(image)

    def s(value: float) -> int:
        return max(1, int(round(value * scale)))

    # Soft app-tile shadow.
    for i, alpha in enumerate([34, 24, 16, 10]):
        offset = s(22 + i * 8)
        rounded_rect(
            draw,
            (s(116) + offset, s(118) + offset, s(908) + offset, s(906) + offset),
            s(194),
            (79, 61, 39, alpha),
        )

    # Warm paper tile.
    rounded_rect(
        draw,
        (s(108), s(104), s(916), s(912)),
        s(196),
        (253, 247, 226, 255),
        (218, 198, 145, 255),
        s(12),
    )

    # Paper grain and ruled notebook lines.
    for y in [272, 354, 436, 518, 600, 682, 764]:
        draw.line((s(188), s(y), s(836), s(y)), fill=(224, 211, 174, 145), width=s(5))
    draw.line((s(248), s(210), s(248), s(812)), fill=(205, 112, 96, 96), width=s(6))

    # Main sound button.
    rounded_rect(
        draw,
        (s(294), s(330), s(730), s(686)),
        s(92),
        (250, 253, 255, 255),
        (91, 124, 170, 255),
        s(12),
    )

    blue = (49, 100, 178, 255)
    speaker = [
        (s(390), s(470)),
        (s(466), s(470)),
        (s(556), s(392)),
        (s(556), s(624)),
        (s(466), s(546)),
        (s(390), s(546)),
    ]
    draw.polygon(speaker, fill=blue)

    cx, cy = s(570), s(508)
    for radius, width in [(88, 10), (136, 10)]:
        box = (cx - s(radius), cy - s(radius), cx + s(radius), cy + s(radius))
        draw.arc(box, start=-42, end=42, fill=blue, width=s(width))

    # Red pencil/check mark for wrong-book correction.
    red = (190, 74, 60, 255)
    draw.line((s(372), s(728), s(464), s(812), s(672), s(694)), fill=red, width=s(34), joint="curve")
    draw.line((s(674), s(692), s(744), s(650)), fill=(138, 97, 54, 255), width=s(18))

    # Small bookmark tab.
    draw.polygon(
        [(s(710), s(104)), (s(810), s(104)), (s(810), s(280)), (s(760), s(238)), (s(710), s(280))],
        fill=(122, 151, 105, 255),
    )

    return image


def main() -> None:
    RESOURCE_DIR.mkdir(parents=True, exist_ok=True)
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    icns_entries = {
        "icp4": 16,
        "icp5": 32,
        "icp6": 64,
        "ic07": 128,
        "ic08": 256,
        "ic09": 512,
        "ic10": 1024,
    }

    source = draw_icon(1024).convert("RGB")
    source.save(BASE_ICON_PATH)
    for filename, output_size in sizes.items():
        subprocess.run(
            [
                "sips",
                "-z",
                str(output_size),
                str(output_size),
                str(BASE_ICON_PATH),
                "--out",
                str(ICONSET_DIR / filename),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )

    chunks = []
    for icon_type, output_size in icns_entries.items():
        png_path = ICONSET_DIR / f"{icon_type}_{output_size}.png"
        subprocess.run(
            [
                "sips",
                "-z",
                str(output_size),
                str(output_size),
                str(BASE_ICON_PATH),
                "--out",
                str(png_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        payload = png_path.read_bytes()
        length = len(payload) + 8
        chunks.append(icon_type.encode("ascii") + length.to_bytes(4, "big") + payload)

    total_length = 8 + sum(len(chunk) for chunk in chunks)
    ICNS_PATH.write_bytes(b"icns" + total_length.to_bytes(4, "big") + b"".join(chunks))
    print(f"Generated {ICNS_PATH}")


if __name__ == "__main__":
    main()
