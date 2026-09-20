# teaching-comic

將教材重點轉換成適合電腦與手機閱讀的教學四格漫畫。

## 漫畫規格

- 畫布：直式 4:5
- 標準尺寸：1080×1350
- 分格：2×2，每格 540×675
- 文字：生圖階段不產生文字，完成後以 PowerShell 加入清晰中文對話框

## 安全工作流

每張漫畫固定保留三個階段，避免重跑時把對話框疊在舊成品上：

1. `comic_point_1_raw.png`：生圖工具產生的無文字原圖。
2. `comic_point_1_normalized.png`：裁切並縮放為 1080×1350。
3. `comic_point_1_final.png`：加入中文對話框的最終成品。

輸入與輸出不可使用同一個檔案。若要替換已存在的衍生檔案，需明確加上 `--force`。

## 目錄結構

- `AGENTS.md`：跨 Agent 專案規範與工作守則。
- `skills/comic-generator/SKILL.md`：教材四格漫畫生成工作流。
- `skills/comic-generator/scripts/normalize_comic.py`：將圖片標準化為 4:5、1080×1350。
- `skills/comic-generator/scripts/add_captions_json.py`：驗證 JSON 並加入多個中文對話框。
- `skills/comic-generator/scripts/comic_common.py`：字型解析、中文折行、泡型幾何（兩支腳本共用）。
- `skills/comic-generator/tests/test_captions.py`：自動測試標準化、文字後製及安全檢查。
- `skills/comic-generator/tests/fixtures/bubbles.json`：涵蓋五種對話框的測試設定。
- `output/`：漫畫成品目錄，不納入 Git。

腳本與測試放在技能資料夾內，技能複製到各 Agent 的全域技能目錄後即可獨立運作。

## 對話框能力

JSON 支援下列 `type`：

- `speech`：一般漫畫對話框。
- `thought`：思考泡泡及圓點尾巴。
- `narration`：無尾巴旁白框。
- `shout`：放射狀強調框。
- `whisper`：虛線低語框。

可直接提供 `x`、`y`、`w`、`h`，也可省略座標並使用 `position` 自動定位。文字會自動換行與縮小字級；對話框超出面板、彼此重疊或設定錯誤時，腳本會停止並顯示原因。

## 使用方式

腳本是 Python（Pillow），跑在 `file-toolkit` 技能的共用環境裡。先取得直譯器路徑：

```powershell
$PY = & (Join-Path $HOME '.claude/skills/file-toolkit/scripts/ensure_env.ps1') | Select-Object -Last 1
```

先標準化原圖：

```powershell
& $PY "skills/comic-generator/scripts/normalize_comic.py" `
  --image-path "output/comic_point_1_raw.png" `
  --output-path "output/comic_point_1_normalized.png"
```

再加入對話框：

```powershell
& $PY "skills/comic-generator/scripts/add_captions_json.py" `
  --image-path "output/comic_point_1_normalized.png" `
  --output-path "output/comic_point_1_final.png" `
  --json-path "output/comic_point_1_bubbles.json"
```

執行自動測試：

```powershell
& $PY "skills/comic-generator/tests/test_captions.py"
```

在其他專案使用時，把上面的 `skills/comic-generator` 換成該 Agent 的全域技能路徑（例如 `~/.claude/skills/comic-generator`）。

## 平台支援

Windows 與 macOS 皆可（需要 pwsh 7 與 `file-toolkit` 的共用 Python 環境）。

畫圖層原本是 .NET 的 System.Drawing（GDI+），自 .NET 6 起只支援 Windows，在 macOS 上會丟 `PlatformNotSupportedException`；2026-09-20 改寫為 Pillow，兩個平台走同一條路。

中文字型依平台自動偵測（Windows 的 Microsoft JhengHei、macOS 的 PingFang、Linux 的 Noto Sans CJK）。找不到時會明確報錯而不是換成沒有中文字的預設字型——那會畫出一整排豆腐格且不報錯。要指定字型就設環境變數 `COMIC_FONT`（粗體另設 `COMIC_FONT_BOLD`；沒有真粗體時以描邊模擬）。
