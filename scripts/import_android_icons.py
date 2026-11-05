#!/usr/bin/env python3
"""Converts the Android icons (res/drawable/ic_*.xml vector drawables) into SVG template images in
the iOS asset catalog (Resources/Assets.xcassets/Icons/<name>.imageset), so both apps show the same
pictures. Template rendering lets SwiftUI tint them with foregroundStyle; vectors stay sharp at any size.

Usage, from the repo root:
    python3 ios/scripts/import_android_icons.py            # every ic_*.xml
    python3 ios/scripts/import_android_icons.py ic_plus     # only these
"""
import json
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAWABLES = ROOT / "android/app/src/main/res/drawable"
ICONS = ROOT / "ios/iWeGain/Resources/Assets.xcassets/Icons"
A = "{http://schemas.android.com/apk/res/android}"


def number(value: str) -> str:
    return value.replace("dp", "")


def color(value: str):
    """#RGB, #ARGB, #RRGGBB or #AARRGGBB → (svg color, opacity)."""
    hex_value = value.lstrip("#")
    if len(hex_value) in (3, 4):
        hex_value = "".join(c * 2 for c in hex_value)
    alpha = 1.0
    if len(hex_value) == 8:
        alpha = int(hex_value[:2], 16) / 255
        hex_value = hex_value[2:]
    return f"#{hex_value}", alpha


def path_svg(element: ET.Element) -> str:
    attributes = [f'd="{element.get(A + "pathData")}"']
    fill = element.get(A + "fillColor")
    if fill:
        svg_color, alpha = color(fill)
        alpha *= float(element.get(A + "fillAlpha", "1"))
        attributes.append(f'fill="{svg_color}"')
        if alpha < 1:
            attributes.append(f'fill-opacity="{alpha:.3f}"')
        if element.get(A + "fillType") == "evenOdd":
            attributes.append('fill-rule="evenodd"')
    else:
        attributes.append('fill="none"')
    stroke = element.get(A + "strokeColor")
    if stroke:
        svg_color, alpha = color(stroke)
        alpha *= float(element.get(A + "strokeAlpha", "1"))
        attributes.append(f'stroke="{svg_color}"')
        if alpha < 1:
            attributes.append(f'stroke-opacity="{alpha:.3f}"')
        attributes.append(f'stroke-width="{element.get(A + "strokeWidth", "1")}"')
        if element.get(A + "strokeLineCap"):
            attributes.append(f'stroke-linecap="{element.get(A + "strokeLineCap")}"')
        if element.get(A + "strokeLineJoin"):
            attributes.append(f'stroke-linejoin="{element.get(A + "strokeLineJoin")}"')
    return f"<path {' '.join(attributes)}/>"


def group_svg(element: ET.Element) -> str:
    transforms = []
    pivot_x, pivot_y = float(element.get(A + "pivotX", "0")), float(element.get(A + "pivotY", "0"))
    tx, ty = element.get(A + "translateX", "0"), element.get(A + "translateY", "0")
    if tx != "0" or ty != "0":
        transforms.append(f"translate({tx} {ty})")
    rotation = element.get(A + "rotation")
    scale_x, scale_y = element.get(A + "scaleX", "1"), element.get(A + "scaleY", "1")
    if rotation or scale_x != "1" or scale_y != "1":
        transforms.append(f"translate({pivot_x} {pivot_y})")
        if rotation:
            transforms.append(f"rotate({rotation})")
        if scale_x != "1" or scale_y != "1":
            transforms.append(f"scale({scale_x} {scale_y})")
        transforms.append(f"translate({-pivot_x} {-pivot_y})")
    children = "".join(child_svg(child) for child in element)
    transform = f' transform="{" ".join(transforms)}"' if transforms else ""
    return f"<g{transform}>{children}</g>"


def child_svg(element: ET.Element) -> str:
    if element.tag == "path":
        return path_svg(element)
    if element.tag == "group":
        return group_svg(element)
    if element.tag == "clip-path":
        raise ValueError("clip-path isn't supported")
    return ""


def convert(source: Path) -> str:
    root = ET.parse(source).getroot()
    if root.tag != "vector":
        raise ValueError(f"{source.name} isn't a vector drawable")
    width, height = number(root.get(A + "width")), number(root.get(A + "height"))
    viewport = f'0 0 {root.get(A + "viewportWidth")} {root.get(A + "viewportHeight")}'
    body = "".join(child_svg(child) for child in root)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{viewport}">{body}</svg>\n'


def main(names: list[str]) -> None:
    sources = [DRAWABLES / f"{n}.xml" for n in names] if names else sorted(DRAWABLES.glob("ic_*.xml"))
    ICONS.mkdir(parents=True, exist_ok=True)
    (ICONS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for source in sources:
        imageset = ICONS / f"{source.stem}.imageset"
        if imageset.exists():
            shutil.rmtree(imageset)
        imageset.mkdir()
        (imageset / f"{source.stem}.svg").write_text(convert(source))
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{source.stem}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        }, indent=2) + "\n")
    print(f"Converted {len(sources)} icons into {ICONS.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
