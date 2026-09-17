//
//  EventOneShotTriggerTests.swift
//  by_monkeyTests
//

import Testing
import Foundation
@testable import by_monkey

/// Integration-style tests spanning `EventConditionEvaluator` + `EventSelector` +
/// `EventProgressStore` together — the same collaborators `WorkSessionCoordinator`
/// composes — since "does the same event ever retrigger" is a property of that whole
/// pipeline, not any single service in isolation.
struct EventOneShotTriggerTests {

    private func makeStore() -> EventProgressStore {
        let suiteName = "EventOneShotTriggerTests.\(UUID().uuidString)"
        return EventProgressStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    private func decideAndCommit(
        event: GameEvent,
        actionInstanceID: String,
        context: EventActionContext,
        store: EventProgressStore,
        evaluator: EventConditionEvaluating,
        selector: EventSelecting
    ) -> EventActionRecord {
        let result = store.decideIfNeeded(
            actionInstanceID: actionInstanceID,
            settlementID: "settlement-\(actionInstanceID)",
            context: context,
            availableCharacters: [EventTestFixtures.playerCharacter]
        ) { save in
            // Use the `save` handed in here, never `store.currentSave()` — this closure
            // runs while `store` still holds its lock, and `currentSave()` would try to
            // reacquire the same non-reentrant lock on the same thread and hang forever.
            let candidates = [event].filter { evaluator.isEligible($0, context: context, save: save) }
            return selector.draw(candidates: candidates, eventChance: 1, rng: FakeEventRandomSource([0, 0]))
        }
        guard case .success(let record) = result else {
            Issue.record("expected successful decision")
            fatalError()
        }
        return record
    }

    @Test func sameEventNeverRetriggersAcrossDifferentActionInstances() {
        let store = makeStore()
        let evaluator = EventConditionEvaluator()
        let selector = EventSelector()
        let event = EventTestFixtures.makeEvent(id: "work_once_only")
        let context = EventTestFixtures.makeContext()

        let first = decideAndCommit(event: event, actionInstanceID: "instance-1", context: context, store: store, evaluator: evaluator, selector: selector)
        #expect(first.status == .inProgress)
        #expect(first.selected?.snapshot.event.id == event.id)

        // A brand-new action instance (new UUID, same day/action) re-runs the whole
        // pipeline from scratch — the event must no longer be a candidate at all.
        let second = decideAndCommit(event: event, actionInstanceID: "instance-2", context: context, store: store, evaluator: evaluator, selector: selector)
        #expect(second.status == .noEvent)
        #expect(second.noEventReason == .noEligibleEvents)

        #expect(store.currentSave().triggeredEventIDs == [event.id])
    }

    @Test func eventStaysExcludedAcrossDayChangeActionRepeatAndRelaunch() {
        let event = EventTestFixtures.makeEvent(id: "work_persistent_exclusion")
        let evaluator = EventConditionEvaluator()
        let suiteName = "EventOneShotTriggerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        var store = EventProgressStore(defaults: defaults)
        let context1 = EventTestFixtures.makeContext(day: 1)
        _ = decideAndCommit(event: event, actionInstanceID: "day1", context: context1, store: store, evaluator: evaluator, selector: EventSelector())

        // Simulate an app relaunch: a fresh `EventProgressStore` reading the same
        // UserDefaults suite, a later day, a fresh action instance.
        store = EventProgressStore(defaults: defaults)
        let context2 = EventTestFixtures.makeContext(day: 2)
        #expect(!evaluator.isEligible(event, context: context2, save: store.currentSave()))
    }

    @Test func migratesLegacySaveWithoutTriggeredEventIDsIntoUnionOfHistoryAndSelectedRecords() throws {
        let suiteName = "EventOneShotTriggerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let completedEvent = EventTestFixtures.makeEvent(id: "work_legacy_completed")
        let inProgressEvent = EventTestFixtures.makeEvent(id: "work_legacy_in_progress")
        let context = EventTestFixtures.makeContext()

        // Hand-built legacy (pre-triggeredEventIDs) JSON — exactly the v1 shape a real
        // on-device save would have had.
        let legacyJSON: [String: Any] = [
            "schemaVersion": 1,
            "flags": [],
            "history": [
                ["eventID": completedEvent.id, "completionCount": 1, "lastCompletedActionInstanceID": "legacy-completed-instance"],
            ],
            "records": [
                [
                    "actionInstanceID": "legacy-completed-instance",
                    "settlementID": "legacy-completed-settlement",
                    "settled": true,
                    "context": try contextJSON(context),
                    "status": "completed",
                    "selected": [
                        "snapshot": ["event": try eventJSON(completedEvent), "characters": [try characterJSON(EventTestFixtures.playerCharacter)]],
                        "currentDialogueID": completedEvent.dialogues.last!.id,
                    ],
                ],
                [
                    "actionInstanceID": "legacy-in-progress-instance",
                    "settlementID": "legacy-in-progress-settlement",
                    "settled": true,
                    "context": try contextJSON(context),
                    "status": "in_progress",
                    "selected": [
                        "snapshot": ["event": try eventJSON(inProgressEvent), "characters": [try characterJSON(EventTestFixtures.playerCharacter)]],
                        "currentDialogueID": inProgressEvent.dialogues.first!.id,
                    ],
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        defaults.set(data, forKey: "EventProgressStore.save")

        let store = EventProgressStore(defaults: defaults)
        let save = store.currentSave()

        #expect(save.schemaVersion == PlayerEventSave.currentSchemaVersion)
        #expect(save.triggeredEventIDs == [completedEvent.id, inProgressEvent.id])
        // Original progress preserved exactly.
        #expect(save.record(for: "legacy-completed-instance")?.status == .completed)
        #expect(save.record(for: "legacy-in-progress-instance")?.selected?.currentDialogueID == inProgressEvent.dialogues.first!.id)

        // Migration is durable — re-reading from the same defaults doesn't need to
        // migrate again (and neither event can retrigger).
        let reloaded = EventProgressStore(defaults: defaults)
        #expect(reloaded.currentSave().triggeredEventIDs == [completedEvent.id, inProgressEvent.id])
    }

    // MARK: - JSON helpers (round-trip through the real Codable models so the fixture
    // JSON always matches the actual on-disk shape, not a hand-guessed one)

    private func contextJSON(_ context: EventActionContext) throws -> [String: Any] {
        try asJSONObject(context)
    }

    private func eventJSON(_ event: GameEvent) throws -> [String: Any] {
        try asJSONObject(event)
    }

    private func characterJSON(_ character: EventCharacter) throws -> [String: Any] {
        try asJSONObject(character)
    }

    private func asJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
