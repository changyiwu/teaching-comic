---
name: comic-generator
description: >
  教材四格漫畫生成技能。當使用者提供教材檔案或教材文字時，整理 1 到 5 個核心重點，
  為每個重點生成一張直式 4:5、2x2 四格漫畫，對話泡由生圖階段畫出，再依 JSON 設定把中文排進泡裡。
  工作流固定保留 raw、normalized、final 三階段，避免覆寫原始生圖。
  當使用者說「整理教材做漫畫」、「教材生四格漫畫」或「把教材做成漫畫」時使用。
---

# 教材四格漫畫生成工作流

一個教學重點對應一張四格漫畫。圖片適合在手機與電腦閱讀。

**職責分工：對話泡的外觀一律由生圖技能畫出，本技能只負責把中文排進泡裡。** 生圖階段要畫出空白的對話泡（含思考、低語、大聲、一般等不同型式），後製腳本預設只排文字，不畫任何框線、底色或尾巴。

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
- 生圖提示必須要求畫出空白對話泡，同時禁止任何文字：
  `empty blank speech balloons with clean white interior, no text, no letters, no lettering, no captions, no labels, no watermark`
- 對話泡不可遮擋主角臉部與核心教材圖示。

### 對話泡由生圖階段畫出

四種型式在生圖提示裡逐格指定，讓每個泡的外觀一眼可辨：

| 型式 | 用途 | 生圖關鍵字 |
|---|---|---|
| 一般 | 平常說話 | `oval speech balloon with a short curved tail pointing at the speaker` |
| 思考 | 心中想法 | `cloud-shaped thought balloon with a trail of small circles toward the speaker` |
| 低語 | 小聲、私語 | `speech balloon with a dashed broken outline and a thin wavy tail` |
| 大聲 | 驚訝、強調 | `jagged spiky burst balloon with sharp radiating edges` |
| 旁白 | 說明、結論 | `plain rectangular caption box in the panel corner` |

規格：

- 每格 1 到 2 個泡，最多 2 個，避免畫面被泡塞滿。
- 每個泡的**內部空白**至少 200×90 像素（以 540×675 的單格為基準），中文才排得下；`shout` 因為邊緣是鋸齒，內部空白要再大一圈。
- 泡的內部必須是乾淨的純色（白或淺色），不可有紋理、漸層或殘留的假文字塗鴉。
- 泡的位置與尾巴方向要對準該格說話者，並在第 2 步的分鏡就先決定。

### 檔案階段

每個重點固定使用以下命名：

1. `output/comic_point_x_raw.png`：含空白對話泡、無文字的原圖。
2. `output/comic_point_x_normalized.png`：標準化後的 1080×1350 圖片。
3. `output/comic_point_x_bubbles.json`：文字排版設定（座標對齊底圖泡的內緣）。
4. `output/comic_point_x_final.png`：最終成品。

不可把輸入與輸出設成同一個檔案。不可直接在 `_raw.png` 上加入文字。

## 執行流程

### 第 0 步：定位技能目錄

腳本與技能檔放在一起，可能在專案裡，也可能在某個 Agent 的全域技能目錄。開工先跑一次，取得絕對路徑：

```powershell
$candidates = @(
  (Join-Path (Get-Location).Path 'skills\comic-generator'),
  "$HOME\.claude\skills\comic-generator",
  "$HOME\.agents\skills\comic-generator",
  "$HOME\.config\opencode\skills\comic-generator",
  "$HOME\.gemini\config\skills\comic-generator"
)
$skillDir = $candidates | Where-Object { Test-Path (Join-Path $_ 'scripts\normalize_comic.ps1') } | Select-Object -First 1
if (-not $skillDir) { throw '找不到 comic-generator 的 scripts 目錄' }
$skillDir
```

把印出的路徑記下來，後面所有指令中的 `<SKILL_DIR>` 都直接換成這個絕對路徑（PowerShell 每次呼叫是獨立行程，變數不會留到下一個指令）。

`output/` 一律相對於使用者當下的工作目錄，不要寫進技能目錄。

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

每句對白同時決定三件事，全部要寫進生圖提示：

1. 泡的型式：一般、思考、低語、大聲、旁白。
2. 泡在該格的位置（例如左上、右上）。
3. 說話者在該格的位置，尾巴要指向他。

### 第 3 步：生成含空白對話泡的原圖

1. 使用可用的生圖工具生成直式 4:5、2x2 四格漫畫。
2. 生圖提示逐格寫明每個泡的型式、位置與尾巴指向，並沿用〈對話泡由生圖階段畫出〉的關鍵字。
3. 泡必須是空的：不要求生圖模型產生任何中文或英文，畫面上不可出現文字、假字或塗鴉。
4. 原圖保存為 `output/comic_point_x_raw.png`。
5. 若生出來的泡太小、內部有雜訊、或型式不對，重生原圖，不要靠後製補框。

### 第 4 步：標準化為 1080×1350

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\normalize_comic.ps1" `
  -imagePath "output/comic_point_x_raw.png" `
  -outputPath "output/comic_point_x_normalized.png"
```

預設使用置中裁切。若不希望裁切，可加上 `-fit letterbox`；只有明確接受變形時才使用 `-fit stretch`。

### 第 5 步：建立文字排版 JSON

泡已經畫在底圖上，所以 JSON 的座標一律從 `_normalized.png` **實際量測泡的內緣**，不使用 `position` 自動定位（自動定位算的是腳本自己的框，會和底圖的泡對不上）。

手動設定範例：

```json
[
  {
    "panel": 1,
    "type": "speech",
    "x": 45,
    "y": 30,
    "w": 280,
    "h": 125,
    "text": "這個問題該怎麼解決呢？"
  },
  {
    "panel": 2,
    "type": "thought",
    "x": 250,
    "y": 40,
    "w": 250,
    "h": 110,
    "text": "讓我先想一想……"
  }
]
```

座標以各面板左上角為原點；每格範圍為寬 540、高 675。`x`、`y`、`w`、`h` 是泡的**純文字區**，要略小於泡的內緣，避免文字壓到鋸齒或虛線邊。

`type` 在此模式下只影響文字樣式與內距，不會畫出任何框線或尾巴：

| type | 對應底圖的泡 | 文字樣式 |
|---|---|---|
| `speech` | 一般橢圓泡 | 一般字重 |
| `thought` | 雲朵狀思考泡 | 一般字重，內距略大 |
| `narration` | 方形旁白框 | 一般字重 |
| `shout` | 鋸齒爆炸泡 | 粗體強調 |
| `whisper` | 虛線泡 | 較小字級 |

選用欄位：

- `font_size`：偏好的最大字級。
- `min_font_size`：允許縮小的最小字級，預設 12。
- `text_color`：文字顏色，可用名稱（`white`）或十六進位（`#FFFFFF`），預設黑色。泡是深色底、或文字要放進黑板等深色載體時使用。

腳本會自動檢查：面板編號、必要欄位、座標範圍、區塊重疊及文字是否能放入。文字會自動換行並逐級縮小。

`speaker_x`、`speaker_y`、`position`、`draw_bubble` 這些欄位只在腳本自己畫框（`-DrawBubbles`）時才有意義，本工作流不使用。

### 第 6 步：輸出最終漫畫

預設就是只排文字，不必加任何旗標：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\add_captions_json.ps1" `
  -imagePath "output/comic_point_x_normalized.png" `
  -outputPath "output/comic_point_x_final.png" `
  -jsonPath "output/comic_point_x_bubbles.json"
```

若最終檔案已存在且使用者確定要替換，加入 `-Force`。只有刻意需要重疊時才加入 `-AllowOverlap`。

#### 底圖的泡不堪用時

不要用腳本補畫框，回第 3 步重生原圖。腳本仍保留繪框能力（`-DrawBubbles`，或個別筆設 `"draw_bubble": true`），但只當作生圖反覆失敗時的臨時退路，不是預設流程；此時 `speaker_x`、`speaker_y`、`position` 這些欄位才會生效。

例外只有一種：**畫面沒有留白可放旁白時，不要硬加旁白框**。優先把文字放進畫面既有的載體（黑板、招牌、螢幕、便條），並用 `text_color` 配合底色（深色底用白字）。

### 第 7 步：檢查與展示

1. 確認輸出為 1080×1350。
2. 檢查中文是否完整、字級是否適合手機閱讀。
3. 檢查文字都落在泡的內部，沒有壓到邊、也沒有溢出。
4. 檢查泡的型式與對白語氣相符（思考、低語、大聲、一般、旁白）。
5. 檢查泡沒有遮住主角臉部或核心教材圖示。
6. 檢查沒有出現「框中框」；若有，代表誤加了 `-DrawBubbles`。
7. 使用新的檔名展示修訂版，避免介面沿用舊圖片快取。
8. 在對話中嵌入 `output/comic_point_x_final.png`。

## 修改程式後的測試

修改 `normalize_comic.ps1` 或 `add_captions_json.ps1` 後必須執行：

```powershell
Powershell.exe -ExecutionPolicy Bypass -File "<SKILL_DIR>\tests\test_captions.ps1"
```

程式只該在 `teaching-comic` 專案的原始檔改，改完跑測試，再用 `sync-skills` 同步到各 Agent 的全域技能目錄；不要直接編輯全域副本。

測試涵蓋：4:5 標準化、五種對話框、長文字自動縮放、預設不繪框、`-DrawBubbles` 退路、JSON 驗證、禁止覆寫原圖、黑色區塊回歸及暫存檔清理。
