# 交接檔（handoff.md）

## ⏯️ 目前做到哪

修掉對話框「框中框」問題：生圖模型畫出的空白對話框，後製腳本又在裡面畫一層框。`add_captions_json.ps1` 新增三個能力：

- `-TextOnly`：整張圖只排文字，不畫框線／底色／尾巴。
- `draw_bubble`（單筆 JSON 欄位）：單一對話框沿用底圖既有的框。
- `text_color`：文字顏色（名稱或 hex），文字要放在深色底（黑板、夜景）時用。

同時把 `comic-generator` 的畫風規則改成不限定：不再有固定風格清單，改由使用者指定，或臨場依教材主題提 4-6 個選項。

## 🚦 目前狀態

- `tests/test_captions.ps1` 全通過，已新增 text-only 回歸測試（比對與底圖的像素差異，確認沒有畫出框形）。
- 1-1-1、1-1-2 的 `output/*_final.png` 都已重出並覆蓋，中間版本檔已清掉。
- `output/` 在 `.gitignore` 內，圖片與 JSON 只存在本機，不會進 GitHub。

## ➡️ 下一步

1. `output/comic_1-1-2_point_1_bubbles.json` 在收工前被改過（四格都改成 `speech` + `draw_bubble: false`，第三格移到 x80/y50/w350/h105 且拿掉 `text_color`），但 `_final.png` 還是舊 JSON 的產物。要用新設定就重跑一次 `add_captions_json.ps1 -Force`；注意第三格新位置會壓到黑板，黑字可能看不清楚。
2. 生圖品質確認：目前 raw 圖極可能是 `claude-draw` 預設的 `low`（1024×1536 符合該技能直式預設，但專案沒留指令紀錄、PNG 也無 metadata）。若要提升，先用 `medium` 生一張 1-1-1 對比再決定是否整批重來。
3. 繼續以教材內容驗證四格漫畫工作流。

## ⚠️ 注意事項

- 底圖已有對話框時務必用 `-TextOnly` 或 `draw_bubble: false`，否則必定出現框中框。
- 底圖沒有留白可放旁白時，不要硬加旁白框；優先把文字放進畫面既有載體（黑板、招牌、螢幕），深色底搭配 `text_color`。
- 對話框內距上限改為隨矩形比例縮放，薄的文字區才不會被固定內距吃光。已驗證 1-1-1 重跑結果與改動前位元相同。
- 不可覆寫原始生圖；衍生檔使用 `_normalized`、`_final` 後綴。
- 不儲存學生真名或其他敏感資料。

## 🕐 最後更新

- 時間：2026-07-23 23:13
- 更新者：Claude Code (Opus 4.8) @ PC-YI-FY
- Git push：✅ 已推（`62ee6c9`）
