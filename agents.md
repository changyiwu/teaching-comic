# teaching-comic（跨 Agent 專案規則）

> 本檔是不同 Agent 共用的專案入口。

## 專案入口

- 專案名稱：`teaching-comic`
- 專案用途：製作教學用漫畫。
- 主要工作目錄：`C:\Users\chang\我的雲端硬碟\agents\teaching-comic`
- GitHub repo：<https://github.com/changyiwu/teaching-comic>
- 預設分支：`main`

## Obsidian 對應筆記

- Vault：`C:\Users\chang\我的雲端硬碟\2ndbrain`
- 專案筆記：`teaching-comic/專案工作流程.md`

## 專案 Skill

- `comic-generator`：當使用者提供教材路徑或內容時，引導其選擇漫畫風格，再把教材重點轉為直式 4:5、2×2 四格漫畫。
- 工作流固定保留 `raw → normalized → final` 三個階段，並透過 JSON 配置中文對話框。
- 詳細規則：`skills/comic-generator/SKILL.md`。使用前必須先完整閱讀該檔。

## 工作規則

- 回應與文件使用繁體中文。
- 涉及檔案操作時回報完整產出位置。
- Windows 指令優先使用 PowerShell 語法。
- 開工時讀取本檔、`handoff.md` 與 Obsidian 專案筆記，並檢查 Git 狀態。
- 收工時更新 Obsidian 專案筆記，檢查 diff，且只提交本次任務相關檔案。
- 修改圖片標準化或對話框程式後，執行 `tests/test_captions.ps1`。
- 原始生圖不可被後製腳本覆寫；衍生檔案使用 `_normalized` 與 `_final` 後綴。
- 不把每日流水帳寫進本檔。

## 安全與隱私

- 不要 commit API key、token、密碼或 Firebase Admin 憑證。
- 不要 commit NotebookLM 個人匯出清單或筆記本 ID 清單。
- 不要自動納入無關的 Git 變更。
- 不要儲存學生真名；正式資料只使用班級代號與座號。

## 最近進度

- 2026-07-22：將四格教學漫畫工作規則整合為跨 Agent `agents.md`，移除舊規則檔並同步 README。
