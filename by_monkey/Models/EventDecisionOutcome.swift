//
//  EventDecisionOutcome.swift
//  by_monkey
//

import Foundation

/// The result of running the "filter conditions → roll chance → pick by weight"
/// pipeline once for one action instance. Not part of GameEventData's own model set —
/// this is the in-memory result type `EventSelector`/`WorkSessionCoordinator` pass
/// around before it becomes a persisted `EventActionRecord`.
enum EventDecisionOutcome: Equatable {
    case noEvent(reason: EventNoEventReason)
    case event(GameEvent)
}
