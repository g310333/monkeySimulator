# 格式與行為約定 v1

## 1. 共通約定

- UTF-8 JSON，無註解、無尾逗號。
- 每個根物件都有自己的 `schemaVersion`，各檔案獨立版號：characters／rules 目前是 1；events／save 是 2（v2 移除 `repeatable`，save 新增 `triggeredEventIDs`，見下）。未知版本先報錯／遷移，不能忽略。
- 事件、角色、台詞 ID 使用小寫英文字、數字、底線，開頭是字母。事件／角色 ID 全內容唯一；台詞 ID 只需事件內唯一。發佈後保持 ID 穩定。
- v1 不接受未定義欄位，避免拼字錯誤被靜默略過。Swift Codable 自動解碼本身不會檢查多餘 key 或數值範圍，整合端要補驗證。
- 範例把可空欄位寫為 null。可空欄位可省略時，Schema 與 Codable 均應能接受；本包 Schema 將這些欄位列為選填。其他欄位必填。
- day 從 1 起算；金額是整數遊戲貨幣單位，不使用浮點數。
- action：work／stocks／mountain_ride／shopping。對照打工／股票／跑山／購物，由 adapter 映射既有 enum。
- timePeriod：morning／afternoon／night，對照早上／下午／晚上。
- 事件定義是共用內容；玩家完成紀錄是每個存檔自己的資料。

## 2. 角色 characters.json

| 欄位 | 型別 | 含義 |
| --- | --- | --- |
| characters | 陣列 | 全部共用角色 |
| id | String | 對話引用的角色 ID |
| name.source | fixed / playerName | 固定顯示名稱／使用當前事件 context 的玩家名稱 |
| name.fallback | String | 固定名稱；玩家名稱空白時的備用名稱 |
| portraitAsset | String | Assets 資產名稱，不加副檔名 |
| presentation.sampling | nearest / linear | 像素圖／一般插畫的取樣方式 |
| presentation.scale | Double，0 < 值 ≤ 3 | 相對於 UI 自動排版尺寸的倍率，1 表示不調整 |
| presentation.offsetX | Double，-1～1 | 舞台寬度比例位移，正值往右 |
| presentation.offsetY | Double，-1～1 | 舞台高度比例位移，正值往下 |

UI 先按人數與素材透明內容範圍決定基礎尺寸，再套用倍率／位移。預設站位不是螢幕絕對像素；需在小螢幕上確認不遮臉。資料不要求翻轉圖片。

## 3. 事件 events_work.json（schemaVersion 2）

| 欄位 | 型別 | 含義 |
| --- | --- | --- |
| events | 陣列 | 事件清單，可分檔載入後合併，合併時檢查重複 ID |
| id | String | 事件永久識別碼；同一存檔內這個 ID 一生只會被觸發一次，見 §5 |
| revision | Int ≥ 1 | 內容修訂版本，改台詞／條件時遞增；不影響、也不重置存檔的觸發／完成紀錄 |
| enabled | Bool | 此事件是否可加入候選清單 |
| title | String | 顯示於事件畫面 |
| trigger.action | 行動 enum | 來源行動 |
| trigger.timing | after_settlement | 必須成功完成結算／入帳後才判定 |
| conditions | 物件 | 所有條件同時成立才合格 |
| selectionWeight | Int ≥ 1 | 合格事件之間的相對權重，不是觸發機率 |
| background | 物件 | inherit 沿用背景，或 asset 指定背景 |
| participants | ID 陣列 | 整場事件涉及的全部角色，可多於三位 |
| dialogues | 陣列 | 順序播放，不得空陣列 |

v1 有過 `repeatable` 欄位（false／true 決定完成後能否再選）；v2 已移除。**現在每個事件不論這裡怎麼寫，同一份存檔一生只會被觸發一次**，判斷依據是存檔的 `triggeredEventIDs`（見 §5），不是這份內容檔的任何欄位。events_work.json 由專案自行發佈、不是玩家存檔，schemaVersion 不符時直接視為不支援，不提供執行期自動遷移；玩家存檔才需要、也才有遷移邏輯。

背景有兩種有效形狀：

```json
{"mode": "inherit"}
```

```json
{"mode": "asset", "assetName": "shop"}
```

inherit 使用 action context 的 backgroundAsset，不能重新隨機選背景。預設全部範例都是 inherit，符合你「沿用選擇到的背景」的要求。

### 觸發條件

| 欄位 | 含義 |
| --- | --- |
| minimumDay | 最低天數，含當日 |
| maximumDay | 最高天數，含當日；null／省略＝無上限 |
| minimumMoney | 最低金錢，含邊界，使用結算後金額 |
| maximumMoney | 最高金錢，含邊界；null／省略＝無上限 |
| timePeriods | 任一列出的時段可觸發；空陣列＝不限 |
| requiredCompletedEventIDs | 列出的事件必須全部完成；空陣列＝無前置事件 |
| requiredFlags | 存檔必須具有全部列出的旗標 |
| excludedFlags | 存檔不能具有其中任何旗標 |

上下限不可互相矛盾。前置事件不能引用自己、未知事件或形成循環。requiredFlags 與 excludedFlags 不可重疊。

天數、時段與金錢使用「結算完成後、事件判定前」的共用玩家狀態快照。若現有遊戲結算會推進時段，使用推進後的值，不在事件系統再次推進。使用者尚未定義的條件不用猜測。

### 台詞與站位

| 欄位 | 含義 |
| --- | --- |
| id | 事件內唯一的台詞 ID；存檔用 ID，不用陣列索引 |
| speakerID | 正在說話的角色，必須在本句 stage 中 |
| text | 台詞；v1 只支援 `{playerName}` 替換，不執行腳本或任意表達式 |
| stage | 本句完整在場名單，1～3 位，不是相對上一句的增量 |
| stage[].characterID | 必須存在於 characters 與事件 participants |
| stage[].slot | left／center／right，同句不能重複 |

一位用 center；兩位用 left/right；三位用 left/center/right。換句時相同角色和站位保持穩定；四人以上輪換部分在場名單，不能把所有人縮小塞進去。只有 stage 中的人要繪製，並依 speakerID 高亮。

例如四人事件可讓第 1 句 stage 是 A/B/C，第 2 句是 A/D/C，前提是已定義角色 D，且說話者在當句 stage 內。

## 4. 整體機率 event_rules.json

每種行動恰有一條 rule：action、enabled、eventChance。

- enabled=false：本次已判定無事件，原因 disabled。
- eventChance 介於 0～1，0 不觸發，1 必觸發（仍須有合格事件）。
- Development 設定 work=1 是方便測試，不能當成正式機率。
- 三個範例事件全部觸發過一次後，同一份存檔即使 debug 100% 也不會再有事件（一生一次，見 §5）。用獨立測試存檔或重新建立測試存檔，不清除真實玩家紀錄。

判定順序：

1. 確認此次 actionInstanceID 的結算成功且收入已保存。
2. 若已有非 pending 的判定紀錄，直接使用紀錄，不重抽。
3. 若該行動規則停用，記錄 no_event / disabled。
4. 依行動、enabled、全部 conditions 與 `triggeredEventIDs`（已觸發過的事件直接排除，不看是否完成、不看 revision）篩出候選；排序依事件 ID，保持 deterministic 測試順序。
5. 無候選：記錄 no_event / no_eligible_events，不做機率抽樣。
6. 產生 u ∈ [0,1)。u < eventChance 才觸發；否則記錄 no_event / chance_missed。
7. 觸發後，產生 v ∈ [0, 候選權重總和)，依累積權重區間選一個。機率與權重抽樣為獨立抽樣；用可注入 RNG 驗證邊界。
8. 將被選事件、角色、第一句 currentDialogueID、context，連同把該事件 ID 加入 `triggeredEventIDs`，一起保存完成後才導航（同一次寫入，不是兩步）。

例如全局機率 0.3，只有權重 1 與 3 的兩個合格事件，最終機率為 7.5%、22.5%，70% 無事件。這只是算例，不是正式設定。

## 5. 存檔格式（schemaVersion 2）

### 根物件

| 欄位 | 含義 |
| --- | --- |
| schemaVersion | 存檔格式版本，2 |
| flags | 玩家劇情旗標的唯一字串集合；v1 由既有遊戲邏輯設定 |
| history | 以 eventID 記錄完成次數與最後完成的行動 ID |
| records | 每個已結算 actionInstanceID 的判定與播放狀態 |
| triggeredEventIDs | **v2 新增**：這份存檔一生觸發過的全部事件 ID 的唯一集合 |

history 是完成判定依据，不因事件 revision 增加就忘記已完成。記錄是否保留／歸檔需有遷移策略；未實作前不要直接刪 records。範例以不刪除 records 為約定。

**觸發（triggered）與完成（completed）是兩件分開記錄的事**：一個事件被選中的當下就進入 `triggeredEventIDs`——不管玩家後來有沒有把它看完；`history`／`completionCount` 只在玩家確認最後一句、record 真正變成 `completed` 時才更新。`requiredCompletedEventIDs` 前置條件永遠查 `history`，不是 `triggeredEventIDs`——只是被選中過、還沒玩完的事件，不能當作別人的前置條件已滿足。

`triggeredEventIDs` 是同一事件 ID 一生只能觸發一次的**唯一依據**：只認 `id`，不看標題、`revision`、哪一個 actionInstanceID 觸發的；換天、換行動、重啟 App、事件內容改了 revision，都不會讓已在這個集合裡的 ID 重新變成候選。所有符合條件的事件都被觸發過一輪後，之後的判定會持續得到 no_event / no_eligible_events，不會重置這份紀錄，也不需要任何特殊處理——單純是候選清單本來就空了。新開一局要用新的、獨立的存檔，才會有一個空的 `triggeredEventIDs` 重新開始。

### records 每筆欄位

| 欄位 | 含義 |
| --- | --- |
| actionInstanceID | 行動開始時產生的唯一 ID；不是 work 這種行動種類 |
| settlementID | 引用既有結算的唯一 ID，不是另一筆薪水 |
| settled | 必須為 true；只放已成功結算的紀錄，實際仍要核對結算服務 |
| context | 結算後的唯讀快照：action、day、timePeriod、moneyAfterSettlement、playerName、backgroundAsset、locationName |
| status | pending／no_event／in_progress／completed |
| noEventReason | 僅 no_event 時有 disabled／no_eligible_events／chance_missed |
| selected | 僅 in_progress／completed 時有內容，其他為 null／省略 |
| selected.snapshot | 當時 event 全部內容與 participants 的 characters 完整快照 |
| selected.currentDialogueID | 正在顯示的台詞 ID；完成狀態固定為最後一句 |

moneyAfterSettlement 只供條件判定與歷史參考，不能拿它覆蓋玩家的即時錢包。此資料包不含發薪欄位或事件獎勵指令。

### 狀態有效組合

| status | noEventReason | selected | 行為 |
| --- | --- | --- | --- |
| pending | null／省略 | null／省略 | 已結算，尚未產生持久化判定 |
| no_event | 必須有原因 | null／省略 | 返回行動選擇，不再判定 |
| in_progress | null／省略 | 必須有 | 恢復快照與目前台詞 |
| completed | null／省略 | 必須有，停在最後句 | 不重播，返回行動選擇 |

pending 不是未結算：未成功入帳的行動不進入這份事件 records。

### 保存與去重的實作契約

- 同一 actionInstanceID 的判定由單一序列化流程／actor 處理，不能兩個 Task 同時抽選。
- 同一次判定在保存失败時保留算好的結果重試，不重新抽樣。若需跨重啟保證「抽樣本身」也不重做，應在抽樣前持久化 RNG 輸入、規則與候選快照，或把判定纳入支援原子提交的工作交易；不得僅依靠按鈕鎖定。本包提供的是已提交結果格式，沒有宣稱 JSON 檔案本身能提供交易能力。
- 至少保證只有已持久化的選取結果才會顯示；結果一旦存在永不覆蓋。原子寫入整份 event save，或使用既有資料庫交易。
- **選中事件時，被選事件的 ID 加入 `triggeredEventIDs`、record 寫入 selected 快照、context 與判定結果，全部在同一次原子寫入／交易裡完成，保存成功才顯示事件畫面。** 保存失敗要重試同一個已抽出的結果（含同一個被選事件），不能因為重試又重新抽選一次；沒有事件（no_event）時，這次寫入只新增這筆行動自己的 record，不去動 `triggeredEventIDs`。
- selected.snapshot 固定進行中內容，避免更新 events JSON 後台詞 ID 消失。素材本身未內嵌，App 更新仍須保留被引用的資產或提供遷移。
- 對話前進時保存下一個即將顯示的 currentDialogueID。中斷重開可再次顯示當前句，這是接續播放，不是再次觸發，不得重抽或發薪。
- 玩家確認最後一句後，在同一交易把 record 設為 completed 並更新 history，然後返回。重複 completion 看 status，不能重複增加 completionCount。`triggeredEventIDs` 在事件被選中當下就已經有這個 ID，完成時不需要（也不應該）再次寫入它。
- 新行動使用新 actionInstanceID，重新執行條件判定；但同一個事件 ID 只要已經在 `triggeredEventIDs` 裡，不論這次是哪個行動、哪一天、事件 revision 有沒有更新，都不會再進候選清單。
- 若無法恢復快照或保存失敗，保留原狀態提示重試，不把錯誤當成 no_event，也不重新發薪。
- **v1→v2 存檔遷移**：v1 存檔沒有 `triggeredEventIDs`。遷移時，把 `history` 裡每個 eventID，以及每筆 `records` 中 `selected` 不為空（`in_progress` 或 `completed`）的 `selected.snapshot.event.id`，聯集寫入新的 `triggeredEventIDs`；`records`／`history` 本身原樣保留，不重置任何進度。舊格式若仍帶有事件內容的 `repeatable` 欄位，遷移與後續判定一律忽略它，不允許用它繞過一生一次的規則。
- 遷移出來、甚至遷移前既有的 `records`，可能本來就有好幾筆紀錄選到**同一個**曾經 `repeatable: true` 的事件——這是舊規則下真實發生過的紀錄，遷移時原樣保留，不是資料損壞，`triggeredEventIDs` 只需要包含這個事件的 ID 一次即可。往前看的保護（同一事件不會再被選第二次）由判定當下的候選篩選負責，不是靠事後掃描 records 有沒有重複來把舊資料判定為不合法；驗證器只需確認 `triggeredEventIDs` 等於全部已選取事件 ID 的集合，不需要、也不應該要求 records 裡每個事件只出現一次。

## 6. 邊界與擴充

v1 僅有線性交談、在場角色、單一說話者，不含玩家選項、分支跳轉、旁白、表情切換、增加金錢、好感度、旗標寫入或事件連發。不要自創 effects 欄位期待程式自動執行。新增這些能力時擴充 schema、Codable 與解讀程式，並設計版本遷移。
