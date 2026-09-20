#!/usr/bin/env python
"""把生圖結果標準化為指定尺寸（預設 1080x1350，直式 4:5）。

取代 normalize_comic.ps1（System.Drawing 只支援 Windows）。
行為刻意與舊版一致：同樣三種 fit、同樣的覆寫保護、同樣先寫暫存檔再搬移。
"""

from __future__ import annotations

import argparse
import sys
import uuid
from pathlib import Path

from PIL import Image

LETTERBOX_BACKGROUND = (250, 247, 238)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Normalize a comic image to a fixed size.")
    p.add_argument("--image-path", required=True)
    p.add_argument("--output-path", required=True)
    p.add_argument("--width", type=int, default=1080)
    p.add_argument("--height", type=int, default=1350)
    p.add_argument("--fit", choices=("crop", "letterbox", "stretch"), default="crop")
    p.add_argument("--force", action="store_true",
                   help="Replace the normalized copy if it already exists.")
    return p


def normalize(args) -> str:
    if not (320 <= args.width <= 3840):
        raise ValueError("width must be between 320 and 3840.")
    if not (400 <= args.height <= 4800):
        raise ValueError("height must be between 400 and 4800.")

    image_path = Path(args.image_path).expanduser().resolve()
    output_path = Path(args.output_path).expanduser().resolve()

    if not image_path.is_file():
        raise ValueError(f"Input image not found: {image_path}")
    if image_path == output_path:
        raise ValueError("Input and output must be different files. Preserve the raw image.")
    if output_path.exists() and not args.force:
        raise ValueError(f"Output already exists: {output_path}. "
                         "Use --force to replace the normalized copy.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    width, height = args.width, args.height

    with Image.open(image_path) as src:
        src = src.convert("RGB")

        if args.fit == "letterbox":
            canvas = Image.new("RGB", (width, height), LETTERBOX_BACKGROUND)
            scale = min(width / src.width, height / src.height)
            draw_w = max(1, round(src.width * scale))
            draw_h = max(1, round(src.height * scale))
            resized = src.resize((draw_w, draw_h), Image.LANCZOS)
            canvas.paste(resized, ((width - draw_w) // 2, (height - draw_h) // 2))
        elif args.fit == "stretch":
            canvas = src.resize((width, height), Image.LANCZOS)
        else:
            source_ratio = src.width / src.height
            target_ratio = width / height
            if source_ratio > target_ratio:
                crop_h = float(src.height)
                crop_w = crop_h * target_ratio
                crop_x = (src.width - crop_w) / 2.0
                crop_y = 0.0
            else:
                crop_w = float(src.width)
                crop_h = crop_w / target_ratio
                crop_x = 0.0
                crop_y = (src.height - crop_h) / 2.0
            box = (crop_x, crop_y, crop_x + crop_w, crop_y + crop_h)
            canvas = src.resize((width, height), Image.LANCZOS, box=box)

    # 先寫暫存檔再搬移：中途失敗不會留下一個半成品佔著正式檔名。
    temp_path = output_path.with_name(f"{output_path.name}.tmp.{uuid.uuid4().hex}.png")
    try:
        canvas.save(temp_path, format="PNG")
        temp_path.replace(output_path)
    finally:
        if temp_path.exists():
            temp_path.unlink()

    return f"Normalized image to {width}x{height}: {output_path}"


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        print(normalize(args))
    except Exception as exc:                       # noqa: BLE001
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
