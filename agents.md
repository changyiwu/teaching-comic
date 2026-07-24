# teaching-comic（專案藍圖）

> 本檔為跨 Agent 通用的專案藍圖（AGENTS.md 開放標準）。任何 Agent 的每個 session 都應先讀本檔＋`handoff.md`。

## 專案簡介

製作教學用漫畫。核心是 `comic-generator` Skill：使用者提供教材路徑或內容後，引導選擇漫畫風格，再把教材重點轉為直式 4:5、2×2 的四格漫畫。工作流固定保留 `raw → normalized → final` 三個階段，並透過 JSON 配置中文對話框。

被 `teaching-web` 專案固定調用來產生課前暖身漫畫。

## 關鍵時程

<!-- 目前無固定時程 -->

## 目標與路線圖

- [x] 階段一：`comic-generator` Skill 與 `raw → normalized → final` 三階段工作流成形
- [x] 階段二：規則整合為跨 Agent `agents.md`，移除舊規則檔並同步 README
- [x] 階段三：修掉「框中框」問題——`add_captions_json.ps1` 新增 `-TextOnly`、`draw_bubble`、`text_color` 三個能力
- [x] 階段四：畫風規則改為不限定（由使用者指定，或臨場依教材主題提 4-6 個選項）
- [ ] 階段五：以更新後的 JSON 重跑 `1-1-2` 的 `_final.png`
- [ ] 階段六：確認生圖品質等級（目前疑為 `claude-draw` 預設 `low`），評估是否整批改用 `medium`
- [ ] 階段七：繼續以教材內容驗證四格漫畫工作流

## 資料夾結構

```
teaching-comic/
├─ skills/comic-generator/SKILL.md   # 核心 Skill（使用前必須完整閱讀）
├─ scripts/                          # 後製腳本（含 add_captions_json.ps1）
├─ tests/test_captions.ps1           # 對話框回歸測試
├─ output/                           # 生圖與後製產物（.gitignore 排除，只存本機）
├─ README.md
├─ agents.md                         # 本檔：專案藍圖
├─ handoff.md                        # 交接檔（每次收工必更新）
├─ .agents/  .gitignore
```

## 同步層級（本專案初始化至第 3 層級）

| 層級 | 平台 | 位置 | 讀取時機 |
|------|------|------|---------|
| L1 | 本地（GDrive） | `agents.md`＋`handoff.md` | 每個 session |
| L2 | GitHub | https://github.com/changyiwu/teaching-comic （公開，預設分支 `main`） | 指定時 |
| L3 | Obsidian | `teaching-comic/專案工作流程.md` | 有需要時 |

## 工作約定

- 任何 Agent、任何電腦：**開工先讀 `handoff.md`，收工必更新 `handoff.md`**
- 修改共用檔案前先讀最新內容，避免覆蓋其他 Agent 的變更
- 所有回應與文件使用繁體中文；涉及檔案操作時回報完整產出位置
- Windows 指令優先使用 PowerShell 語法
- 使用 `comic-generator` 前必須先完整閱讀 `skills/comic-generator/SKILL.md`
- 修改圖片標準化或對話框程式後，執行 `tests/test_captions.ps1`
- **原始生圖不可被後製腳本覆寫**；衍生檔案使用 `_normalized` 與 `_final` 後綴
- 收工時更新 Obsidian 專案筆記，檢查 diff，且只提交本次任務相關檔案
- 不把每日流水帳寫進本檔

## 對話框製作規則

- 底圖已有對話框時務必用 `-TextOnly` 或 `draw_bubble: false`，否則必定出現框中框
- 底圖沒有留白可放旁白時，不要硬加旁白框；優先把文字放進畫面既有載體（黑板、招牌、螢幕），深色底搭配 `text_color`
- 對話框內距上限隨矩形比例縮放，薄的文字區才不會被固定內距吃光
- 對白座標一律從實際的 `_normalized.png` 量測

## 安全與隱私

- 不要 commit API key、token、密碼或 Firebase Admin 憑證
- 不要 commit NotebookLM 個人匯出清單或筆記本 ID 清單
- 不要自動納入無關的 Git 變更
- 不要儲存學生真名；正式資料只使用班級代號與座號

## 最近進度

- 2026-07-22：將四格教學漫畫工作規則整合為跨 Agent `agents.md`，移除舊規則檔並同步 README。
- 2026-07-23：修掉「框中框」問題（底圖已有對話框時腳本又畫一層），`add_captions_json.ps1` 新增 `-TextOnly`、`draw_bubble`、`text_color`；`comic-generator` 改為不限定畫風。
- 2026-07-24：專案藍圖改用標準範本格式（補上路線圖 checklist、資料夾結構與同步層級表）。
