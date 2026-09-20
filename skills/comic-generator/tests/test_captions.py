#!/usr/bin/env python
"""comic-generator 的回歸測試（跨平台，Pillow）。

取代 test_captions.ps1。涵蓋與舊版相同的項目：
標準化、五種泡型、自動縮字、預設只排文字、--draw-bubbles 退路、
驗證、覆寫保護、暫存檔清理。

用法：<file-toolkit 的 python> tests/test_captions.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

SKILL_ROOT = Path(__file__).resolve().parent.parent
NORMALIZE = SKILL_ROOT / "scripts" / "normalize_comic.py"
CAPTIONS = SKILL_ROOT / "scripts" / "add_captions_json.py"
FIXTURE = SKILL_ROOT / "tests" / "fixtures" / "bubbles.json"


def run(script: Path, *args: str) -> subprocess.CompletedProcess:
    """一律用跑這支測試的同一個直譯器，不要去猜系統 python 是哪個。"""
    return subprocess.run([sys.executable, str(script), *args],
                          capture_output=True, text=True)


def make_source(path: Path) -> None:
    img = Image.new("RGB", (1200, 1200))
    draw = ImageDraw.Draw(img)
    quadrants = [
        ((0, 0, 600, 600), (231, 244, 255)),
        ((600, 0, 1200, 600), (241, 255, 232)),
        ((0, 600, 600, 1200), (255, 242, 224)),
        ((600, 600, 1200, 1200), (246, 234, 255)),
    ]
    for box, color in quadrants:
        draw.rectangle(box, fill=color)
    draw.line([(600, 0), (600, 1200)], fill=(70, 60, 50), width=8)
    draw.line([(0, 600), (1200, 600)], fill=(70, 60, 50), width=8)
    img.save(path, format="PNG")


def changed_pixels(base_path: Path, compare_path: Path) -> int:
    with Image.open(base_path) as a_img, Image.open(compare_path) as b_img:
        a = a_img.convert("RGB")
        b = b_img.convert("RGB")
        changed = 0
        for x in range(0, a.width, 4):
            for y in range(0, a.height, 4):
                pa, pb = a.getpixel((x, y)), b.getpixel((x, y))
                if (abs(pa[0] - pb[0]) > 12 or abs(pa[1] - pb[1]) > 12
                        or abs(pa[2] - pb[2]) > 12):
                    changed += 1
        return changed


def dark_ratio(path: Path) -> float:
    with Image.open(path) as img:
        rgb = img.convert("RGB")
        dark = total = 0
        for x in range(10, rgb.width, 20):
            for y in range(10, rgb.height, 20):
                p = rgb.getpixel((x, y))
                if p[0] < 20 and p[1] < 20 and p[2] < 20:
                    dark += 1
                total += 1
        return dark / total


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="teaching-comic-tests-") as tmp:
        work = Path(tmp)
        source = work / "source-square.png"
        normalized = work / "comic-normalized.png"
        final = work / "comic-final.png"
        text_only = work / "comic-final-textonly.png"

        make_source(source)

        r = run(NORMALIZE, "--image-path", str(source), "--output-path", str(normalized))
        assert r.returncode == 0, f"normalize_comic.py failed: {r.stderr}"

        r = run(CAPTIONS, "--image-path", str(normalized), "--output-path", str(final),
                "--json-path", str(FIXTURE), "--draw-bubbles")
        assert r.returncode == 0, f"add_captions_json.py --draw-bubbles failed: {r.stderr}"

        with Image.open(final) as img:
            assert (img.width, img.height) == (1080, 1350), \
                f"Unexpected output size: {img.width}x{img.height}"

        ratio = dark_ratio(final)
        assert ratio <= 0.05, f"Unexpected black-area regression detected ({ratio:.3f})."

        # 不給旗標時必須只排文字：漏給旗標絕不能在生圖畫好的泡上再蓋一層框。
        r = run(CAPTIONS, "--image-path", str(normalized), "--output-path", str(text_only),
                "--json-path", str(FIXTURE))
        assert r.returncode == 0, f"add_captions_json.py default mode failed: {r.stderr}"

        full_diff = changed_pixels(normalized, final)
        text_diff = changed_pixels(normalized, text_only)
        assert text_diff > 0, "Default mode rendered nothing onto the image."
        assert text_diff < full_diff * 0.5, \
            f"Default mode still paints bubble shapes (changed={text_diff} vs full={full_diff})."

        # 輸入與輸出同一個檔案必須擋下來，否則原始生圖會被覆寫。
        r = run(CAPTIONS, "--image-path", str(normalized), "--output-path", str(normalized),
                "--json-path", str(FIXTURE))
        assert r.returncode != 0, "Same-path safety check did not fail as expected."

        invalid_json = work / "invalid.json"
        invalid_json.write_text('[{"panel":9,"text":"invalid"}]', encoding="utf-8")
        r = run(CAPTIONS, "--image-path", str(normalized),
                "--output-path", str(work / "invalid-output.png"),
                "--json-path", str(invalid_json))
        assert r.returncode != 0, "Invalid-panel validation did not fail as expected."

        # 已存在的輸出沒給 --force 要擋下來。
        r = run(CAPTIONS, "--image-path", str(normalized), "--output-path", str(final),
                "--json-path", str(FIXTURE))
        assert r.returncode != 0, "Overwrite protection did not fail as expected."

        leftovers = [p.name for p in work.iterdir() if ".tmp." in p.name]
        assert not leftovers, f"Temporary files were not cleaned up: {leftovers}"

    print("PASS: normalize, render, five bubble types, auto-fit, text-only default, "
          "--draw-bubbles fallback, validation, overwrite protection, and temp cleanup.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
