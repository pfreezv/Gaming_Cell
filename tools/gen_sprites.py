#!/usr/bin/env python3
"""
Genera sprites PNG 64x64 para cada molécula definida en science-params.json.
Salida: assets/sprites/molecules/mol_{TYPE}.png
"""
import json
import os
import math
from PIL import Image, ImageDraw, ImageFilter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
JSON_PATH = os.path.join(PROJECT_ROOT, "src", "data", "science-params.json")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "molecules")
IMG_SIZE = 64


def parse_color(hex_str):
    hex_str = hex_str.lstrip('#')
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))


def create_sprite(mol_type, mol_data):
    r, g, b = parse_color(mol_data.get("color", "#ffffff"))
    shape = mol_data.get("shape", "circle")

    img = Image.new("RGBA", (IMG_SIZE, IMG_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base = (r, g, b, 230)
    border = (max(r - 80, 0), max(g - 80, 0), max(b - 80, 0), 255)
    glow = (min(r + 60, 255), min(g + 60, 255), min(b + 60, 255), 100)
    highlight = (255, 255, 255, 110)

    cx, cy = IMG_SIZE / 2, IMG_SIZE / 2
    rad = 22

    # ── helpers ──────────────────────────────────────────
    def circ(x, y, radius, fill=base, outline=border):
        draw.ellipse(
            [x - radius, y - radius, x + radius, y + radius],
            fill=fill, outline=outline, width=2
        )
        # specular highlight
        hr = radius * 0.35
        draw.ellipse(
            [x - radius * 0.45, y - radius * 0.55,
             x - radius * 0.45 + hr * 2, y - radius * 0.55 + hr * 2],
            fill=highlight
        )

    def poly(x, y, radius, sides, rotation=0):
        points = []
        for i in range(sides):
            a = rotation + (i * 2 * math.pi / sides)
            points.append((x + radius * math.cos(a), y + radius * math.sin(a)))
        draw.polygon(points, fill=base, outline=border, width=2)
        # small highlight
        hr = radius * 0.18
        draw.ellipse(
            [x - radius * 0.25, y - radius * 0.35,
             x - radius * 0.25 + hr * 2, y - radius * 0.35 + hr * 2],
            fill=highlight
        )

    # ── outer glow ring ─────────────────────────────────
    draw.ellipse(
        [cx - rad - 4, cy - rad - 4, cx + rad + 4, cy + rad + 4],
        fill=(r, g, b, 35)
    )

    # ── shape rendering ─────────────────────────────────
    if shape == "circle":
        circ(cx, cy, rad)

    elif shape == "amino":
        circ(cx - 7, cy + 5, rad * 0.72)
        circ(cx + 9, cy - 7, rad * 0.48)

    elif shape == "hexagon":
        poly(cx, cy, rad, 6, rotation=math.pi / 6)

    elif shape == "nmp":
        poly(cx - 6, cy, rad * 0.65, 6, rotation=math.pi / 6)
        circ(cx + 14, cy, rad * 0.35)

    elif shape == "chain":
        circ(cx - 14, cy + 6, rad * 0.42)
        circ(cx, cy - 2, rad * 0.42)
        circ(cx + 14, cy + 6, rad * 0.42)
        # connectors
        draw.line([(cx - 8, cy + 3), (cx - 4, cy - 1)], fill=border, width=2)
        draw.line([(cx + 4, cy - 1), (cx + 8, cy + 3)], fill=border, width=2)

    elif shape == "rna":
        offsets = [(-18, 10), (-9, -2), (0, -12), (10, -4), (18, 8)]
        for i, (dx, dy) in enumerate(offsets):
            circ(cx + dx, cy + dy, rad * 0.3)
            if i > 0:
                px, py = offsets[i - 1]
                draw.line(
                    [(cx + px, cy + py), (cx + dx, cy + dy)],
                    fill=border, width=2
                )

    elif shape == "atp":
        poly(cx - 10, cy, rad * 0.55, 6, rotation=math.pi / 6)
        positions = [(cx + 6, cy - 6), (cx + 14, cy), (cx + 22, cy + 6)]
        for i, (px, py) in enumerate(positions):
            circ(px, py, rad * 0.22)
            if i > 0:
                prev = positions[i - 1]
                draw.line([prev, (px, py)], fill=border, width=2)
        draw.line([(cx - 2, cy), (cx + 6, cy - 6)], fill=border, width=2)

    elif shape == "square":
        poly(cx, cy, rad, 4, rotation=math.pi / 4)

    elif shape == "triangle":
        poly(cx, cy, rad, 3, rotation=-math.pi / 2)

    else:
        circ(cx, cy, rad)

    # ── post-processing ─────────────────────────────────
    img = img.filter(ImageFilter.SMOOTH_MORE)

    out_path = os.path.join(OUTPUT_DIR, f"mol_{mol_type}.png")
    img.save(out_path)
    return out_path


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    with open(JSON_PATH, 'r') as f:
        data = json.load(f)

    molecules = data.get("molecules", {})
    count = 0
    for m_type, m_data in molecules.items():
        if m_type.startswith("_"):
            continue
        path = create_sprite(m_type, m_data)
        print(f"  ✓ {m_type:12s} → {os.path.basename(path)}")
        count += 1

    print(f"\nDone — {count} sprites generated in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
