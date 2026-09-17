//
//  EventValidatorTests.swift
//  by_monkeyTests
//

import Testing
@testable import by_monkey

struct EventValidatorTests {

    /// Asset existence stubbed out so these tests don't depend on the real asset catalog.
    let validator = EventValidator(assetExists: { _ in true })

    @Test func validEventPassesValidation() throws {
        let event = EventTestFixtures.makeEvent()
        try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
    }

    @Test func duplicateEventIDsAreRejected() {
        let event = EventTestFixtures.makeEvent()
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event, event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func unknownParticipantIsRejected() {
        let event = EventTestFixtures.makeEvent(participants: ["ghost"])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func emptyDialoguesIsRejected() {
        let event = EventTestFixtures.makeEvent(dialogues: [])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func speakerNotInStageIsRejected() {
        let line = EventDialogue(id: "line_001", speakerID: "boss", text: "hi", stage: [EventStageActor(characterID: "player", slot: .center)])
        let event = EventTestFixtures.makeEvent(participants: ["player", "boss"], dialogues: [line])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func duplicateSlotIsRejected() {
        let line = EventDialogue(
            id: "line_001", speakerID: "player", text: "hi",
            stage: [EventStageActor(characterID: "player", slot: .left), EventStageActor(characterID: "boss", slot: .left)]
        )
        let event = EventTestFixtures.makeEvent(participants: ["player", "boss"], dialogues: [line])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func wrongSlotSetForParticipantCountIsRejected() {
        // Two people on stage must use left/right, not left/center.
        let line = EventDialogue(
            id: "line_001", speakerID: "player", text: "hi",
            stage: [EventStageActor(characterID: "player", slot: .left), EventStageActor(characterID: "boss", slot: .center)]
        )
        let event = EventTestFixtures.makeEvent(participants: ["player", "boss"], dialogues: [line])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func emptyTextIsRejected() {
        let line = EventDialogue(id: "line_001", speakerID: "player", text: "", stage: [EventStageActor(characterID: "player", slot: .center)])
        let event = EventTestFixtures.makeEvent(dialogues: [line])
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func dayRangeContradictionIsRejected() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(minimumDay: 8, maximumDay: 2))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func moneyRangeContradictionIsRejected() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(minimumMoney: 900, maximumMoney: 100))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func overlappingFlagsAreRejected() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredFlags: ["a"], excludedFlags: ["a"]))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func illegalWeightIsRejected() {
        let event = EventTestFixtures.makeEvent(selectionWeight: 0)
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func unknownPrerequisiteEventIsRejected() {
        let event = EventTestFixtures.makeEvent(conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["missing_event"]))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func selfReferencingPrerequisiteCycleIsRejected() {
        let event = EventTestFixtures.makeEvent(id: "work_self", conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["work_self"]))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([event], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func twoEventPrerequisiteCycleIsRejected() {
        let a = EventTestFixtures.makeEvent(id: "work_a", conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["work_b"]))
        let b = EventTestFixtures.makeEvent(id: "work_b", conditions: EventTestFixtures.conditions(requiredCompletedEventIDs: ["work_a"]))
        #expect(throws: EventValidationError.self) {
            try validator.validateEvents([a, b], characters: EventTestFixtures.allCharacters)
        }
    }

    @Test func illegalChanceIsRejected() {
        let rule = EventActionRule(action: .work, enabled: true, eventChance: 1.5)
        #expect(throws: EventValidationError.self) {
            try validator.validateRules([rule])
        }
    }

    @Test func boundaryChancesAreAccepted() throws {
        try validator.validateRules([
            EventActionRule(action: .work, enabled: true, eventChance: 0),
            EventActionRule(action: .stocks, enabled: true, eventChance: 1),
        ])
    }

    // MARK: - Save record consistency (mirrors Tools/validate.py's save_check)

    @Test func pendingRecordWithSelectedIsRejected() {
        let context = EventTestFixtures.makeContext()
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .pending, noEventReason: nil, selected: makeSelection())
        #expect(throws: EventValidationError.self) {
            try validator.validateRecord(record)
        }
    }

    @Test func noEventWithoutReasonIsRejected() {
        let context = EventTestFixtures.makeContext()
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .noEvent, noEventReason: nil, selected: nil)
        #expect(throws: EventValidationError.self) {
            try validator.validateRecord(record)
        }
    }

    @Test func unknownDialogueCursorIsRejected() {
        let context = EventTestFixtures.makeContext()
        var selection = makeSelection()
        selection.currentDialogueID = "does_not_exist"
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: selection)
        #expect(throws: EventValidationError.self) {
            try validator.validateRecord(record)
        }
    }

    @Test func completedRecordNotOnLastLineIsRejected() {
        let context = EventTestFixtures.makeContext()
        // Two-line event so a cursor pointing at the *first* line while status is
        // `completed` is actually a distinct, invalid state (a single-line fixture
        // would have its only line double as the last line, masking this check).
        let event = EventTestFixtures.makeEvent(dialogues: [
            EventDialogue(id: "line_001", speakerID: "player", text: "first", stage: [EventStageActor(characterID: "player", slot: .center)]),
            EventDialogue(id: "line_002", speakerID: "player", text: "second", stage: [EventStageActor(characterID: "player", slot: .center)]),
        ])
        let snapshot = EventPlaybackSnapshot(event: event, characters: [EventTestFixtures.playerCharacter])
        let selection = EventSelection(snapshot: snapshot, currentDialogueID: "line_001")
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .completed, noEventReason: nil, selected: selection)
        #expect(throws: EventValidationError.self) {
            try validator.validateRecord(record)
        }
    }

    @Test func validInProgressRecordPasses() throws {
        let context = EventTestFixtures.makeContext()
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: makeSelection())
        try validator.validateRecord(record)
    }

    // MARK: - triggeredEventIDs consistency

    @Test func matchingTriggeredEventIDsPasses() throws {
        let context = EventTestFixtures.makeContext()
        let selection = makeSelection()
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: selection)
        let save = PlayerEventSave(schemaVersion: PlayerEventSave.currentSchemaVersion, flags: [], history: [], records: [record], triggeredEventIDs: [selection.snapshot.event.id])
        try validator.validateTriggeredConsistency(save)
    }

    @Test func missingTriggeredEventIDIsRejected() {
        let context = EventTestFixtures.makeContext()
        let selection = makeSelection()
        let record = EventActionRecord(actionInstanceID: "a", settlementID: "s", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: selection)
        let save = PlayerEventSave(schemaVersion: PlayerEventSave.currentSchemaVersion, flags: [], history: [], records: [record], triggeredEventIDs: [])
        #expect(throws: EventValidationError.self) {
            try validator.validateTriggeredConsistency(save)
        }
    }

    @Test func sameEventSelectedByTwoRecordsIsToleratedAsLegitimateMigratedHistory() throws {
        // The runtime pipeline (EventConditionEvaluator) is what actually prevents a
        // *new* duplicate selection from ever being created going forward. This
        // validator's job is narrower: confirm `triggeredEventIDs` matches what's
        // selected. A migrated save can legitimately carry several old records that
        // selected the same once-repeatable event before the one-shot rule existed —
        // that must not be flagged as corrupt (see FORMAT.md §5's migration contract).
        let context = EventTestFixtures.makeContext()
        let selectionA = makeSelection()
        let selectionB = makeSelection() // same underlying event id as selectionA
        let recordA = EventActionRecord(actionInstanceID: "a", settlementID: "sa", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: selectionA)
        let recordB = EventActionRecord(actionInstanceID: "b", settlementID: "sb", settled: true, context: context, status: .inProgress, noEventReason: nil, selected: selectionB)
        let save = PlayerEventSave(schemaVersion: PlayerEventSave.currentSchemaVersion, flags: [], history: [], records: [recordA, recordB], triggeredEventIDs: [selectionA.snapshot.event.id])
        try validator.validateTriggeredConsistency(save)
    }

    private func makeSelection() -> EventSelection {
        let event = EventTestFixtures.makeEvent()
        let snapshot = EventPlaybackSnapshot(event: event, characters: [EventTestFixtures.playerCharacter])
        return EventSelection(snapshot: snapshot, currentDialogueID: "line_001")
    }
}
