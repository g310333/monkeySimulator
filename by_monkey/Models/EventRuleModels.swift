//
//  EventRuleModels.swift
//  by_monkey
//

import Foundation

// Mirrors GameEventData's Resources/event_rules.json (schema v1) — see
// GameEventData/FORMAT.md §4. Production ships all four actions disabled; the real
// trigger rate/conditions haven't been decided, and this file must not guess one.

struct EventActionRule: Codable, Equatable {
    let action: EventAction
    let enabled: Bool
    let eventChance: Double
}

struct EventRulesFile: Codable {
    let schemaVersion: Int
    let rules: [EventActionRule]
}
