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
- [x] 階段五：技能自足化——`scripts/`、`tests/` 移入 `skills/comic-generator/`，並安裝到四個 Agent 的全域技能目錄
- [ ] 階段六：以更新後的 JSON 重跑 `1-1-2` 的 `_final.png`
- [ ] 階段七：確認生圖品質等級（目前疑為 `claude-draw` 預設 `low`），評估是否整批改用 `medium`
- [ ] 階段八：繼續以教材內容驗證四格漫畫工作流

## 資料夾結構

```
teaching-comic/
├─ skills/comic-generator/           # 核心 Skill（自足，可整包安裝到全域技能目錄）
│  ├─ SKILL.md                       # 使用前必須完整閱讀
│  ├─ scripts/                       # 後製腳本（含 add_captions_json.ps1）
│  └─ tests/test_captions.ps1        # 對話框回歸測試
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

## 三個檔案的職責（依「時效性」分家，不是依「詳細程度」）

| 檔案 | 時效 | 寫入方式 | 放什麼 |
|------|------|---------|--------|
| `handoff.md` | **只對下一個 session 有效**，過期即丟 | 每次收工整份重寫 | 做到哪、下一步、**這次**的暫時 workaround |
| `agents.md`（本檔） | **長期有效**，每個 session 都適用 | 只有規則本身變了才改 | 目標、路線圖、常設規則、結構 |
| Obsidian／`git log` | **歷史**：發生過什麼、為什麼 | 只增不刪 | 決策紀錄、踩坑完整版、逐次進度 |

驗收標準：**`handoff.md` 整份刪掉，不應損失任何長期資訊**——會的話代表該升級進本檔卻沒升級。

**本檔不要出現的東西**：❌ `## 最近進度`／逐次工作紀錄、❌ 決策理由與踩坑完整版。2026-08-03 移除了 `## 最近進度`，內容逐條比對後已在 L3 筆記的〈🗓️ 最近更動紀錄〉——**是主動移除，不是遺漏，不要補回來**。踩過的坑只把**結論**收斂成一條祈使句寫進〈工作約定〉，原因留 L3。

## 工作約定

- 任何 Agent、任何電腦：**開工先讀 `handoff.md`，收工必更新 `handoff.md`**
- 修改共用檔案前先讀最新內容，避免覆蓋其他 Agent 的變更
- 所有回應與文件使用繁體中文；涉及檔案操作時回報完整產出位置
- Windows 指令優先使用 PowerShell 語法
- 使用 `comic-generator` 前必須先完整閱讀 `skills/comic-generator/SKILL.md`
- 修改圖片標準化或對話框程式後，執行 `skills/comic-generator/tests/test_captions.ps1`
- 腳本只改本專案的原始檔，改完跑測試再用 `sync-skills` 同步；不要直接編輯全域技能副本
- **原始生圖不可被後製腳本覆寫**；衍生檔案使用 `_normalized` 與 `_final` 後綴
- 收工時更新 Obsidian 專案筆記，檢查 diff，且只提交本次任務相關檔案
- 不把每日流水帳寫進本檔
- 呼叫腳本前先跑 `SKILL.md` 第 0 步取得**絕對路徑**，不要沿用相對路徑

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
