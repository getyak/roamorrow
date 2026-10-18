"""Render the shared Roamorrow mark into native vector and app-icon assets.

The paths match roamorrow-mark.svg and the web mark's 64-point viewBox.
Requires Pillow and ReportLab only when regenerating these checked-in assets.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw
from reportlab.pdfgen import canvas

RESOURCES = Path(__file__).resolve().parents[1] / "SoloCompass/Resources"
ASSETS = RESOURCES / "Assets.xcassets"
PAPER = "#FAF8F6"
BROWN = "#5D3000"
GOLD = "#C9A677"


def cubic(start, first, second, end):
    points = []
    for step in range(257):
        t = step / 256
        u = 1 - t
        points.append(tuple(
            u**3 * start[i] + 3 * u**2 * t * first[i]
            + 3 * u * t**2 * second[i] + t**3 * end[i]
            for i in (0, 1)
        ))
    return points


def icon(size):
    scale = size * 4 / 64
    image = Image.new("RGB", (size * 4, size * 4), PAPER)
    draw = ImageDraw.Draw(image)
    draw.pieslice(tuple(v * scale for v in (34, 16, 54, 36)), 180, 360, fill=GOLD)
    paths = [[(10, 28), (54, 28)],
             cubic((22, 55), (48, 48), (47, 41), (31, 38))
             + cubic((31, 38), (17, 35), (18, 28), (32, 28))[1:]]
    radius = 2.25 * scale
    for path in paths:
        points = [(x * scale, y * scale) for x, y in path]
        draw.line(points, fill=BROWN, width=round(4.5 * scale), joint="curve")
        # Round joins at every sample keep dense, wide cubic strokes solid.
        for x, y in points:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=BROWN)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def vector_mark():
    destination = ASSETS / "RoamorrowMark.imageset"
    destination.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(destination / "roamorrow-mark.pdf"), pagesize=(64, 64), invariant=1)
    pdf.translate(0, 64)
    pdf.scale(1, -1)
    pdf.setFillColor(GOLD)
    sun = pdf.beginPath()
    sun.moveTo(34, 26)
    sun.curveTo(34, 20.4771525, 38.4771525, 16, 44, 16)
    sun.curveTo(49.5228475, 16, 54, 20.4771525, 54, 26)
    sun.close()
    pdf.drawPath(sun, fill=1, stroke=0)
    pdf.setStrokeColor(BROWN)
    pdf.setLineWidth(4.5)
    pdf.setLineCap(1)
    pdf.setLineJoin(1)
    horizon = pdf.beginPath()
    horizon.moveTo(10, 28)
    horizon.lineTo(54, 28)
    pdf.drawPath(horizon)
    route = pdf.beginPath()
    route.moveTo(22, 55)
    route.curveTo(48, 48, 47, 41, 31, 38)
    route.curveTo(17, 35, 18, 28, 32, 28)
    pdf.drawPath(route)
    pdf.showPage()
    pdf.save()
    (destination / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "roamorrow-mark.pdf", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }, indent=2) + "\n")


if __name__ == "__main__":
    vector_mark()
    icons = ASSETS / "AppIcon.appiconset"
    manifest = json.loads((icons / "Contents.json").read_text())
    for filename in sorted({entry["filename"] for entry in manifest["images"]}):
        size = int(filename.split("-")[1].split("x")[0])
        icon(size).save(icons / filename)
