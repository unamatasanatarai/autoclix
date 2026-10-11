#!/usr/bin/env python3
"""
Generates a retina-resolution custom DMG installer background image
for Autoclix featuring a sleek obsidian gradient, watermark logo,
and directional installation arrows.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

def get_font(size, bold=False):
    font_paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf"
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size, index=1 if bold else 0)
            except Exception:
                try:
                    return ImageFont.truetype(path, size)
                except Exception:
                    continue
    return ImageFont.load_default()

def draw_vector_arrow(draw, start_x, end_x, y, color=(255, 255, 255, 200), line_w=4, head_len=24):
    draw.line([(start_x, y), (end_x, y)], fill=color, width=line_w)
    wing_y = int(head_len * 0.75)
    pts = [
        (end_x - head_len, y - wing_y),
        (end_x, y),
        (end_x - head_len, y + wing_y)
    ]
    draw.line([pts[0], pts[1]], fill=color, width=line_w)
    draw.line([pts[1], pts[2]], fill=color, width=line_w)

def generate_background():
    # 2x Retina: 660 x 420 points = 1320 x 840 pixels
    W, H = 1320, 840
    img = Image.new("RGBA", (W, H), (10, 10, 12, 255))
    draw = ImageDraw.Draw(img)

    # 1. Base Dark Obsidian Gradient
    for y in range(H):
        ny = y / float(H)
        r = int(12 + ny * 6)
        g = int(14 + ny * 8)
        b = int(18 + ny * 10)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # 2. Subtle ambient center glow
    ambient = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    amb_draw = ImageDraw.Draw(ambient)
    center_x, center_y = W // 2, int(H * 0.46)
    max_r = int(W * 0.5)
    for r in range(max_r, 0, -15):
        factor = 1.0 - (r / max_r)
        alpha = int(35 * (factor ** 2))
        amb_draw.ellipse(
            [center_x - r, center_y - int(r * 0.65), center_x + r, center_y + int(r * 0.65)],
            fill=(40, 50, 60, alpha)
        )
    ambient = ambient.filter(ImageFilter.GaussianBlur(40))
    img = Image.alpha_composite(img, ambient)

    # 3. Watermark Logo in center
    watermark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(watermark)
    
    wm_cx, wm_cy = center_x, center_y
    r_out, r_in = 190, 150
    w_stroke = 14
    wm_color = (255, 255, 255, 18)
    
    wdraw.ellipse([wm_cx - r_out, wm_cy - r_out, wm_cx + r_out, wm_cy + r_out], outline=wm_color, width=w_stroke)
    wdraw.ellipse([wm_cx - r_in, wm_cy - r_in, wm_cx + r_in, wm_cy + r_in], outline=wm_color, width=w_stroke)
    
    angles = [math.pi / 4.0, 3.0 * math.pi / 4.0, 5.0 * math.pi / 4.0, 7.0 * math.pi / 4.0]
    for a in angles:
        x1 = wm_cx + math.cos(a) * 80
        y1 = wm_cy - math.sin(a) * 80
        x2 = wm_cx + math.cos(a) * 240
        y2 = wm_cy - math.sin(a) * 240
        wdraw.line([(x1, y1), (x2, y2)], fill=wm_color, width=w_stroke)
        
    img = Image.alpha_composite(img, watermark)

    # 4. Drop Zones and directional arrow
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)

    left_x, icon_y = 320, 410
    right_x = 1000

    def draw_drop_pedestal(cx, cy):
        ped_rx, ped_ry = 135, 135
        odraw.ellipse([cx - ped_rx, cy - ped_ry, cx + ped_rx, cy + ped_ry], fill=(255, 255, 255, 6), outline=(255, 255, 255, 26), width=2)
        odraw.ellipse([cx - 105, cy - 105, cx + 105, cy + 105], outline=(255, 255, 255, 12), width=1)

    draw_drop_pedestal(left_x, icon_y)
    draw_drop_pedestal(right_x, icon_y)

    # Elegant connection line & arrow
    draw_vector_arrow(odraw, left_x + 160, right_x - 160, icon_y, color=(255, 255, 255, 140), line_w=4, head_len=26)

    # Header and Subtitle Typography
    title_font = get_font(42, bold=True)
    sub_font = get_font(24, bold=False)

    title_text = "Install AutoCliX"
    sub_text = "Drag AutoCliX to Applications to complete installation"

    title_box = odraw.textbbox((0, 0), title_text, font=title_font)
    title_w = title_box[2] - title_box[0]
    odraw.text(((W - title_w) // 2, 80), title_text, fill=(255, 255, 255, 240), font=title_font)

    sub_box = odraw.textbbox((0, 0), sub_text, font=sub_font)
    sub_w = sub_box[2] - sub_box[0]
    odraw.text(((W - sub_w) // 2, 140), sub_text, fill=(255, 255, 255, 130), font=sub_font)

    img = Image.alpha_composite(img, overlay)

    # Save 2x and 1x
    resources_dir = "Resources"
    os.makedirs(resources_dir, exist_ok=True)
    
    bg_2x_path = os.path.join(resources_dir, "dmg_background@2x.png")
    bg_1x_path = os.path.join(resources_dir, "dmg_background.png")
    
    img.save(bg_2x_path)
    img_1x = img.resize((W // 2, H // 2), Image.Resampling.LANCZOS)
    img_1x.save(bg_1x_path)
    print("✅ Created Resources/dmg_background.png and dmg_background@2x.png")

if __name__ == "__main__":
    generate_background()
