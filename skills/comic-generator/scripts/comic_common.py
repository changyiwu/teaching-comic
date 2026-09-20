"""comic-generator 的共用繪圖工具（Pillow，跨平台）。

取代原本的 System.Drawing（GDI+）。GDI+ 自 .NET 6 起只支援 Windows——
`System.Drawing.Common` 的組件層級帶著 SupportedOSPlatform("windows6.1")，
在 macOS 上會丟 PlatformNotSupportedException，而且是在畫圖那一步才丟，
比一開始就失敗更難查。

這支只放「兩支腳本都要用」的東西：字型解析、文字排版、幾何路徑。
"""

from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import ImageFont

# ── 字型 ────────────────────────────────────────────────────────────────
# 正黑體類的中文字型，依平台列候選。**不要只寫一個路徑**：兩個平台的字型位置
# 本來就不同，寫死等於保證有一邊會壞。找不到時明確報錯，不要默默換成
# 沒有中文字的預設字型——那會畫出一整排豆腐格，而且不報錯。
#
# 逃生門：環境變數 COMIC_FONT / COMIC_FONT_BOLD 指向 .ttf/.ttc，優先於候選清單。
_WINDOWS_FONTS = [
    (r"C:\Windows\Fonts\msjh.ttc", 0),      # Microsoft JhengHei
    (r"C:\Windows\Fonts\msyh.ttc", 0),      # Microsoft YaHei
    (r"C:\Windows\Fonts\simhei.ttf", 0),
]
_WINDOWS_BOLD = [
    (r"C:\Windows\Fonts\msjhbd.ttc", 0),
    (r"C:\Windows\Fonts\msyhbd.ttc", 0),
]
_MACOS_FONTS = [
    ("/System/Library/Fonts/PingFang.ttc", 0),
    ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
    ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0),
    ("/Library/Fonts/Arial Unicode.ttf", 0),
]
_MACOS_BOLD = [
    # PingFang 的粗體在同一個 .ttc 的其他 index，但 index 對應的字重隨 macOS
    # 版本變動，猜錯會拿到 Light。與其猜，不如讓它落空走描邊假粗體。
    ("/System/Library/Fonts/STHeiti Medium.ttc", 1),
]
_LINUX_FONTS = [
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 0),
    ("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", 0),
    ("/usr/share/fonts/opentype/noto/NotoSansCJKtc-Regular.otf", 0),
]
_LINUX_BOLD = [
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 0),
    ("/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc", 0),
]


def _platform_candidates() -> tuple[list, list]:
    if sys.platform == "win32":
        return _WINDOWS_FONTS, _WINDOWS_BOLD
    if sys.platform == "darwin":
        return _MACOS_FONTS, _MACOS_BOLD
    return _LINUX_FONTS, _LINUX_BOLD


def _first_usable(candidates):
    for path, index in candidates:
        if not Path(path).is_file():
            continue
        try:
            ImageFont.truetype(path, 24, index=index)
        except OSError:
            continue
        return path, index
    return None


@dataclass
class FontSet:
    """一組中文字型：正體必有，粗體可能沒有（就用描邊假粗體補）。"""

    regular: tuple[str, int]
    bold: tuple[str, int] | None

    def load(self, size: int, bold: bool):
        """回傳 (font, stroke_width)。

        找不到真正的粗體字時用描邊模擬。描邊寬度要跟著字級走，
        否則小字會糊成一團、大字又看不出粗細。
        """
        size = max(1, int(size))
        if bold and self.bold is not None:
            path, index = self.bold
            return ImageFont.truetype(path, size, index=index), 0
        path, index = self.regular
        font = ImageFont.truetype(path, size, index=index)
        stroke = max(1, round(size * 0.045)) if bold else 0
        return font, stroke


def resolve_fonts() -> FontSet:
    env_regular = os.environ.get("COMIC_FONT")
    env_bold = os.environ.get("COMIC_FONT_BOLD")

    regular = None
    if env_regular:
        if not Path(env_regular).is_file():
            raise RuntimeError(f"COMIC_FONT points at a missing file: {env_regular}")
        regular = (env_regular, 0)

    cands, bold_cands = _platform_candidates()
    if regular is None:
        regular = _first_usable(cands)
    if regular is None:
        listed = ", ".join(p for p, _ in cands)
        raise RuntimeError(
            "No CJK font found. Set COMIC_FONT to a .ttf/.ttc that contains "
            f"Traditional Chinese, or install one of: {listed}"
        )

    bold = (env_bold, 0) if env_bold and Path(env_bold).is_file() else _first_usable(bold_cands)
    return FontSet(regular=regular, bold=bold)


# ── 文字排版 ─────────────────────────────────────────────────────────────
# Pillow 不會自動折行，GDI+ 的 MeasureString 會，所以折行要自己做。
# 中文可以在任何字之間斷，英數不行——所以先切成「單位」再貪婪填行。

_NO_LINE_START = "、。，．！？：；）〉》」』】〕’”%…"
_NO_LINE_END = "（〈《「『【〔‘“"


def _is_cjk(ch: str) -> bool:
    o = ord(ch)
    return (
        0x3040 <= o <= 0x30FF      # 假名
        or 0x3400 <= o <= 0x4DBF   # 擴充 A
        or 0x4E00 <= o <= 0x9FFF   # 基本區
        or 0xF900 <= o <= 0xFAFF   # 相容
        or 0xFF00 <= o <= 0xFF60   # 全形
        or 0x3000 <= o <= 0x303F   # 標點
    )


def _tokenize(paragraph: str) -> list[str]:
    """中文一字一單位；英數與其餘連續字元合成一個單位，避免把英文字拆開。"""
    tokens: list[str] = []
    buf = ""
    for ch in paragraph:
        if _is_cjk(ch) or ch.isspace():
            if buf:
                tokens.append(buf)
                buf = ""
            tokens.append(ch)
        else:
            buf += ch
    if buf:
        tokens.append(buf)
    return tokens


def wrap_paragraph(paragraph: str, font, max_width: float) -> list[str]:
    if not paragraph:
        return [""]
    lines: list[str] = []
    current = ""
    for token in _tokenize(paragraph):
        if token == " " and not current:
            continue                       # 不讓行首留空白
        candidate = current + token
        if current and font.getlength(candidate) > max_width:
            # 避免把不該在行首的標點推到下一行的開頭
            if token and token[0] in _NO_LINE_START and len(current) > 1:
                lines.append(current + token)
                current = ""
                continue
            if current[-1] in _NO_LINE_END:
                lines.append(current[:-1])
                current = current[-1] + token
                continue
            lines.append(current.rstrip())
            current = "" if token.isspace() else token
        else:
            current = candidate
    if current.strip() or not lines:
        lines.append(current.rstrip())
    return lines


LINE_SPACING = 1.12


def layout_text(text: str, font, max_width: float) -> tuple[list[str], float, float]:
    """回傳 (每行文字, 實際最寬, 總高)。`\\n` 是強制換行，規格明訂要支援。"""
    lines: list[str] = []
    for paragraph in text.split("\n"):
        lines.extend(wrap_paragraph(paragraph, font, max_width))
    ascent, descent = font.getmetrics()
    line_height = (ascent + descent) * LINE_SPACING
    width = max((font.getlength(line) for line in lines), default=0.0)
    return lines, width, line_height * len(lines)


def fit_font(fonts: FontSet, text: str, box_w: float, box_h: float,
             preferred: float, minimum: float, bold: bool):
    """由大往小找第一個塞得下的字級。全都塞不下就丟錯，不要硬塞。

    回傳 (font, stroke_width, lines, line_height)。
    """
    size = int(math.floor(preferred))
    while size >= minimum:
        font, stroke = fonts.load(size, bold)
        lines, width, height = layout_text(text, font, box_w)
        if width <= box_w + 1 and height <= box_h + 1:
            ascent, descent = font.getmetrics()
            return font, stroke, lines, (ascent + descent) * LINE_SPACING
        size -= 1
    raise ValueError(f"Text does not fit inside its bubble even at {minimum:g}px: {text}")


def draw_centered(draw, lines, line_height, rect, font, stroke, fill):
    """在 rect 內水平垂直置中畫多行文字。rect = (x, y, w, h)。"""
    x, y, w, h = rect
    total = line_height * len(lines)
    top = y + (h - total) / 2.0
    cx = x + w / 2.0
    for i, line in enumerate(lines):
        draw.text(
            (cx, top + i * line_height),
            line,
            font=font,
            fill=fill,
            anchor="ma",
            stroke_width=stroke,
            stroke_fill=fill,
        )


# ── 幾何 ─────────────────────────────────────────────────────────────────

def rounded_rect_points(x, y, w, h, radius, steps=12):
    """把圓角矩形攤成點列，給虛線描邊用（Pillow 的 outline 不支援虛線）。"""
    r = min(radius, w / 2.0, h / 2.0)
    pts = []
    corners = [
        (x + w - r, y + r, -90, 0),
        (x + w - r, y + h - r, 0, 90),
        (x + r, y + h - r, 90, 180),
        (x + r, y + r, 180, 270),
    ]
    for cx, cy, start, end in corners:
        for i in range(steps + 1):
            a = math.radians(start + (end - start) * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    return pts


def shout_points(x, y, w, h, spikes=32):
    """大聲泡的鋸齒外框：一圈上交替用滿半徑與 0.84 倍半徑。"""
    cx, cy = x + w / 2.0, y + h / 2.0
    rx, ry = w / 2.0, h / 2.0
    pts = []
    for i in range(spikes):
        angle = 2.0 * math.pi * i / spikes
        factor = 1.0 if i % 2 == 0 else 0.84
        pts.append((cx + rx * math.cos(angle) * factor,
                    cy + ry * math.sin(angle) * factor))
    return pts


def draw_dashed(draw, points, fill, width, dash=9.0, gap=6.0):
    """沿著點列畫虛線。低語泡的框是虛線，Pillow 沒有 DashStyle，只能自己走。"""
    carry = 0.0
    drawing = True
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        seg = math.hypot(x2 - x1, y2 - y1)
        if seg <= 0:
            continue
        pos = 0.0
        while pos < seg:
            span = (dash if drawing else gap) - carry
            step = min(span, seg - pos)
            if drawing:
                t0, t1 = pos / seg, (pos + step) / seg
                draw.line(
                    [(x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0),
                     (x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1)],
                    fill=fill, width=width,
                )
            pos += step
            carry += step
            if carry >= (dash if drawing else gap) - 1e-9:
                drawing = not drawing
                carry = 0.0


def thought_tail_dots(bx, by, bw, bh, tx, ty):
    """思考泡的三顆小圓：從泡緣朝說話者遞減。回傳 [(cx, cy, 直徑)]。"""
    cx, cy = bx + bw / 2.0, by + bh / 2.0
    dx, dy = tx - cx, ty - cy
    if math.hypot(dx, dy) <= 0:
        return []
    rx, ry = bw / 2.0, bh / 2.0
    scale = 1.0 / math.sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry))
    ex, ey = cx + dx * scale, cy + dy * scale
    out = []
    for size, frac in ((14.0, 0.16), (10.0, 0.30), (6.0, 0.43)):
        out.append((ex + (tx - ex) * frac, ey + (ty - ey) * frac, size))
    return out
