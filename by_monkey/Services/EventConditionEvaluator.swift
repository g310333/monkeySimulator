//
//  EventConditionEvaluator.swift
//  by_monkey
//

import Foundation

/// Whether one event qualifies as a candidate for this action instance: its own
/// `enabled`/`trigger.action`/`conditions`, plus save-dependent facts that content alone
/// can't answer. Exactly GameEventData/FORMAT.md §3's condition table plus the
/// once-ever-per-save rule from §4 step 4.
protocol EventConditionEvaluating {
    func isEligible(_ event: GameEvent, context: EventActionContext, save: PlayerEventSave) -> Bool
}

struct EventConditionEvaluator: EventConditionEvaluating {

    func isEligible(_ event: GameEvent, context: EventActionContext, save: PlayerEventSave) -> Bool {
        // Every event triggers at most once ever per save — checked by `id` alone, not
        // title/revision/actionInstanceID, and independent of whether it was ever
        // completed. This replaces the old `repeatable` flag entirely.
        guard !save.triggeredEventIDs.contains(event.id) else { return false }

        guard event.enabled else { return false }
        guard event.trigger.action == context.action else { return false }

        let conditions = event.conditions
        guard context.day >= conditions.minimumDay else { return false }
        if let maximumDay = conditions.maximumDay, context.day > maximumDay { return false }
        guard context.moneyAfterSettlement >= conditions.minimumMoney else { return false }
        if let maximumMoney = conditions.maximumMoney, context.moneyAfterSettlement > maximumMoney { return false }
        if !conditions.timePeriods.isEmpty, !conditions.timePeriods.contains(context.timePeriod) { return false }

        // Prerequisites are still completion-based (a genuinely *finished* event), kept
        // deliberately separate from `triggeredEventIDs` (merely "already shown").
        let completedEventIDs = Set(save.history.map { $0.eventID })
        guard Set(conditions.requiredCompletedEventIDs).isSubset(of: completedEventIDs) else { return false }

        let flags = Set(save.flags)
        guard Set(conditions.requiredFlags).isSubset(of: flags) else { return false }
        guard Set(conditions.excludedFlags).isDisjoint(with: flags) else { return false }

        return true
    }
}
