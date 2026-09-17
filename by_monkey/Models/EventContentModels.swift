//
//  EventContentModels.swift
//  by_monkey
//

import Foundation

// Mirrors GameEventData's Resources/events_work.json (schema v2) — see
// GameEventData/FORMAT.md §3 for field semantics. `EventAction`/`EventTimePeriod` are
// the JSON-facing vocabulary; `PlayerActionAdapter.swift` maps them to the project's own
// `PlayerAction`/`TimeOfDay` so gameplay code has a single source of truth for "which
// action" / "which time period", not two parallel enums doing the same job.
//
// v2 dropped `repeatable` — every event now triggers at most once ever per save,
// tracked by `PlayerEventSave.triggeredEventIDs` (see EventSaveModels.swift), not by a
// per-event flag. This content file is authored and shipped by us (not a persisted
// player artifact), so there's nothing to migrate at runtime: `EventRepository`
// requires schemaVersion 2 and rejects a v1 file outright, same as an unknown version —
// re-export the content at v2 rather than relying on silent tolerance. (Contrast with
// `PlayerEventSave`, an on-device save that genuinely does need runtime migration.)

enum EventAction: String, Codable {
    case work
    case stocks
    case mountainRide = "mountain_ride"
    case shopping
}

enum EventTimePeriod: String, Codable {
    case morning
    case afternoon
    case night
}

enum EventTriggerTiming: String, Codable {
    case afterSettlement = "after_settlement"
}

enum EventStageSlot: String, Codable {
    case left
    case center
    case right
}

struct EventTrigger: Codable, Equatable {
    let action: EventAction
    let timing: EventTriggerTiming
}

struct EventConditions: Codable, Equatable {
    let minimumDay: Int
    let maximumDay: Int?
    let minimumMoney: Int
    let maximumMoney: Int?
    let timePeriods: [EventTimePeriod]
    let requiredCompletedEventIDs: [String]
    let requiredFlags: [String]
    let excludedFlags: [String]
}

enum EventBackground: Codable, Equatable {
    case inherit
    case asset(String)

    private enum Keys: String, CodingKey { case mode, assetName }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let mode = try container.decode(String.self, forKey: .mode)
        switch mode {
        case "inherit":
            self = .inherit
        case "asset":
            self = .asset(try container.decode(String.self, forKey: .assetName))
        default:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: container, debugDescription: "Unknown background mode: \(mode)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .inherit:
            try container.encode("inherit", forKey: .mode)
        case .asset(let name):
            try container.encode("asset", forKey: .mode)
            try container.encode(name, forKey: .assetName)
        }
    }

    /// The background asset to actually show for this event — either the one baked
    /// into the event, or the current action's own background when `mode: inherit`.
    func resolvedAssetName(inheritedFrom contextBackgroundAsset: String) -> String {
        switch self {
        case .inherit: return contextBackgroundAsset
        case .asset(let name): return name
        }
    }
}

struct EventStageActor: Codable, Equatable {
    let characterID: String
    let slot: EventStageSlot
}

struct EventDialogue: Codable, Equatable {
    let id: String
    let speakerID: String
    let text: String
    let stage: [EventStageActor]

    /// v1 only supports the `{playerName}` token — no scripting, no other substitutions.
    func resolvedText(playerName: String) -> String {
        text.replacingOccurrences(of: "{playerName}", with: playerName)
    }
}

struct GameEvent: Codable, Equatable {
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

    func dialogue(id dialogueID: String) -> EventDialogue? {
        dialogues.first { $0.id == dialogueID }
    }
}

struct GameEventFile: Codable {
    let schemaVersion: Int
    let events: [GameEvent]
}
