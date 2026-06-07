---
name: comic-generator
description: >
  教材四格漫畫生成技能。當使用者提供教材檔案路徑或直接貼上教材內容時，
  分析教材並整理出核心重點。每一個重點製作一個四格漫畫（一個重點一張圖），
  引導使用者選擇漫畫風格後，調用生圖工具生成 2x2 四格漫畫圖片，
  並將漫畫圖片輸出至專案根目錄的 `output/` 資料夾。
  當使用者說「整理教材做漫畫」、「教材生四格漫畫」、「幫我把這份教材做成漫畫」時，
  請使用此技能。
---

# 教材四格漫畫生成工作流 (comic-generator)

本技能旨在將枯燥的教材內容，轉化為易於理解、生動有趣的**四格漫畫**。一個學習重點對應一張 4 格漫畫，幫助學生快速吸收核心概念。

---

## 適用情境
- 課堂教學投影片輔助插圖
- 教科書/講義重點視覺化
- 課後複習圖卡

---

## 輸入規範
使用者需提供：
- **教材內容**：教材檔案路徑（如 `.txt`、`.md`）或直接輸入的教材段落文字。
- **風格選擇**：提供以下風格清單供選擇，亦支援自訂風格：
  1. **日系黑白漫畫 (Japanese B&W Manga)**：網點、速度線、高對比、傳統日漫風格。
  2. **美式英雄漫畫 (American Superhero Comic)**：粗輪廓線、鮮明色彩、美式連環漫畫網格。
  3. **可愛 Q 版卡通 (Cute Chibi/Anime)**：萌系人物比例、明亮溫馨、適合國中小學生。
  4. **皮克斯 3D 卡通 (Pixar-style 3D)**：溫暖光影、黏土質感、精緻的立體 3D 卡通角色。
  5. **復古手繪插畫 (Retro Hand-drawn)**：水彩渲染、鉛筆筆觸、經典繪本風。

---

## 必守的設計與生圖憲法

### A. 一個重點一張圖
- 避免把多個不相關的重點塞進同一個四格漫畫。
- 每個重點設計的四格漫畫，其情節必須緊扣該重點的教學目標。

### B. 四格漫畫 (2x2 Grid) 拼圖提示詞
為了讓生圖工具能在一張圖中產生合理的四格漫畫，Prompt 必須嚴格遵守以下格式：
- **結構關鍵字**：`4-panel comic strip, 2x2 grid layout, sequential panels, storyboarding`
- **內容描述**：按順序描述 4 個格子的內容（如：`Panel 1: ...; Panel 2: ...; Panel 3: ...; Panel 4: ...`）。
- **文字控制**：必須加入 `no readable text, no speech bubbles, no text`（避免生圖工具產生亂碼英文字或歪斜對話框。對白與旁白建議由 AI 在 Markdown 中以文字標註在圖片下方，或引導使用者後製）。
- **風格一致性**：風格描述必須寫在 Prompt 的最前面。例如：`[Style Choice], 4-panel comic strip of [character/scene description]...`

### C. 檔案命名與輸出
- 圖片統一輸出至專案根目錄的 `output/` 資料夾下。
- 命名規則：`comic_point_1.png`，`comic_point_2.png`，依此類推。

---

## 執行流程

### 第 1 步：讀取教材與整理重點
1. 讀取使用者給予的路徑檔案或文字內容。
2. 提取出 **1 ~ 5 個核心教學重點**（不宜過多，以免流於流水帳）。
3. 輸出重點清單，並列出**風格選擇清單**，等待使用者確認重點並選擇風格。

### 第 2 步：設計四格漫畫分鏡與情節
在使用者選定風格後，為每個重點設計一個四格漫畫的情節大綱：
- **第一格 (起)**：引入情境或帶出問題。
- **第二格 (承)**：探討問題或展開解釋。
- **第三格 (轉)**：重點概念的轉折或關鍵動作演示。
- **第四格 (合)**：得出結論、趣味結局或核心重點的視覺呈現。
- **對話與旁白規劃**：為每一格寫出對應的台詞或旁白（稍後將呈現在圖片下方的說明中）。

### 第 3 步：調用 `generate_image` 生成圖片
1. 將設計好的分鏡與風格轉化為高質量的英文 Prompt。
2. 對每個重點平行呼叫 `generate_image` 產生圖片：
   - 參數設定：`ImageName` 設為 `comic_point_x`。
   - Prompt 範本：
     ```text
     [ выбранный стиль ], 4-panel comic strip, 2x2 grid layout, sequential panels, storyboarding.
     Panel 1: [情境1]. Panel 2: [情境2]. Panel 3: [情境3]. Panel 4: [情境4].
     Consistent character design, vibrant colors, clean lines, no readable text, no speech bubbles.
     ```
3. 儲存圖片至 `output/`。

### 第 4 步：展示結果與更新駕駛艙
1. 在對話中以 Markdown 格式嵌入圖片 `![重點 X：[重點標題]](file:///c:/Users/chang/我的雲端硬碟/agents/antigravity/teaching-comic/output/comic_point_x.png)`。
2. 在圖片下方附上四格分鏡的詳細對話/旁白說明。
3. 更新 Obsidian 專案駕駛艙。
