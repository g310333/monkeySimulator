//
//  EventConditionEvaluatorTests.swift
//  by_monkeyTests
//

import Testing
@testable import by_monkey

struct EventConditionEvaluatorTests {

    let evaluator = EventConditionEvaluator()

    @Test func disabledEventIsIneligible() {
        let event = EventTestFixtures.makeEvent(enabled: false)
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: .empty))
    }

    @Test func mismatchedActionIsIneligible() {
        let event = EventTestFixtures.makeEvent(action: .work)
        let context = EventTestFixtures.makeContext(action: .shopping)
        #expect(!evaluator.isEligible(event, context: context, save: .empty))
    }

    @Test func dayBelowMinimumIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(minimumDay: 5))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(day: 4), save: .empty))
    }

    @Test func dayAboveMaximumIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(maximumDay: 3))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(day: 4), save: .empty))
    }

    @Test func nilMaximumDayHasNoUpperBound() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(maximumDay: nil))
        #expect(evaluator.isEligible(event, context: EventTestFixtures.makeContext(day: 9999), save: .empty))
    }

    @Test func moneyBelowMinimumIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(minimumMoney: 500))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(money: 100), save: .empty))
    }

    @Test func moneyAboveMaximumIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(maximumMoney: 500))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(money: 600), save: .empty))
    }

    @Test func emptyTimePeriodsMeansAnyPeriod() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(timePeriods: []))
        #expect(evaluator.isEligible(event, context: EventTestFixtures.makeContext(timePeriod: .night), save: .empty))
    }

    @Test func timePeriodMismatchIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(timePeriods: [.morning]))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(timePeriod: .night), save: .empty))
    }

    @Test func missingPrerequisiteEventIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["prior_event"]))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: .empty))
    }

    @Test func satisfiedPrerequisiteEventIsEligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["prior_event"]))
        let save = EventTestFixtures.makeSave(history: [EventCompletionHistory(eventID: "prior_event", completionCount: 1, lastCompletedActionInstanceID: "x")])
        #expect(evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: save))
    }

    @Test func missingRequiredFlagIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredFlags: ["met_boss"]))
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: .empty))
    }

    @Test func excludedFlagPresentIsIneligible() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(excludedFlags: ["quit_job"]))
        let save = EventTestFixtures.makeSave(flags: ["quit_job"])
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: save))
    }

    @Test func alreadyTriggeredEventIsIneligibleRegardlessOfCompletion() {
        // Triggered but never even completed (still in_progress in spirit) — one-shot
        // is about ever being *selected*, not about finishing it.
        let event = EventTestFixtures.makeEvent()
        let save = EventTestFixtures.makeSave(triggeredEventIDs: [event.id])
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: save))
    }

    @Test func untriggeredEventStaysEligibleEvenWithOtherHistory() {
        let event = EventTestFixtures.makeEvent(id: "work_never_triggered")
        let save = EventTestFixtures.makeSave(
            history: [EventCompletionHistory(eventID: "some_other_event", completionCount: 5, lastCompletedActionInstanceID: "x")],
            triggeredEventIDs: ["some_other_event"]
        )
        #expect(evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: save))
    }

    @Test func triggeredButNotCompletedEventDoesNotSatisfyPrerequisite() {
        // "Triggered" and "completed" are deliberately separate: a prerequisite keyed
        // on `requiredCompletedEventIDs` must not unlock just because the prior event
        // was shown — it needs to actually be finished (present in `history`).
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["prior_event"]))
        let save = EventTestFixtures.makeSave(triggeredEventIDs: ["prior_event"]) // triggered, not completed
        #expect(!evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: save))
    }

    @Test func fullyQualifyingEventIsEligible() {
        let event = EventTestFixtures.makeEvent()
        #expect(evaluator.isEligible(event, context: EventTestFixtures.makeContext(), save: .empty))
    }
}
