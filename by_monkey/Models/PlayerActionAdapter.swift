//
//  PlayerActionAdapter.swift
//  by_monkey
//

import Foundation

// GameEventData/FORMAT.md §1: "action... 由 adapter 映射既有 enum." `PlayerAction` and
// `TimeOfDay` (this project's own gameplay enums) stay the single source of truth for
// "which action" / "which time period" — `EventAction`/`EventTimePeriod` only exist to
// mirror the JSON vocabulary, and never get compared or switched on outside the event
// subsystem's own JSON-facing code.

extension PlayerAction {
    var eventAction: EventAction {
        switch self {
        case .work: return .work
        case .stocks: return .stocks
        case .touge: return .mountainRide
        case .shopping: return .shopping
        }
    }
}

extension EventAction {
    var playerAction: PlayerAction {
        switch self {
        case .work: return .work
        case .stocks: return .stocks
        case .mountainRide: return .touge
        case .shopping: return .shopping
        }
    }
}

extension TimeOfDay {
    var eventTimePeriod: EventTimePeriod {
        switch self {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .night: return .night
        }
    }
}

extension EventTimePeriod {
    var timeOfDay: TimeOfDay {
        switch self {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .night: return .night
        }
    }
}
