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

輸入與輸出不可使用同一個檔案。若要替換已存在的衍生檔案，需明確加上 `-Force`。

## 目錄結構

- `agents.md`：跨 Agent 專案規範與工作守則。
- `skills/comic-generator/SKILL.md`：教材四格漫畫生成工作流。
- `scripts/normalize_comic.ps1`：將圖片標準化為 4:5、1080×1350。
- `scripts/add_captions_json.ps1`：驗證 JSON 並加入多個中文對話框。
- `tests/test_captions.ps1`：自動測試標準化、文字後製及安全檢查。
- `tests/fixtures/bubbles.json`：涵蓋五種對話框的測試設定。
- `output/`：漫畫成品目錄，不納入 Git。

## 對話框能力

JSON 支援下列 `type`：

- `speech`：一般漫畫對話框。
- `thought`：思考泡泡及圓點尾巴。
- `narration`：無尾巴旁白框。
- `shout`：放射狀強調框。
- `whisper`：虛線低語框。

可直接提供 `x`、`y`、`w`、`h`，也可省略座標並使用 `position` 自動定位。文字會自動換行與縮小字級；對話框超出面板、彼此重疊或設定錯誤時，腳本會停止並顯示原因。

## 使用方式

先標準化原圖：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "scripts/normalize_comic.ps1" `
  -imagePath "output/comic_point_1_raw.png" `
  -outputPath "output/comic_point_1_normalized.png"
```

再加入對話框：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "scripts/add_captions_json.ps1" `
  -imagePath "output/comic_point_1_normalized.png" `
  -outputPath "output/comic_point_1_final.png" `
  -jsonPath "output/comic_point_1_bubbles.json"
```

執行自動測試：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "tests/test_captions.ps1"
```
