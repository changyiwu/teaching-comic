---
name: comic-generator
description: >
  教材四格漫畫生成技能。當使用者提供教材檔案路徑或直接貼上教材內容時，
  分析教材並整理出核心重點。每一個重點製作一個四格漫畫（一個重點一張圖），
  引導使用者選擇漫畫風格後，調用生圖工具生成 2x2 四格漫畫圖片，
  隨後調用專案內置的 `scripts/add_captions.ps1` 自動為漫畫的 4 個面板後製中文對白與旁白文字框，
  並將漫畫圖片輸出至專案根目錄的 `output/` 資料夾。
  當使用者說「整理教材做漫畫」、「教材生四格漫畫」、「幫我把這份教材做成漫畫」時，
  請使用此技能。
---

# 教材四格漫畫生成工作流 (comic-generator)

本技能旨在將枯燥的教材內容，轉化為易於理解、生動有趣的**帶對白四格漫畫**。一個學習重點對應一張 4 格漫畫，並自動加上精美中文對白。

---

## 適用情境
- 課堂教學投影片輔助插圖
- 教科書/講義重點視覺化
- 課後複習圖卡

---

## 輸入規範
使用者需提供：
- **教材內容**：教材檔案路徑（如 `.txt`、`.md`、`.pdf`）或直接輸入的教材段落文字。
- **風格選擇**：提供以下風格清單供選擇，亦支援自訂風格：
  1. **日系黑白漫畫 (Japanese B&W Manga)**：網點、速度線、高對比、傳統日漫風格。
  2. **美式英雄漫畫 (American Superhero Comic)**：粗輪廓線、鮮明色彩、美式連環漫畫網格。
  3. **可愛 Q 版卡通 (Cute Chibi/Anime)**：萌系人物比例、明亮溫馨、適合國中小學生。
  4. **皮克斯 3D 卡通 (Pixar-style 3D)**：溫暖光影、黏土質感、精緻的立體 3D 卡通角色。
  5. **復古手繪插畫 (Retro Hand-drawn)**：水彩渲染、鉛筆筆觸、經典繪本風。
  6. **卡皮巴拉水豚風 (Capybara Style)**：以慢條斯理、療癒呆萌的水豚作為漫畫主角。

---

## 必守的設計與生圖憲法

### A. 一個重點一張圖
- 避免把多個不相關的重點塞進同一個四格漫畫。
- 每個重點設計的四格漫畫，其情節必須緊扣該重點的教學目標。

### B. 四格漫畫 (2x2 Grid) 拼圖提示詞
為了讓生圖工具能在一張圖中產生合理的四格漫畫，Prompt 必須格式化：
- **結構關鍵字**：`4-panel comic strip, 2x2 grid layout, sequential panels, storyboarding`
- **內容描述**：按順序描述 4 個格子的內容（如：`Panel 1: ...; Panel 2: ...; Panel 3: ...; Panel 4: ...`）。
- **文字控制**：必須加入 `no readable text, no speech bubbles, no text`（避免生圖工具產生亂碼英文字或歪斜對話框。對白由專案後製指令碼動態加入）。
- **風格一致性**：風格描述必須寫在 Prompt 的最前面。例如：`[Style Choice], 4-panel comic strip of [character/scene description]...`

### C. 檔案命名與輸出
- 圖片統一輸出至專案根目錄的 `output/` 資料夾下。
- 命名規則：`comic_point_1.png`，`comic_point_2.png`，依此類推。

---

## 執行流程

### 第 1 步：讀取教材與整理重點
1. 讀取使用者給予的路徑檔案或文字內容（若為 PDF 請執行 OCR 或提取文字）。
2. 提取出 **1 ~ 5 個核心教學重點**。
3. 輸出重點清單，並列出**風格選擇清單**，等待使用者確認重點並選擇風格。

### 第 2 步：設計四格漫畫分鏡與情節
在使用者選定風格後，為每個重點設計一個四格漫畫的情節大綱與各格對白：
- **第一格 (起)**：引入情境或帶出問題。
- **第二格 (承)**：探討問題或展開解釋。
- **第三格 (轉)**：重點概念的轉折或關鍵動作演示。
- **第四格 (合)**：得出結論、趣味結局或核心重點的視覺呈現。

### 第 3 步：調用 `generate_image` 生成原始圖片
1. 將設計好的分鏡與風格轉化為高質量的英文 Prompt。
2. 對每個重點平行呼叫 `generate_image` 產生圖片：
   - 參數設定：`ImageName` 設為 `comic_point_x`。
   - 原始生圖儲存於臨時路徑（如 Artifact 目錄）後，複製並命名為 `output/comic_point_x.png`。

### 第 4 步：調用 `scripts/add_captions.ps1` 後製中文對白（核心自動化步驟）
為了讓漫畫對白更清晰，呼叫專案內置的 PowerShell 指令碼，將對白文字以半透明背景框精美地繪製在 4 個面板下方：
1. 準備指令：
   ```powershell
   Powershell.exe -ExecutionPolicy Bypass -File "scripts/add_captions.ps1" `
     -imagePath "output/comic_point_x.png" `
     -outputPath "output/comic_point_x.png" `
     -text1 "「第一格對白內容」" `
     -text2 "「第二格對白內容」" `
     -text3 "「第三格對白內容」" `
     -text4 "「第四格對白內容」"
   ```
2. 注意事項：
   - 執行的 PowerShell 指令碼必須保存為 **帶 BOM 的 UTF-8** 編碼，以防止 Windows 環境下中文亂碼與引號語法解析錯誤。
   - 該指令碼已使用 `.tmp` 轉存機制，可避免 `System.Drawing` 讀寫同檔案時的 GDI+ 鎖定衝突。

### 第 5 步：展示結果與更新駕駛艙
1. 在對話中以 Markdown 格式嵌入已後製的圖片 `![重點 X：[重點標題]](file:///c:/Users/chang/我的雲端硬碟/agents/antigravity/teaching-comic/output/comic_point_x.png)`。
2. 在圖片下方附上四格分鏡的詳細對話/旁白說明。
3. 更新 Obsidian 專案駕駛艙。
