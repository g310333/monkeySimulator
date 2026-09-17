//
//  EventDebugSettings.swift
//  by_monkey
//

import Foundation

#if DEBUG
/// Dev-only override for exercising every event-outcome branch (no event, 1/2/3-person)
/// without waiting on real trigger conditions or randomness. This type doesn't exist at
/// all outside DEBUG builds, and even in DEBUG it defaults to off — there is no "force
/// event" control anywhere a player can reach; flip this in code and rebuild.
///
/// `debugWorkRule` mirrors GameEventData/Development/event_rules_debug.json's intent
/// (work enabled at 100%) without bundling that file into the app at all, sidestepping
/// any need to make Copy Bundle Resources membership configuration-dependent.
enum EventDebugSettings {
    enum ForcedOutcome {
        case none
        /// Picks any event that hasn't been triggered yet in this save — no headcount
        /// needed when you just want "make something happen".
        case any
        /// Picks the shipped demo event with this many participants (1, 2, or 3), for
        /// when you specifically want to see the 1-/2-/3-person staging.
        case participantCount(Int)
    }

    // TODO: revert to isEnabled = false before shipping — forced on for manual testing.
    static var isEnabled = true
    static var forcedOutcome: ForcedOutcome = .any

    static let debugWorkRule = EventActionRule(action: .work, enabled: true, eventChance: 1)
}
#endif
