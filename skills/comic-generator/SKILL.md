---
name: comic-generator
description: >
  教材四格漫畫生成技能。當使用者提供教材檔案或教材文字時，整理 1 到 5 個核心重點，
  為每個重點生成一張直式 4:5、2x2 四格漫畫，再依 JSON 設定加入可讀的中文對話框。
  工作流固定保留 raw、normalized、final 三階段，避免覆寫原始生圖。
  當使用者說「整理教材做漫畫」、「教材生四格漫畫」或「把教材做成漫畫」時使用。
---

# 教材四格漫畫生成工作流

一個教學重點對應一張四格漫畫。圖片適合在手機與電腦閱讀，生圖階段不產生文字，中文對白統一在後製階段加入。

## 輸入

- 教材檔案：`.txt`、`.md`、`.pdf`，或直接貼上的教材內容。
- 漫畫風格：不預設、不限定任何固定風格。

風格決定方式：

1. 使用者已指定風格（含自備參考圖、既有角色設定、指定畫風關鍵字）：直接照用，不改寫。
2. 使用者未指定：依教材主題、學習者年齡與情境，臨場提出 4 到 6 個彼此差異明顯的風格選項，附一句話說明適合原因，並保留「其他／我自己描述」選項，等使用者選定後才生圖。

風格選單每次重新設計，不沿用固定清單；可跨繪本、漫畫、插畫、3D、寫實、資訊圖等任何方向。選定後把該風格的關鍵字固定寫進生圖提示，同一套教材的多張漫畫維持同一風格與同一主角設定。

## 必守規格

### 一個重點一張圖

- 每張四格漫畫只處理一個核心教學目標。
- 四格依序呈現「起、承、轉、合」。
- 不把不相關的概念塞入同一張圖。

### 圖片比例與分格

- 畫布固定為直式 4:5。
- 標準輸出為 `1080x1350`。
- 使用 2x2 四格，每格為 `540x675`。
- 生圖提示必須包含：
  `portrait 4:5, 4-panel comic strip, 2x2 grid layout, equal-sized panels, sequential panels, storyboarding`
- 生圖提示必須禁止文字：
  `no readable text, no speech bubbles, no captions, no labels, no watermark`
- 每格預留不遮擋主角的對話框空間。

### 檔案階段

每個重點固定使用以下命名：

1. `output/comic_point_x_raw.png`：無文字原圖。
2. `output/comic_point_x_normalized.png`：標準化後的 1080×1350 圖片。
3. `output/comic_point_x_bubbles.json`：對話框設定。
4. `output/comic_point_x_final.png`：最終成品。

不可把輸入與輸出設成同一個檔案。不可直接在 `_raw.png` 上加入文字。

## 執行流程

### 第 1 步：整理教材重點

1. 讀取教材內容；PDF 優先提取文字，掃描型 PDF 才使用 OCR。
2. 提取 1 到 5 個核心教學重點。
3. 顯示重點及風格選單，等待使用者確認。

### 第 2 步：設計分鏡與對白

每個重點設計四格：

- 第一格：引入問題。
- 第二格：探索或解釋。
- 第三格：呈現關鍵轉折。
- 第四格：形成結論或記憶點。

同時記錄每句對白的說話者位置，後續轉成 `speaker_x`、`speaker_y`。

### 第 3 步：生成無文字原圖

1. 使用可用的生圖工具生成直式 4:5、2x2 四格漫畫。
2. 原圖保存為 `output/comic_point_x_raw.png`。
3. 不在此階段要求生圖模型產生中文或對話框。

### 第 4 步：標準化為 1080×1350

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "scripts/normalize_comic.ps1" `
  -imagePath "output/comic_point_x_raw.png" `
  -outputPath "output/comic_point_x_normalized.png"
```

預設使用置中裁切。若不希望裁切，可加上 `-fit letterbox`；只有明確接受變形時才使用 `-fit stretch`。

### 第 5 步：建立對話框 JSON

完整手動設定範例：

```json
[
  {
    "panel": 1,
    "type": "speech",
    "x": 45,
    "y": 30,
    "w": 280,
    "h": 125,
    "text": "這個問題該怎麼解決呢？",
    "speaker_x": 210,
    "speaker_y": 390
  }
]
```

自動定位範例：

```json
[
  {
    "panel": 2,
    "type": "thought",
    "position": "top-right",
    "text": "讓我先想一想……",
    "speaker_x": 280,
    "speaker_y": 430
  },
  {
    "panel": 4,
    "type": "narration",
    "position": "bottom-center",
    "text": "最後，我們得到答案。"
  }
]
```

座標以各面板左上角為原點；每格範圍為寬 540、高 675。

可用 `type`：

| type | 用途 | 尾巴 |
|---|---|---|
| `speech` | 一般對話 | 短小彎曲漫畫尾巴 |
| `thought` | 心中想法 | 三個圓點 |
| `narration` | 旁白或說明 | 無尾巴 |
| `shout` | 驚訝、強調 | 放射框，可指定說話者 |
| `whisper` | 低語 | 虛線框與彎曲尾巴 |

自動定位可用：`top-left`、`top-center`、`top-right`、`center-left`、`center`、`center-right`、`bottom-left`、`bottom-center`、`bottom-right`。

選用欄位：

- `w`、`h`：省略時依類型使用預設尺寸。
- `font_size`：偏好的最大字級。
- `min_font_size`：允許縮小的最小字級，預設 12。
- `speaker_x`、`speaker_y`：說話者位置，建議取代舊的 `tail_x`、`tail_y`。
- `draw_bubble`：設為 `false` 時只畫文字，不畫框線、底色與尾巴。用於底圖已經有現成對話框的情況。關閉框線後 `w`、`h` 就是純文字區，可以比對話框更薄（最小 40×24）。
- `text_color`：文字顏色，可用名稱（`white`）或十六進位（`#FFFFFF`），預設黑色。文字要放在深色底（例如黑板、夜景）時使用。

腳本會自動檢查：面板編號、必要欄位、座標範圍、對話框重疊、尾巴位置及文字是否能放入。文字會自動換行並逐級縮小。

### 第 6 步：輸出最終漫畫

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "scripts/add_captions_json.ps1" `
  -imagePath "output/comic_point_x_normalized.png" `
  -outputPath "output/comic_point_x_final.png" `
  -jsonPath "output/comic_point_x_bubbles.json"
```

若最終檔案已存在且使用者確定要替換，加入 `-Force`。只有刻意需要重疊時才加入 `-AllowOverlap`。

#### 底圖已經有空白對話框時

生圖模型有時仍會畫出空白對話框。此時再讓腳本畫一次框，就會出現「框中框」。

處理原則：

- 底圖已有可用的空白對話框：加上 `-TextOnly`，只把文字排進既有對話框；`x`、`y`、`w`、`h` 對齊底圖對話框的內緣。
- 只有部分對話框需要沿用底圖：在該筆 JSON 加 `"draw_bubble": false`，其餘維持腳本繪製。
- 底圖完全沒有對話框：維持預設，由腳本繪製框線與尾巴。
- 底圖沒有留白可放旁白：不要硬加一個旁白框。優先把文字放進畫面既有的載體（黑板、招牌、螢幕、便條），並用 `text_color` 配合底色（深色底用白字）。

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "scripts/add_captions_json.ps1" `
  -imagePath "output/comic_point_x_normalized.png" `
  -outputPath "output/comic_point_x_final.png" `
  -jsonPath "output/comic_point_x_bubbles.json" `
  -TextOnly
```

`-TextOnly` 模式下 `type` 只影響文字樣式與內距，不再畫出任何框線或尾巴。

### 第 7 步：檢查與展示

1. 確認輸出為 1080×1350。
2. 檢查中文是否完整、字級是否適合手機閱讀。
3. 檢查對話框沒有遮住主角或核心教材圖示。
4. 檢查對話框沒有出現「框中框」；若有，改用 `-TextOnly` 或 `"draw_bubble": false` 重新輸出。
4. 使用新的檔名展示修訂版，避免介面沿用舊圖片快取。
5. 在對話中嵌入 `output/comic_point_x_final.png`。

## 修改程式後的測試

修改 `normalize_comic.ps1` 或 `add_captions_json.ps1` 後必須執行：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "tests/test_captions.ps1"
```

測試涵蓋：4:5 標準化、五種對話框、長文字自動縮放、JSON 驗證、禁止覆寫原圖、黑色區塊回歸及暫存檔清理。
