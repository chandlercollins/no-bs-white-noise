#!/usr/bin/env python3
"""
Compose App Store marketing screenshots (iPhone 6.9", 1320x2868) from raw
simulator captures.

Pipeline:
  1. Capture raw frames from the iPhone 17 Pro Max simulator into `raw/`
     using the DEBUG-only launch hook in ContentView (UITEST_* env vars).
     See APP_STORE_METADATA.md for the exact simctl commands.
  2. Run this script:  python3 Tools/make_screenshots.py
     Output lands in `Screenshots/6.9-inch/`.

Requires Pillow (`pip3 install pillow`). Uses the system SF Pro font.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "raw")                       # raw simulator captures
OUT = os.path.join(ROOT, "Screenshots", "6.9-inch")   # finished marketing shots
os.makedirs(OUT, exist_ok=True)

W, H = 1320, 2868
SFNS = "/System/Library/Fonts/SFNS.ttf"
HELV = "/System/Library/Fonts/Helvetica.ttc"

# Each entry: raw file, theme, headline (\n for line breaks), subtitle.
CONFIGS = [
    dict(src="main_light.png", theme="light",
         title="White noise\nthat just works", sub="Fast. Focused. No BS."),
    dict(src="menu_light.png", theme="light",
         title="Five clean sounds", sub="White · Brown · Fire · Rain · Birds"),
    dict(src="playing_dark.png", theme="dark",
         title="One tap.\nFocus for hours.", sub="Runs all night, sips battery"),
    dict(src="menu_dark_fire.png", theme="dark",
         title="Real Liquid Glass", sub="Designed for iOS 26"),
    dict(src="main_dark.png", theme="dark",
         title="No ads. No tracking.\nNo subscriptions.", sub="Just one fair price"),
]

LIGHT_BG = ((233, 240, 251), (247, 249, 252))
DARK_BG = ((22, 27, 42), (6, 8, 14))
LIGHT_TITLE, LIGHT_SUB = (11, 18, 32), (92, 104, 128)
DARK_TITLE, DARK_SUB = (255, 255, 255), (150, 162, 186)

SHOT_W = 1004
SHOT_H = int(SHOT_W * H / W)
SHOT_X = (W - SHOT_W) // 2
SHOT_Y = 690
RADIUS = 88


def load_font(size, weight="Bold"):
    try:
        f = ImageFont.truetype(SFNS, size)
        try:
            f.set_variation_by_name(weight)
        except Exception:
            pass
        return f
    except Exception:
        return ImageFont.truetype(HELV, size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(top, bottom):
    g = Image.new("RGB", (W, H), top)
    px = g.load()
    for y in range(H):
        c = lerp(top, bottom, y / (H - 1))
        for x in range(W):
            px[x, y] = c
    return g


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return m


def draw_center(draw, cx, y, text, font, fill, line_gap=1.1):
    ascent, descent = font.getmetrics()
    lh = int((ascent + descent) * line_gap)
    for line in text.split("\n"):
        w = draw.textlength(line, font=font)
        draw.text((cx - w / 2, y), line, font=font, fill=fill)
        y += lh
    return y


def main():
    title_font = load_font(112, "Bold")
    sub_font = load_font(46, "Medium")

    for i, cfg in enumerate(CONFIGS, 1):
        theme = cfg["theme"]
        src_path = os.path.join(SRC, cfg["src"])
        if not os.path.exists(src_path):
            print("SKIP (missing raw):", src_path)
            continue

        bg = gradient(*(LIGHT_BG if theme == "light" else DARK_BG))
        draw = ImageDraw.Draw(bg)
        title_fill = LIGHT_TITLE if theme == "light" else DARK_TITLE
        sub_fill = LIGHT_SUB if theme == "light" else DARK_SUB

        y = draw_center(draw, W / 2, 168, cfg["title"], title_font, title_fill, 1.08)
        draw_center(draw, W / 2, y + 22, cfg["sub"], sub_font, sub_fill, 1.1)

        shot = Image.open(src_path).convert("RGB").resize((SHOT_W, SHOT_H), Image.LANCZOS)
        mask = rounded_mask((SHOT_W, SHOT_H), RADIUS)

        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [SHOT_X, SHOT_Y + 26, SHOT_X + SHOT_W, SHOT_Y + SHOT_H + 26],
            radius=RADIUS, fill=(0, 0, 0, 150 if theme == "dark" else 60))
        shadow = shadow.filter(ImageFilter.GaussianBlur(40))
        bg = Image.alpha_composite(bg.convert("RGBA"), shadow).convert("RGB")

        bg.paste(shot, (SHOT_X, SHOT_Y), mask)
        ImageDraw.Draw(bg).rounded_rectangle(
            [SHOT_X, SHOT_Y, SHOT_X + SHOT_W, SHOT_Y + SHOT_H], radius=RADIUS,
            outline=(255, 255, 255) if theme == "dark" else (0, 0, 0), width=2)

        out = os.path.join(OUT, f"{i:02d}_{cfg['src'].replace('.png', '')}.png")
        bg.save(out, "PNG")
        print("wrote", out)


if __name__ == "__main__":
    main()
