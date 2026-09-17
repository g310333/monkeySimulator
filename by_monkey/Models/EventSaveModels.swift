//
//  EventSaveModels.swift
//  by_monkey
//

import Foundation

// Mirrors GameEventData's save format (schema v2) — see GameEventData/FORMAT.md §5.
// This is per-player-save state (owned by `EventProgressStore`), distinct from the
// shared, read-only event *content* in EventContentModels.swift.
//
// v2 adds `triggeredEventIDs`: every event ID this save has ever selected, checked once
// ever regardless of completion, revision bumps, day/action changes, or relaunches. It
// replaces the old `repeatable`-based rule entirely — `EventConditionEvaluator` no
// longer looks at completion history to decide eligibility, only this set. Completion
// history (`history`/`completionCount`) still exists, but purely for
// `requiredCompletedEventIDs` prerequisites — "triggered" and "completed" are
// deliberately separate facts.

enum EventRecordStatus: String, Codable {
    case pending
    case noEvent = "no_event"
    case inProgress = "in_progress"
    case completed
}

enum EventNoEventReason: String, Codable {
    case disabled
    case noEligibleEvents = "no_eligible_events"
    case chanceMissed = "chance_missed"
}

/// Read-only historical snapshot of the settlement that produced this record. Never a
/// second source of truth for money — `moneyAfterSettlement` is only for condition
/// checks and history; the player's live wallet is `PlayerProfileStore` alone.
struct EventActionContext: Codable, Equatable {
    let action: EventAction
    let day: Int
    let timePeriod: EventTimePeriod
    let moneyAfterSettlement: Int
    let playerName: String
    let backgroundAsset: String
    let locationName: String
}

/// Frozen content for an in-progress/completed record, so a later edit to
/// events_work.json can never change what an already-selected playthrough shows, and a
/// dialogue ID it references never goes missing underneath it.
struct EventPlaybackSnapshot: Codable, Equatable {
    let event: GameEvent
    let characters: [EventCharacter]

    func character(id characterID: String) -> EventCharacter? {
        characters.first { $0.id == characterID }
    }
}

struct EventSelection: Codable, Equatable {
    let snapshot: EventPlaybackSnapshot
    var currentDialogueID: String
}

struct EventActionRecord: Codable, Equatable {
    let actionInstanceID: String
    let settlementID: String
    let settled: Bool
    let context: EventActionContext
    var status: EventRecordStatus
    var noEventReason: EventNoEventReason?
    var selected: EventSelection?
}

struct EventCompletionHistory: Codable, Equatable {
    let eventID: String
    var completionCount: Int
    var lastCompletedActionInstanceID: String
}

struct PlayerEventSave: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    var flags: [String]
    var history: [EventCompletionHistory]
    var records: [EventActionRecord]
    /// Every event ID ever selected into a record (in_progress or completed) for this
    /// save. The sole gate for "has this event already happened" — see
    /// `EventConditionEvaluator`. An event enters this the moment it's selected, before
    /// the player even finishes it, and it is never removed.
    var triggeredEventIDs: Set<String>

    static let empty = PlayerEventSave(schemaVersion: currentSchemaVersion, flags: [], history: [], records: [], triggeredEventIDs: [])

    func record(for actionInstanceID: String) -> EventActionRecord? {
        records.first { $0.actionInstanceID == actionInstanceID }
    }

    func completionCount(for eventID: String) -> Int {
        history.first { $0.eventID == eventID }?.completionCount ?? 0
    }
}
