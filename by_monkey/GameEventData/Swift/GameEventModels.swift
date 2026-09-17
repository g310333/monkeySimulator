import Foundation

// 資料格式參考模型。整合時可併入既有模型，避免重複類型。
// Codable 只解碼結構；數值範圍、跨檔參照與狀態不變量仍須驗證。
enum EventAction: String, Codable { case work, stocks, mountainRide = "mountain_ride", shopping }
enum EventTimePeriod: String, Codable { case morning, afternoon, night }
enum EventTriggerTiming: String, Codable { case afterSettlement = "after_settlement" }
enum EventNameSource: String, Codable { case fixed, playerName }
enum EventImageSampling: String, Codable { case nearest, linear }
enum EventStageSlot: String, Codable { case left, center, right }
enum EventRecordStatus: String, Codable {
    case pending, noEvent = "no_event", inProgress = "in_progress", completed
}
enum EventNoEventReason: String, Codable {
    case disabled, noEligibleEvents = "no_eligible_events", chanceMissed = "chance_missed"
}

struct EventCharacterName: Codable {
    let source: EventNameSource
    let fallback: String
    func resolved(playerName: String) -> String {
        source == .playerName && !playerName.isEmpty ? playerName : fallback
    }
}
struct EventCharacterPresentation: Codable {
    let sampling: EventImageSampling
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}
struct EventCharacter: Codable {
    let id: String
    let name: EventCharacterName
    let portraitAsset: String
    let presentation: EventCharacterPresentation
}
struct EventCharacterFile: Codable { let schemaVersion: Int; let characters: [EventCharacter] }
struct EventTrigger: Codable { let action: EventAction; let timing: EventTriggerTiming }
struct EventConditions: Codable {
    let minimumDay: Int
    let maximumDay: Int?
    let minimumMoney: Int
    let maximumMoney: Int?
    let timePeriods: [EventTimePeriod]
    let requiredCompletedEventIDs: [String]
    let requiredFlags: [String]
    let excludedFlags: [String]
}
enum EventBackground: Codable {
    case inherit
    case asset(String)
    private enum Keys: String, CodingKey { case mode, assetName }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let mode = try c.decode(String.self, forKey: .mode)
        switch mode {
        case "inherit": self = .inherit
        case "asset": self = .asset(try c.decode(String.self, forKey: .assetName))
        default: throw DecodingError.dataCorruptedError(forKey: .mode, in: c, debugDescription: "Unknown background mode: \(mode)")
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .inherit: try c.encode("inherit", forKey: .mode)
        case .asset(let name):
            try c.encode("asset", forKey: .mode)
            try c.encode(name, forKey: .assetName)
        }
    }
}
struct EventStageActor: Codable { let characterID: String; let slot: EventStageSlot }
struct EventDialogue: Codable {
    let id: String
    let speakerID: String
    let text: String
    let stage: [EventStageActor]
    func resolvedText(playerName: String) -> String {
        text.replacingOccurrences(of: "{playerName}", with: playerName)
    }
}
// v2: no `repeatable` — every event triggers at most once ever per save, tracked by
// `PlayerEventSave.triggeredEventIDs` below, not a per-event flag.
struct GameEvent: Codable {
    let id: String
    let revision: Int
    let enabled: Bool
    let title: String
    let trigger: EventTrigger
    let conditions: EventConditions
    let selectionWeight: Int
    let background: EventBackground
    let participants: [String]
    let dialogues: [EventDialogue]
}
struct GameEventFile: Codable { let schemaVersion: Int; let events: [GameEvent] }
struct EventActionRule: Codable { let action: EventAction; let enabled: Bool; let eventChance: Double }
struct EventRulesFile: Codable { let schemaVersion: Int; let rules: [EventActionRule] }

// 玩家金錢只在既有玩家存檔／結算服務中更新。此 context 是唯讀歷史快照。
struct EventActionContext: Codable {
    let action: EventAction
    let day: Int
    let timePeriod: EventTimePeriod
    let moneyAfterSettlement: Int
    let playerName: String
    let backgroundAsset: String
    let locationName: String
}
struct EventPlaybackSnapshot: Codable { let event: GameEvent; let characters: [EventCharacter] }
struct EventSelection: Codable {
    let snapshot: EventPlaybackSnapshot
    var currentDialogueID: String
}
struct EventActionRecord: Codable {
    let actionInstanceID: String
    let settlementID: String
    let settled: Bool
    let context: EventActionContext
    var status: EventRecordStatus
    var noEventReason: EventNoEventReason?
    var selected: EventSelection?
}
struct EventCompletionHistory: Codable {
    let eventID: String
    var completionCount: Int
    var lastCompletedActionInstanceID: String
}
// v2: adds `triggeredEventIDs` — every event ID ever selected into a record for this
// save, checked once ever regardless of completion, revision, day/action changes, or
// relaunch. Replaces the old `repeatable`-based rule; `history`/`completionCount`
// remain, but only for `requiredCompletedEventIDs` prerequisites — "triggered" and
// "completed" are deliberately separate facts. A v1 save (no `triggeredEventIDs`)
// should be migrated by unioning every `history` eventID and every
// `records[].selected.snapshot.event.id` into `triggeredEventIDs` — see FORMAT.md §5.
struct PlayerEventSave: Codable {
    let schemaVersion: Int
    var flags: [String]
    var history: [EventCompletionHistory]
    var records: [EventActionRecord]
    var triggeredEventIDs: Set<String>
}

enum GameEventDecodeError: Error { case unsupportedSchemaVersion(Int) }
// 明確指定要載入的檔案，不要自動把 Examples 或 Development 合併進正式內容。
// events_work.json 本身是隨程式一起發佈的內容檔（非玩家存檔），schemaVersion 不符時
// 直接視為不支援即可；玩家存檔（PlayerEventSave）才需要真正的執行期遷移。
func decodeGameEventFile(from data: Data) throws -> GameEventFile {
    let file = try JSONDecoder().decode(GameEventFile.self, from: data)
    guard file.schemaVersion == 2 else {
        throw GameEventDecodeError.unsupportedSchemaVersion(file.schemaVersion)
    }
    return file
}
