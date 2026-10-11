#!/usr/bin/env python3
"""
Generates high-resolution macOS application icons and razor-sharp status bar icons
for Autoclix based directly on:
- Resources/AppIcon.svg for the App Icon (faceted cursor inside dark obsidian squircle tile)
- Resources/StatusbarIcon.svg for the Status Bar Icons (outline cursor with click rays)
"""

import os
import shutil
import subprocess
from PIL import Image, ImageDraw

# -------------------------------------------------------------------------
# 1. Geometry for AppIcon (from Resources/AppIcon.svg, viewBox="0 0 127 128")
# Outer translate: (-61, -28)
# Cursor scale 0.3, translate (87, 50)
# Net formula for cursor: X = 26.0 + 0.3 * x, Y = 22.0 + 0.3 * y
# -------------------------------------------------------------------------
APP_SVG_W = 127.0
APP_SVG_H = 128.0

APP_RAYS = [
    ((3.0, 15.0), (37.0, 28.0)),    # Ray 1: M64 43 98 56
    ((86.0, 23.0), (115.0, 3.0)),   # Ray 2: M147 51 176 31
    ((92.0, 44.0), (126.0, 46.0)),  # Ray 3: M153 72 187 74
    ((25.0, 94.0), (44.0, 66.0))    # Ray 4: M86 122 105 94
]

APP_TIP = (62.9, 42.7)      # Tip (123, 69)
APP_RIGHT = (125.3, 100.9)  # Right wing (331, 263)
APP_NOTCH = (89.0, 102.7)   # Inner notch (210, 269)
APP_LEFT = (62.9, 127.9)    # Left wing (123, 353)

# -------------------------------------------------------------------------
# 2. Geometry for StatusbarIcon (from Resources/StatusbarIcon.svg, viewBox="0 0 132 135")
# Cursor is outline-only with stroke 6.0 (20 * 0.3), matching rays stroke 6.0
# -------------------------------------------------------------------------
SB_SVG_W = 132.0
SB_SVG_H = 135.0

SB_RAYS = APP_RAYS

SB_TIP = APP_TIP
SB_RIGHT = APP_RIGHT
SB_NOTCH = APP_NOTCH
SB_LEFT = APP_LEFT


def generate_icons():
    resources_dir = "Resources"
    os.makedirs(resources_dir, exist_ok=True)

    # ----------------------------------------------------
    # 1. Generate 1024x1024 Master AppIcon (Dark Obsidian)
    # ----------------------------------------------------
    W = 1024
    ss = 4
    canvas_w = W * ss
    master = Image.new("RGBA", (canvas_w, canvas_w), (0, 0, 0, 0))
    draw = ImageDraw.Draw(master)

    margin = int(82 * ss)
    box = [margin, margin, canvas_w - margin, canvas_w - margin]
    radius = int((canvas_w - 2 * margin) * 0.224)

    # Squircle dark obsidian tile matching macOS standard
    draw.rounded_rectangle(box, radius=radius, fill=(20, 20, 24, 255), outline=(48, 48, 56, 255), width=int(3 * ss))

    target_h = 580.0 * ss
    target_w = target_h * (APP_SVG_W / APP_SVG_H)

    off_x = (canvas_w - target_w) / 2.0
    off_y = (canvas_w - target_h) / 2.0

    def at(x, y):
        nx = x / APP_SVG_W
        ny = y / APP_SVG_H
        return (off_x + nx * target_w, off_y + ny * target_h)

    # Click Rays
    ray_stroke = int((6.0 / APP_SVG_H) * target_h * 1.05)
    for p1, p2 in APP_RAYS:
        tp1, tp2 = at(*p1), at(*p2)
        draw.line([tp1, tp2], fill=(255, 255, 255, 255), width=ray_stroke)
        cap_r = ray_stroke / 2.0
        draw.ellipse([tp1[0] - cap_r, tp1[1] - cap_r, tp1[0] + cap_r, tp1[1] + cap_r], fill=(255, 255, 255, 255))
        draw.ellipse([tp2[0] - cap_r, tp2[1] - cap_r, tp2[0] + cap_r, tp2[1] + cap_r], fill=(255, 255, 255, 255))

    p_tip = at(*APP_TIP)
    p_right = at(*APP_RIGHT)
    p_notch = at(*APP_NOTCH)
    p_left = at(*APP_LEFT)

    # Right Facet (Pure White)
    draw.polygon([p_tip, p_right, p_notch], fill=(255, 255, 255, 255))

    # Left Facet (Refined Platinum Slate)
    draw.polygon([p_tip, p_notch, p_left], fill=(160, 164, 175, 255))

    app_icon_1024 = master.resize((W, W), Image.Resampling.LANCZOS)
    app_icon_1024.save(os.path.join(resources_dir, "AppIcon.png"))
    app_icon_1024.save(os.path.join(resources_dir, "AppIcon-Dark.png"))
    print("✅ Created Resources/AppIcon.png from Resources/AppIcon.svg")

    # ----------------------------------------------------
    # 2. Multi-resolution Apple .icns Bundle
    # ----------------------------------------------------
    iconset_dir = "/tmp/Autoclix_AppIcon.iconset"
    shutil.rmtree(iconset_dir, ignore_errors=True)
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for size, filename in sizes:
        resized = app_icon_1024.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))

    icns_path = os.path.join(resources_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print("✅ Created Resources/AppIcon.icns")

    # ----------------------------------------------------
    # 3. Razor-Sharp Status Bar Icons from StatusbarIcon.svg
    # (Outline cursor with click rays, 18x18 and 36x36 @2x)
    # ----------------------------------------------------
    def render_crisp_statusbar(size_pt, is_2x=True, mode="template"):
        px_size = size_pt * (2 if is_2x else 1)  # 18 or 36
        ss_sub = 16
        canvas = px_size * ss_sub
        hires = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        hdraw = ImageDraw.Draw(hires)

        # 14.0 pt height in 18 pt menu bar space provides optimal presence
        target_h = (14.0 / 18.0) * canvas
        target_w = target_h * (SB_SVG_W / SB_SVG_H)

        off_x = (canvas - target_w) / 2.0
        off_y = (canvas - target_h) / 2.0

        def sbt(x, y):
            nx = x / SB_SVG_W
            ny = y / SB_SVG_H
            return (off_x + nx * target_w, off_y + ny * target_h)

        if mode == "template":
            # Pure black for macOS template image (macOS tints this automatically in light/dark mode)
            color = (0, 0, 0, 255)
        elif mode == "active":
            # Vibrant emerald green for running state
            color = (16, 185, 129, 255)
        elif mode == "waiting":
            # Vibrant orange for waiting state
            color = (249, 115, 22, 255)

        # Stroke width in supersampled pixels: 2.1 pt for @2x, 1.25 pt for @1x
        stroke_px = (2.1 if is_2x else 1.25) * ss_sub

        # 1. Rays with rounded caps
        for p1, p2 in SB_RAYS:
            sp1, sp2 = sbt(*p1), sbt(*p2)
            hdraw.line([sp1, sp2], fill=color, width=int(stroke_px))
            cap_r = stroke_px / 2.0
            hdraw.ellipse([sp1[0] - cap_r, sp1[1] - cap_r, sp1[0] + cap_r, sp1[1] + cap_r], fill=color)
            hdraw.ellipse([sp2[0] - cap_r, sp2[1] - cap_r, sp2[0] + cap_r, sp2[1] + cap_r], fill=color)

        s_tip = sbt(*SB_TIP)
        s_right = sbt(*SB_RIGHT)
        s_notch = sbt(*SB_NOTCH)
        s_left = sbt(*SB_LEFT)

        # 2. Outline cursor polygon (matching fill="none" stroke="#242424" stroke-width="20" in SVG)
        poly = [s_tip, s_right, s_notch, s_left, s_tip]
        for i in range(len(poly) - 1):
            p1, p2 = poly[i], poly[i + 1]
            hdraw.line([p1, p2], fill=color, width=int(stroke_px))
            cap_r = stroke_px / 2.0
            hdraw.ellipse([p1[0] - cap_r, p1[1] - cap_r, p1[0] + cap_r, p1[1] + cap_r], fill=color)
            hdraw.ellipse([p2[0] - cap_r, p2[1] - cap_r, p2[0] + cap_r, p2[1] + cap_r], fill=color)

        # Downsample with Lanczos
        downsampled = hires.resize((px_size, px_size), Image.Resampling.LANCZOS)

        # Contrast/punch alpha curve for razor-sharp edge definition
        r, g, b, a = downsampled.split()

        def punch_curve(p):
            if p < 15:
                return 0
            elif p > 220:
                return 255
            else:
                return min(255, int(p * 1.15))

        a = a.point(punch_curve)
        return Image.merge("RGBA", (r, g, b, a))

    # Standard template icons (monochrome)
    sb_18 = render_crisp_statusbar(18, is_2x=False, mode="template")
    sb_36 = render_crisp_statusbar(18, is_2x=True, mode="template")

    sb_18.save(os.path.join(resources_dir, "StatusBarIcon.png"))
    sb_18.save(os.path.join(resources_dir, "status-bar-icon.png"))
    sb_36.save(os.path.join(resources_dir, "StatusBarIcon@2x.png"))
    sb_36.save(os.path.join(resources_dir, "status-bar-icon@2x.png"))

    # Active running state (Emerald)
    act_18 = render_crisp_statusbar(18, is_2x=False, mode="active")
    act_36 = render_crisp_statusbar(18, is_2x=True, mode="active")
    act_18.save(os.path.join(resources_dir, "StatusBarIcon-Active.png"))
    act_36.save(os.path.join(resources_dir, "StatusBarIcon-Active@2x.png"))

    # Waiting countdown state (Orange)
    wait_18 = render_crisp_statusbar(18, is_2x=False, mode="waiting")
    wait_36 = render_crisp_statusbar(18, is_2x=True, mode="waiting")
    wait_18.save(os.path.join(resources_dir, "StatusBarIcon-Waiting.png"))
    wait_36.save(os.path.join(resources_dir, "StatusBarIcon-Waiting@2x.png"))

    print("✅ Created razor-sharp outline status bar icons from Resources/StatusbarIcon.svg (Template, Active Emerald, Waiting Orange @1x and @2x)")


if __name__ == "__main__":
    generate_icons()
