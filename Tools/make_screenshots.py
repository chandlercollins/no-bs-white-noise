#!/usr/bin/env python3
"""
Compose App Store marketing screenshots from raw simulator captures.

Devices:
  - iPhone 6.9"  (1320x2868)  raw frames in  raw/        -> Screenshots/6.9-inch/
  - iPad 13"     (2064x2752)  raw frames in  raw/ipad/   -> Screenshots/13-inch/

Pipeline:
  1. Capture raw frames from the simulator into the raw dir using the
     DEBUG-only launch hook in ContentView (UITEST_* env vars) plus a 9:41
     status-bar override. See APP_STORE_METADATA.md for the exact commands.
  2. Run this script:  python3 Tools/make_screenshots.py

Requires Pillow (`pip3 install pillow`). Uses the system SF Pro font.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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

DEVICES = [
    dict(name="iPhone 6.9\"", canvas=(1320, 2868),
         raw_dir=os.path.join(ROOT, "raw"),
         out_dir=os.path.join(ROOT, "Screenshots", "6.9-inch"),
         shot_w=1004, shot_y=690, radius=88,
         title_size=112, sub_size=46, caption_y=168),
    dict(name="iPad 13\"", canvas=(2064, 2752),
         raw_dir=os.path.join(ROOT, "raw", "ipad"),
         out_dir=os.path.join(ROOT, "Screenshots", "13-inch"),
         shot_w=1280, shot_y=700, radius=72,
         title_size=132, sub_size=54, caption_y=150),
]

LIGHT_BG = ((233, 240, 251), (247, 249, 252))
DARK_BG = ((22, 27, 42), (6, 8, 14))
LIGHT_TITLE, LIGHT_SUB = (11, 18, 32), (92, 104, 128)
DARK_TITLE, DARK_SUB = (255, 255, 255), (150, 162, 186)


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


def gradient(size, top, bottom):
    w, h = size
    g = Image.new("RGB", size, top)
    px = g.load()
    for y in range(h):
        c = lerp(top, bottom, y / (h - 1))
        for x in range(w):
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


def compose(device):
    W, H = device["canvas"]
    os.makedirs(device["out_dir"], exist_ok=True)
    title_font = load_font(device["title_size"], "Bold")
    sub_font = load_font(device["sub_size"], "Medium")
    shot_w = device["shot_w"]
    shot_h = int(shot_w * H / W)
    shot_x = (W - shot_w) // 2
    shot_y = device["shot_y"]
    radius = device["radius"]

    for i, cfg in enumerate(CONFIGS, 1):
        src_path = os.path.join(device["raw_dir"], cfg["src"])
        if not os.path.exists(src_path):
            print("SKIP (missing raw):", src_path)
            continue
        theme = cfg["theme"]

        bg = gradient((W, H), *(LIGHT_BG if theme == "light" else DARK_BG))
        draw = ImageDraw.Draw(bg)
        title_fill = LIGHT_TITLE if theme == "light" else DARK_TITLE
        sub_fill = LIGHT_SUB if theme == "light" else DARK_SUB

        y = draw_center(draw, W / 2, device["caption_y"], cfg["title"], title_font, title_fill, 1.08)
        draw_center(draw, W / 2, y + 22, cfg["sub"], sub_font, sub_fill, 1.1)

        shot = Image.open(src_path).convert("RGB").resize((shot_w, shot_h), Image.LANCZOS)
        mask = rounded_mask((shot_w, shot_h), radius)

        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [shot_x, shot_y + 26, shot_x + shot_w, shot_y + shot_h + 26],
            radius=radius, fill=(0, 0, 0, 150 if theme == "dark" else 60))
        shadow = shadow.filter(ImageFilter.GaussianBlur(40))
        bg = Image.alpha_composite(bg.convert("RGBA"), shadow).convert("RGB")

        bg.paste(shot, (shot_x, shot_y), mask)
        ImageDraw.Draw(bg).rounded_rectangle(
            [shot_x, shot_y, shot_x + shot_w, shot_y + shot_h], radius=radius,
            outline=(255, 255, 255) if theme == "dark" else (0, 0, 0), width=2)

        out = os.path.join(device["out_dir"], f"{i:02d}_{cfg['src'].replace('.png', '')}.png")
        bg.save(out, "PNG")
        print("wrote", out, bg.size)


if __name__ == "__main__":
    for device in DEVICES:
        print(f"--- {device['name']} ---")
        compose(device)
