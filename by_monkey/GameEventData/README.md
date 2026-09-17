# 遊戲交談事件資料包 v1

這是一套已定義格式的 JSON、範例、Schema 與 Swift Codable 參考模型，供 Claude 整合現有 UIKit 專案。不是已接線的事件引擎或 UI 套件；不包含圖片。加入 JSON 後，仍需程式實作判定、讀取、存檔與播放。

## 先看這裡

- `Resources/characters.json`：共用角色與立繪（schemaVersion 1）。
- `Resources/events_work.json`：一人、兩人、三人三個完整事件（schemaVersion 2；v2 移除了 `repeatable`，見下）。
- `Resources/event_rules.json`：正式觸發設定；四種行動預設全部關閉，尚未決定正式機率（schemaVersion 1）。
- `Development/event_rules_debug.json`：開發專用；打工 100% 觸發，從符合資格的範例中等權重選一個。不是每個事件都播放；已經觸發過的事件不會再進候選（見下）。
- `Examples/event_template.json`：可複製的新事件範本，預設停用。
- `Examples/save_*.json`：同一個存檔在不同時間的獨立示例，不能合併或當成真實玩家存檔（schemaVersion 2，含 `triggeredEventIDs`）。
- `Schemas/`：四份 JSON Schema；characters／rules 是版本 1，events／save 是版本 2。
- `Swift/GameEventModels.swift`：對應 Codable 模型與事件檔解碼範例。
- `FORMAT.md`：完整欄位與判定／保存規則。
- `CLAUDE_INTEGRATION.md`：給 Claude 的整合指示。
- `Tools/validate.py`：無第三方依賴的本資料包驗證器。

## 怎麼放進 Xcode

1. 將 Resources 的三份 JSON 加入 App Target／Copy Bundle Resources，保留唯一檔名。先用明確清單載入，不靠掃描整個 Bundle。
2. 將 Swift 模型按既有架構加入或合併；不要重複定義現有類型。
3. 確認 Assets 中存在 `player`、`boss`、`store_uniform_neutral`，必要時改 characters.json 對照實際名稱。Assets 使用資產名稱，不加 .png。事件背景預設沿用此次行動選到的背景。
4. Development、Examples、Schemas、Tools、文件不加入正式 App Resources。DEBUG 測試可單獨加入開發設定，取代正式規則，不能兩份一起套用。
5. 真正存檔寫在既有可寫存檔位置，不修改 Bundle JSON。金錢仍由既有玩家狀態保存。

## 新增一個事件

1. 複製 Examples/event_template.json 中 events 陣列的物件到 events_work.json。
2. 修改唯一 id、標題、participants、每句 speakerID／text／stage。
3. 調整條件與權重。完成後將 enabled 設成 true。
4. 執行 `python3 Tools/validate.py`（從資料包目錄執行）。
5. 使用開發規則測試，再由你決定正式觸發率。

所有範例的最低天數 1、權重 1，僅用來示範格式，不代表正式平衡設定。**每個事件的 id 在同一份存檔裡一生只會被選中一次**（觸發過就永久排除候選，不看是否完成、不因 revision 更新而重置）；沒有「可重複」這個選項。主規則關閉時，事件 enabled=true 也不會觸發。

正式版增加事件只需新增符合格式的資料；選項分支、好感度與獎勵效果不在 v1 內，需另行擴充格式與處理程式，不會默默執行。

## 驗證範圍

附帶驗證器會檢查資料結構、範圍、ID、角色／台詞／站位引用、條件循環、存檔狀態及多種刻意破壞資料。它只支援本包 Schema 使用的關鍵字，並非通用 JSON Schema 引擎。

這個環境沒有 Swift／Xcode，未進行 Swift 編譯或 UIKit 執行驗證。模型是整合參考，請在專案環境 build。Assets 檔案是否存在需由 App 或 Xcode 另外檢查。
