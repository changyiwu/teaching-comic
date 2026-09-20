#!/usr/bin/env python
"""依 JSON 設定把中文排進四格漫畫的對話泡。

取代 add_captions_json.ps1（System.Drawing 只支援 Windows）。
JSON 結構、驗證規則、預設值、錯誤訊息都刻意與舊版一致，既有的 .json 不必改。

預設**只排文字不畫框**：泡是生圖階段畫出來的，再畫一次會變成框中框。
--draw-bubbles 是泡不堪用時的退路。
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import uuid
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comic_common import (  # noqa: E402
    draw_centered,
    draw_dashed,
    fit_font,
    resolve_fonts,
    rounded_rect_points,
    shout_points,
    thought_tail_dots,
)

ALLOWED_TYPES = ("speech", "thought", "narration", "shout", "whisper")
AUTO_SLOTS = ("top-left", "top-right", "bottom-left", "bottom-right",
              "top-center", "bottom-center", "center")

FILL_COLORS = {
    "narration": (255, 247, 218, 248),
    "shout": (255, 255, 245, 250),
    "default": (255, 255, 252, 248),
}
BORDER_WHISPER = (92, 82, 72, 230)
BORDER_DEFAULT = (58, 49, 40, 255)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Render caption text into comic bubbles.")
    p.add_argument("--image-path", required=True)
    p.add_argument("--output-path", required=True)
    p.add_argument("--json-path", required=True)
    p.add_argument("--force", action="store_true")
    p.add_argument("--allow-overlap", action="store_true")
    p.add_argument("--draw-bubbles", action="store_true",
                   help="Also paint the bubble outline/fill/tail, not just the text.")
    return p


def auto_position(position, panel_w, panel_h, w, h):
    margin_x = panel_w * 0.04
    margin_y = panel_h * 0.035
    left, top = margin_x, margin_y
    center_x = (panel_w - w) / 2.0
    center_y = (panel_h - h) / 2.0
    right = panel_w - w - margin_x
    bottom = panel_h - h - margin_y
    table = {
        "top-left": (left, top),
        "top-center": (center_x, top),
        "top-right": (right, top),
        "center-left": (left, center_y),
        "center": (center_x, center_y),
        "center-right": (right, center_y),
        "bottom-left": (left, bottom),
        "bottom-center": (center_x, bottom),
        "bottom-right": (right, bottom),
    }
    if position not in table:
        raise ValueError(f"Unsupported position '{position}'.")
    return table[position]


def number(bubble, name, default=None, required=False, label=""):
    if name not in bubble:
        if required:
            raise ValueError(f"{label}missing required numeric property '{name}'.")
        return default
    try:
        return float(bubble[name])
    except (TypeError, ValueError):
        raise ValueError(f"{label}property '{name}' must be numeric.") from None


def resolve_bubbles(source, img_w, img_h, draw_bubbles_default):
    panel_w = img_w / 2.0
    panel_h = img_h / 2.0
    origins = [(0.0, 0.0), (panel_w, 0.0), (0.0, panel_h), (panel_w, panel_h)]
    auto_counts = {1: 0, 2: 0, 3: 0, 4: 0}
    resolved = []

    for index, bubble in enumerate(source, start=1):
        label = f"Bubble {index}: "
        if not isinstance(bubble, dict):
            raise ValueError(f"{label}each bubble must be a JSON object.")
        if "panel" not in bubble:
            raise ValueError(f"{label}missing 'panel'.")
        panel = int(bubble["panel"])
        if panel < 1 or panel > 4:
            raise ValueError(f"{label}panel must be between 1 and 4.")
        text = str(bubble.get("text", ""))
        if not text.strip():
            raise ValueError(f"{label}text cannot be empty.")

        btype = str(bubble.get("type", "speech")).lower()
        if btype not in ALLOWED_TYPES:
            raise ValueError(f"{label}unsupported type '{btype}'. "
                             f"Allowed: {', '.join(ALLOWED_TYPES)}.")

        draw_bubble = bool(bubble["draw_bubble"]) if "draw_bubble" in bubble \
            else draw_bubbles_default

        width_factor = 0.78 if btype == "narration" else 0.54
        if btype == "narration":
            height_factor = 0.14
        elif btype == "shout":
            height_factor = 0.21
        else:
            height_factor = 0.18
        w = number(bubble, "w", panel_w * width_factor, label=label)
        h = number(bubble, "h", panel_h * height_factor, label=label)

        # 純排字的框只是版面矩形，可以比畫出來的泡更薄。
        min_w = 80 if draw_bubble else 40
        min_h = 55 if draw_bubble else 24
        if w < min_w or h < min_h:
            raise ValueError(f"{label}w and h are too small.")

        has_x, has_y = "x" in bubble, "y" in bubble
        if has_x != has_y:
            raise ValueError(f"{label}provide both x and y, or neither.")
        if has_x:
            local_x = number(bubble, "x", required=True, label=label)
            local_y = number(bubble, "y", required=True, label=label)
        else:
            if "position" in bubble:
                position = str(bubble["position"]).lower()
            else:
                position = AUTO_SLOTS[auto_counts[panel] % len(AUTO_SLOTS)]
                auto_counts[panel] += 1
            local_x, local_y = auto_position(position, panel_w, panel_h, w, h)

        if local_x < 0 or local_y < 0 or local_x + w > panel_w or local_y + h > panel_h:
            raise ValueError(f"{label}rectangle exceeds panel {panel} bounds.")

        has_sx, has_sy = "speaker_x" in bubble, "speaker_y" in bubble
        has_tx, has_ty = "tail_x" in bubble, "tail_y" in bubble
        if (has_sx != has_sy) or (has_tx != has_ty):
            raise ValueError(f"{label}tail/speaker coordinates must be provided as an x/y pair.")

        tail_x = tail_y = None
        if btype != "narration":
            if has_sx:
                tail_x = number(bubble, "speaker_x", required=True, label=label)
                tail_y = number(bubble, "speaker_y", required=True, label=label)
            elif has_tx:
                tail_x = number(bubble, "tail_x", required=True, label=label)
                tail_y = number(bubble, "tail_y", required=True, label=label)
            if tail_x is not None and (tail_x < 0 or tail_y < 0
                                       or tail_x > panel_w or tail_y > panel_h):
                raise ValueError(f"{label}tail/speaker target must stay inside panel {panel}.")

        text_color = (0, 0, 0)
        if "text_color" in bubble:
            try:
                text_color = ImageColor.getrgb(str(bubble["text_color"]))
            except ValueError:
                raise ValueError(
                    f"{label}unsupported text_color '{bubble['text_color']}'. "
                    "Use a name such as 'white' or a hex value such as '#FFFFFF'."
                ) from None

        preferred = number(bubble, "font_size",
                           min(28.0, max(18.0, round(img_h / 60.0))), label=label)
        minimum = number(bubble, "min_font_size", 12.0, label=label)
        if preferred < minimum:
            raise ValueError(f"{label}font_size must be >= min_font_size.")

        ox, oy = origins[panel - 1]
        resolved.append({
            "index": index, "panel": panel, "type": btype, "text": text,
            "draw_bubble": draw_bubble, "text_color": text_color,
            "local_x": local_x, "local_y": local_y,
            "x": ox + local_x, "y": oy + local_y, "w": w, "h": h,
            "tail_x": None if tail_x is None else ox + tail_x,
            "tail_y": None if tail_y is None else oy + tail_y,
            "preferred": preferred, "minimum": minimum,
        })
    return resolved


def check_overlap(resolved):
    for i in range(len(resolved)):
        for j in range(i + 1, len(resolved)):
            a, b = resolved[i], resolved[j]
            if a["panel"] != b["panel"]:
                continue
            if (a["local_x"] < b["local_x"] + b["w"]
                    and b["local_x"] < a["local_x"] + a["w"]
                    and a["local_y"] < b["local_y"] + b["h"]
                    and b["local_y"] < a["local_y"] + a["h"]):
                raise ValueError(
                    f"Bubble {a['index']} and bubble {b['index']} overlap in "
                    f"panel {a['panel']}. Reposition them or use --allow-overlap."
                )


def paint_bubble(draw, bubble):
    btype = bubble["type"]
    fill = FILL_COLORS.get(btype, FILL_COLORS["default"])
    border = BORDER_WHISPER if btype == "whisper" else BORDER_DEFAULT
    line_w = 2 if btype != "narration" else 1
    x, y, w, h = bubble["x"], bubble["y"], bubble["w"], bubble["h"]

    if btype == "shout":
        pts = shout_points(x, y, w, h)
        draw.polygon(pts, fill=fill, outline=border, width=line_w)
        return
    radius = min(w, h) * (0.12 if btype == "narration" else 0.28)
    if btype == "whisper":
        # 虛線框：Pillow 的 outline 畫不了虛線，先填色再自己沿著點列走。
        draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=fill)
        draw_dashed(draw, rounded_rect_points(x, y, w, h, radius), border, line_w)
        return
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius,
                           fill=fill, outline=border, width=line_w)


def paint_thought_tail(draw, bubble):
    fill = FILL_COLORS["default"]
    for cx, cy, size in thought_tail_dots(bubble["x"], bubble["y"], bubble["w"],
                                          bubble["h"], bubble["tail_x"], bubble["tail_y"]):
        box = [cx - size / 2.0, cy - size / 2.0, cx + size / 2.0, cy + size / 2.0]
        draw.ellipse(box, fill=fill, outline=BORDER_DEFAULT, width=2)


def text_rect(bubble):
    w, h = bubble["w"], bubble["h"]
    # 固定下限是照完整泡抓的；再用矩形比例封頂，薄的純文字框才不會被內距吃光。
    pad_x = min(max(18.0, w * 0.09), w * 0.15)
    pad_y = min(max(14.0, h * 0.14), h * 0.20)
    if bubble["type"] == "shout":
        pad_x = max(pad_x, w * 0.14)
        pad_y = max(pad_y, h * 0.18)
    return (bubble["x"] + pad_x, bubble["y"] + pad_y,
            w - 2.0 * pad_x, h - 2.0 * pad_y)


def render(args) -> str:
    image_path = Path(args.image_path).expanduser().resolve()
    output_path = Path(args.output_path).expanduser().resolve()
    json_path = Path(args.json_path).expanduser().resolve()

    if not image_path.is_file():
        raise ValueError(f"Input image not found: {image_path}")
    if not json_path.is_file():
        raise ValueError(f"JSON config file not found: {json_path}")
    if image_path == output_path:
        raise ValueError("Input and output must be different files. "
                         "Keep the raw image and final image separate.")
    if output_path.exists() and not args.force:
        raise ValueError(f"Output already exists: {output_path}. "
                         "Use --force to replace the final image.")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        parsed = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON config: {exc}") from None

    source = parsed["bubbles"] if isinstance(parsed, dict) and "bubbles" in parsed else parsed
    if not isinstance(source, list) or not source:
        raise ValueError("JSON config must contain at least one bubble.")

    with Image.open(image_path) as src:
        base = src.convert("RGBA")

    ratio = base.width / base.height
    if abs(ratio - 4.0 / 5.0) > 0.01:
        raise ValueError("Input image must use a portrait 4:5 aspect ratio. "
                         f"Actual size: {base.width}x{base.height}")

    resolved = resolve_bubbles(source, base.width, base.height, args.draw_bubbles)
    if not args.allow_overlap:
        check_overlap(resolved)

    fonts = resolve_fonts()
    # 泡的填色帶 alpha，所以畫在獨立圖層再合成，半透明才會真的半透明。
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    for bubble in resolved:
        if bubble["draw_bubble"]:
            paint_bubble(draw, bubble)
            # 只有思考泡有尾巴，一般對話泡的尾巴是刻意關掉的。
            if bubble["type"] == "thought" and bubble["tail_x"] is not None:
                paint_thought_tail(draw, bubble)

        rect = text_rect(bubble)
        bold = bubble["type"] != "whisper"
        font, stroke, lines, line_height = fit_font(
            fonts, bubble["text"], rect[2], rect[3],
            bubble["preferred"], bubble["minimum"], bold,
        )
        draw_centered(draw, lines, line_height, rect, font, stroke,
                      tuple(bubble["text_color"]))

    result = Image.alpha_composite(base, overlay).convert("RGB")

    temp_path = output_path.with_name(f"{output_path.name}.tmp.{uuid.uuid4().hex}.png")
    try:
        result.save(temp_path, format="PNG")
        temp_path.replace(output_path)
    finally:
        if temp_path.exists():
            temp_path.unlink()

    return f"Successfully rendered {len(resolved)} bubbles to {output_path}"


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        print(render(args))
    except Exception as exc:                       # noqa: BLE001
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
