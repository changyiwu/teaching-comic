# 交接檔（handoff.md）

## ⏯️ 目前做到哪

已將四格教學漫畫的 Skill、輸出階段、測試與隱私規則整合為跨 Agent `agents.md`，刪除舊規則檔並同步 README。

## 🚦 目前狀態

- 本次沒有修改圖片後製或對話框程式，因此未重跑 caption 測試。
- `raw → normalized → final` 三階段規則已保留。

## ➡️ 下一步

1. 下次修改圖片標準化或對話框程式後執行 `tests/test_captions.ps1`。
2. 繼續以教材內容驗證四格漫畫工作流。

## ⚠️ 注意事項

- 不可覆寫原始生圖；衍生檔使用 `_normalized`、`_final` 後綴。
- 不儲存學生真名或其他敏感資料。

## 🕐 最後更新

- 時間：2026-07-22 14:29
- 更新者：Codex @ PC-YI-FY
- Git push：⬜ 待推
