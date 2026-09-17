# 給 Claude 的整合指示

請把這份 GameEventData 資料格式接入現有 Swift／UIKit 專案。先閱讀 README.md、FORMAT.md 與專案規範；沿用現有 UI、導航、結算、玩家存檔及 Assets。

1. Resources/characters.json 與 events_work.json 為內容來源，event_rules.json 為正式機率設定。正式規則全部停用是刻意的，不自行開啟或猜測機率。
2. 使用 Swift/GameEventModels.swift 的 Codable 契約，按專案型別整合。它不含事件引擎或交易保存實作，需要補上。
3. 只在結算成功、收入入帳後，以此次 actionInstanceID 判定事件。無事件直接返回，有事件直接進事件 UI；結束後再返回原本的行動選擇。
4. 採用「篩條件 → 整體機率 → 權重選一個」的順序，實作 FORMAT.md 的精確語意，包括空陣列、null、觸發過即永久排除（一生一次，見存檔的 `triggeredEventIDs`）與前置事件。
5. 角色／背景引用 Assets，背景預設繼承此次行動已選到的背景。保留既有打工的 Assets/player/frames/talk000.png～talk003.png；事件大立繪使用 player、boss、store_uniform_neutral，必要時修改 JSON 映射實際資產名稱。
6. 從 dialogue.stage 取得完整在場角色、站位與 speakerID。一人置中、兩人左右、三人左中右，多於三位參與者時按每句舞台切換。高亮說話者、同步姓名、依序播放；最後一句確認才結束。
7. 完成結算與事件去重分開管理。金錢只有既有結算服務會更新；此資料包的 context.moneyAfterSettlement 只是快照，不能再次入帳。
8. 記錄所有判定結果，包括 no_event。重複回呼、返回、重啟不得覆蓋已提交結果。使用事件／角色快照恢復進度。completed 與 history 同交易保存。
9. Examples/save_*.json 只是同一狀態機不同階段的示例，不要合併或覆蓋真實存檔。存檔要使用既有可寫位置並有原子寫入／交易與版本遷移。
10. 執行 Tools/validate.py；在 App 端實作相應的解碼後驗證。Codable 不會自動做 JSON Schema 驗證。確認所有圖片存在。
11. DEBUG 可明確選用 Development/event_rules_debug.json，替換正式設定；可以用測試依賴強制指定三個事件之一或無事件以驗證 UI。這些控制不要放入正式玩家介面。
12. 補上針對機率邊界、權重、前置事件、單次判定、完成去重與中斷恢復的必要測試，執行 build。不要宣稱本資料包已完成 UIKit 整合。

限制：v1 不支援選項分支、旁白、好感度、額外報酬或任意腳本。不要藉此改動其他遊戲玩法。

完成後報告實際接入入口、資產對照、判定與存檔方式、測試結果和未完成事項。
