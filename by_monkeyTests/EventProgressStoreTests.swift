//
//  EventProgressStoreTests.swift
//  by_monkeyTests
//

import Testing
import Foundation
@testable import by_monkey

struct EventProgressStoreTests {

    private func makeStore() -> EventProgressStore {
        let suiteName = "EventProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return EventProgressStore(defaults: defaults)
    }

    @Test func decideIfNeededPersistsNoEventWithReason() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        let result = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: []) { _ in
            .noEvent(reason: .chanceMissed)
        }
        guard case .success(let record) = result else { Issue.record("expected success"); return }
        #expect(record.status == .noEvent)
        #expect(record.noEventReason == .chanceMissed)
        #expect(record.selected == nil)
        #expect(store.existingRecord(for: "a1") == record)
    }

    @Test func decideIfNeededNeverRerollsForTheSameInstance() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        var decideCallCount = 0

        func decide(_ save: PlayerEventSave) -> EventDecisionOutcome {
            decideCallCount += 1
            return .noEvent(reason: .chanceMissed)
        }

        _ = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: [], decide: decide)
        // A second call for the SAME instance (simulating a duplicate callback, a
        // rebuilt view, or re-entering the same in-flight instance) must reuse the
        // persisted result and never invoke `decide` again.
        let second = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: [], decide: decide)

        #expect(decideCallCount == 1)
        if case .success(let record) = second {
            #expect(record.status == .noEvent)
        } else {
            Issue.record("expected success on second call")
        }
    }

    @Test func decideIfNeededPersistsSelectedEventWithFirstDialogueCursor() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        let event = EventTestFixtures.makeEvent()
        let result = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: [EventTestFixtures.playerCharacter]) { _ in
            .event(event)
        }
        guard case .success(let record) = result else { Issue.record("expected success"); return }
        #expect(record.status == .inProgress)
        #expect(record.selected?.currentDialogueID == event.dialogues.first?.id)
        #expect(record.selected?.snapshot.characters.map { $0.id } == ["player"])
    }

    @Test func saveDialogueProgressUpdatesCursor() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        let line2 = EventDialogue(id: "line_002", speakerID: "player", text: "second", stage: [EventStageActor(characterID: "player", slot: .center)])
        let event = EventTestFixtures.makeEvent(dialogues: [
            EventDialogue(id: "line_001", speakerID: "player", text: "first", stage: [EventStageActor(characterID: "player", slot: .center)]),
            line2,
        ])
        _ = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: [EventTestFixtures.playerCharacter]) { _ in .event(event) }

        let result = store.saveDialogueProgress(actionInstanceID: "a1", dialogueID: "line_002")
        guard case .success(let record) = result else { Issue.record("expected success"); return }
        #expect(record.selected?.currentDialogueID == "line_002")
    }

    @Test func completeEventUpdatesHistoryOnce() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        let event = EventTestFixtures.makeEvent()
        _ = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: [EventTestFixtures.playerCharacter]) { _ in .event(event) }

        let first = store.completeEvent(actionInstanceID: "a1")
        guard case .success(let firstRecord) = first else { Issue.record("expected success"); return }
        #expect(firstRecord.status == .completed)
        #expect(store.currentSave().completionCount(for: event.id) == 1)

        // Re-entrant completion (duplicate callback, return navigation firing twice,
        // relaunch resuming an already-completed record) must never double-count.
        let second = store.completeEvent(actionInstanceID: "a1")
        guard case .success = second else { Issue.record("expected success"); return }
        #expect(store.currentSave().completionCount(for: event.id) == 1)
    }

    @Test func differentActionInstancesGetIndependentDecisions() {
        let store = makeStore()
        let context = EventTestFixtures.makeContext()
        _ = store.decideIfNeeded(actionInstanceID: "a1", settlementID: "s1", context: context, availableCharacters: []) { _ in .noEvent(reason: .chanceMissed) }
        _ = store.decideIfNeeded(actionInstanceID: "a2", settlementID: "s2", context: context, availableCharacters: []) { _ in .noEvent(reason: .disabled) }

        #expect(store.existingRecord(for: "a1")?.noEventReason == .chanceMissed)
        #expect(store.existingRecord(for: "a2")?.noEventReason == .disabled)
    }
}
