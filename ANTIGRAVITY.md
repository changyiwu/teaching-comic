# teaching-comic - ANTIGRAVITY.md

## 專案入口

專案名稱：teaching-comic
專案用途：製作教學用的漫畫
主要工作目錄：c:\Users\chang\我的雲端硬碟\agents\antigravity\teaching-comic
GitHub repo：https://github.com/changyiwu/teaching-comic
預設 branch：main

## Obsidian 對應筆記

Obsidian vault：c:\Users\chang\我的雲端硬碟\2ndbrain
專案駕駛艙：c:\Users\chang\我的雲端硬碟\2ndbrain\teaching-comic-專案駕駛艙.md

## 專案技能

- **教材四格漫畫生成 (comic-generator)**：當使用者輸入教材路徑或內容時，引導其選擇漫畫風格，隨後將教材重點轉化為 2x2 四格漫畫生圖，並儲存至 `output/` 目錄。詳細規則參閱 [SKILL.md](file:///c:/Users/chang/我的雲端硬碟/agents/antigravity/teaching-comic/skills/comic-generator/SKILL.md)。

## 工作規則

- 回應使用繁體中文。
- 涉及檔案操作時回報完整產出位置。
- 使用 PowerShell 語法。
- 開工時讀本檔、讀 Obsidian 駕駛艙、檢查 Git 狀態。
- 收工時更新 Obsidian，必要時更新本檔，檢查 diff 後只提交相關檔案。
- 不把每日流水帳寫進本檔。

## 不要做

- 不要 commit API key、token、密碼、Firebase Admin 憑證。
- 不要 commit NotebookLM 個人匯出清單或筆記本 ID 清單。
- 不要自動納入無關 git 變更。
- 不要儲存學生真名；正式資料只用班級代號與座號。
