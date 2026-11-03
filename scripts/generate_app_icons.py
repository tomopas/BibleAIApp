"""Generate Bible AI app icons for Web, PWA, Android, Windows, and Flutter UI.

Usage:
    python scripts/generate_app_icons.py
"""

from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent


def _lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(c1[0] + (c2[0] - c1[0]) * t),
        int(c1[1] + (c2[1] - c1[1]) * t),
        int(c1[2] + (c2[2] - c1[2]) * t),
    )


def render_master_icon(size: int = 1024, maskable: bool = False) -> Image.Image:
    """Render the Bible AI emblem (open parchment Bible + golden cross/star) at high resolution."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Create diagonal crimson-burgundy leather gradient background
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_px = bg.load()
    c_top = (140, 59, 46)    # #8C3B2E
    c_mid = (98, 37, 28)     # #62251C
    c_bot = (54, 19, 14)     # #36130E
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2.0 * size)
            if t < 0.55:
                rgb = _lerp_color(c_top, c_mid, t / 0.55)
            else:
                rgb = _lerp_color(c_mid, c_bot, (t - 0.55) / 0.45)
            bg_px[x, y] = (*rgb, 255)

    if maskable:
        img.paste(bg, (0, 0))
    else:
        mask = Image.new("L", (size, size), 0)
        mdraw = ImageDraw.Draw(mask)
        pad = int(size * 0.03)
        radius = int(size * 0.22)
        mdraw.rounded_rectangle([pad, pad, size - pad, size - pad], radius=radius, fill=255)
        img.paste(bg, (0, 0), mask)

    draw = ImageDraw.Draw(img, "RGBA")

    # Inner gold frame border
    frame_pad = int(size * (0.10 if maskable else 0.068))
    frame_rad = int(size * (0.16 if maskable else 0.185))
    draw.rounded_rectangle(
        [frame_pad, frame_pad, size - frame_pad, size - frame_pad],
        radius=frame_rad,
        outline=(212, 175, 55, 135),
        width=max(2, int(size * 0.01)),
    )

    scale = 0.82 if maskable else 1.0
    cx = size // 2
    cy = size // 2

    def sx(val: float) -> int:
        return int(cx + (val - 512) * (size / 1024.0) * scale)

    def sy(val: float) -> int:
        return int(cy + (val - 512) * (size / 1024.0) * scale)

    # Soft golden glow behind the star/cross
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    gx, gy = sx(512), sy(305)
    grad_r = int(size * 0.19 * scale)
    gdraw.ellipse([gx - grad_r, gy - grad_r, gx + grad_r, gy + grad_r], fill=(247, 223, 139, 55))
    grad_r2 = int(size * 0.11 * scale)
    gdraw.ellipse([gx - grad_r2, gy - grad_r2, gx + grad_r2, gy + grad_r2], fill=(247, 223, 139, 85))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(4, int(size * 0.025))))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img, "RGBA")

    # Golden 4-point Cross / Star of Light
    star_pts = [
        (sx(512), sy(132)),
        (sx(540), sy(264)),
        (sx(668), sy(292)),
        (sx(540), sy(320)),
        (sx(512), sy(452)),
        (sx(484), sy(320)),
        (sx(356), sy(292)),
        (sx(484), sy(264)),
    ]
    draw.polygon(star_pts, fill=(238, 198, 88, 255))
    ir = max(3, int(size * 0.018 * scale))
    draw.ellipse([sx(512) - ir, sy(292) - ir, sx(512) + ir, sy(292) + ir], fill=(255, 253, 245, 255))

    # Small side sparkles
    for sp_x, sp_y in [(700, 195), (324, 195)]:
        s_pts = [
            (sx(sp_x), sy(sp_y - 32)),
            (sx(sp_x + 9), sy(sp_y - 8)),
            (sx(sp_x + 32), sy(sp_y)),
            (sx(sp_x + 9), sy(sp_y + 8)),
            (sx(sp_x), sy(sp_y + 32)),
            (sx(sp_x - 9), sy(sp_y + 8)),
            (sx(sp_x - 32), sy(sp_y)),
            (sx(sp_x - 9), sy(sp_y - 8)),
        ]
        draw.polygon(s_pts, fill=(247, 223, 139, 225))

    # Open Bible Gold Cover Base
    cover_pts = [
        (sx(176), sy(478)),
        (sx(330), sy(448)),
        (sx(512), sy(496)),
        (sx(694), sy(448)),
        (sx(848), sy(478)),
        (sx(848), sy(812)),
        (sx(694), sy(782)),
        (sx(512), sy(832)),
        (sx(330), sy(782)),
        (sx(176), sy(812)),
    ]
    draw.polygon(cover_pts, fill=(212, 175, 55, 255))

    # Left Parchment Page
    left_page = [
        (sx(200), sy(450)),
        (sx(344), sy(420)),
        (sx(508), sy(474)),
        (sx(508), sy(790)),
        (sx(344), sy(742)),
        (sx(200), sy(772)),
    ]
    draw.polygon(left_page, fill=(250, 246, 238, 255))

    # Right Parchment Page
    right_page = [
        (sx(516), sy(474)),
        (sx(680), sy(420)),
        (sx(824), sy(450)),
        (sx(824), sy(772)),
        (sx(680), sy(742)),
        (sx(516), sy(790)),
    ]
    draw.polygon(right_page, fill=(244, 237, 223, 255))

    # Center spine crease
    lw = max(2, int(size * 0.008 * scale))
    draw.line([(sx(512), sy(472)), (sx(512), sy(794))], fill=(180, 155, 125, 255), width=lw)

    # Scripture text lines on left and right pages
    line_w = max(2, int(size * 0.011 * scale))
    for idx, y_off in enumerate([524, 582, 640, 696]):
        color = (140, 59, 46, 165) if idx == 0 else (110, 98, 92, 130)
        # Left page line
        draw.line([(sx(248), sy(y_off)), (sx(462), sy(y_off + 14))], fill=color, width=line_w)
        # Right page line
        draw.line([(sx(562), sy(y_off + 14)), (sx(776), sy(y_off))], fill=color, width=line_w)

    # Crimson ribbon bookmark at bottom spine
    ribbon = [
        (sx(494), sy(788)),
        (sx(530), sy(788)),
        (sx(530), sy(892)),
        (sx(512), sy(870)),
        (sx(494), sy(892)),
    ]
    draw.polygon(ribbon, fill=(197, 59, 39, 255))

    return img


def main() -> None:
    master = render_master_icon(1024, maskable=False)
    master_maskable = render_master_icon(1024, maskable=True)

    targets: list[tuple[Path, int, bool]] = [
        # App asset icon
        (ROOT / "assets" / "icon" / "app_icon.png", 512, False),
        # Backend Web App / PWA icons
        (ROOT / "backend" / "static" / "favicon.png", 64, False),
        (ROOT / "backend" / "static" / "icon-192.png", 192, False),
        (ROOT / "backend" / "static" / "icon-512.png", 512, False),
        (ROOT / "backend" / "static" / "icon-maskable-512.png", 512, True),
        # Flutter Web icons
        (ROOT / "web" / "favicon.png", 64, False),
        (ROOT / "web" / "icons" / "Icon-192.png", 192, False),
        (ROOT / "web" / "icons" / "Icon-512.png", 512, False),
        (ROOT / "web" / "icons" / "Icon-maskable-192.png", 192, True),
        (ROOT / "web" / "icons" / "Icon-maskable-512.png", 512, True),
        # Android launcher mipmaps
        (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi" / "ic_launcher.png", 48, False),
        (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi" / "ic_launcher.png", 72, False),
        (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi" / "ic_launcher.png", 96, False),
        (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi" / "ic_launcher.png", 144, False),
        (ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png", 192, False),
    ]

    for path, px, is_maskable in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        src = master_maskable if is_maskable else master
        out = src.resize((px, px), Image.Resampling.LANCZOS)
        out.save(path, format="PNG", optimize=True)
        print(f"Generated {path.relative_to(ROOT)} ({px}x{px})")

    # Windows multi-size .ico
    win_ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    if win_ico.parent.exists():
        ico_base = master.resize((256, 256), Image.Resampling.LANCZOS)
        ico_base.save(
            win_ico,
            format="ICO",
            sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )
        print(f"Generated {win_ico.relative_to(ROOT)} (multi-size ICO)")


if __name__ == "__main__":
    main()
