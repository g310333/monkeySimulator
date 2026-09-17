//
//  EventFlowViewModelTests.swift
//  by_monkeyTests
//

import Testing
import Foundation
@testable import by_monkey

struct EventFlowViewModelTests {

    private func makeSnapshot() -> EventPlaybackSnapshot {
        let event = EventTestFixtures.makeEvent(dialogues: [
            EventDialogue(id: "line_001", speakerID: "player", text: "first", stage: [EventStageActor(characterID: "player", slot: .center)]),
            EventDialogue(id: "line_002", speakerID: "player", text: "second", stage: [EventStageActor(characterID: "player", slot: .center)]),
            EventDialogue(id: "line_003", speakerID: "player", text: "third", stage: [EventStageActor(characterID: "player", slot: .center)]),
        ])
        return EventPlaybackSnapshot(event: event, characters: [EventTestFixtures.playerCharacter])
    }

    /// This is the "interrupted then reopened" scenario: a persisted record's
    /// `currentDialogueID` (not an array index) resumes exactly where it left off,
    /// which is continuing playback, not a fresh trigger.
    @Test func resumesAtThePersistedDialogueIDNotFromTheStart() {
        let store = EventProgressStore(defaults: UserDefaults(suiteName: "EventFlowViewModelTests.\(UUID().uuidString)")!)
        let snapshot = makeSnapshot()
        let viewModel = EventFlowViewModel(
            actionInstanceID: "resume-instance",
            snapshot: snapshot,
            currentDialogueID: "line_002",
            playerName: "阿杰",
            progressStore: store
        )
        #expect(viewModel.currentLine?.id == "line_002")
        #expect(viewModel.progressText == "02 / 03")
    }

    @Test func advancingPersistsTheNextCursor() {
        let store = EventProgressStore(defaults: UserDefaults(suiteName: "EventFlowViewModelTests.\(UUID().uuidString)")!)
        let snapshot = makeSnapshot()
        // Seed a real in-progress record so `saveDialogueProgress` has something to update.
        _ = store.decideIfNeeded(actionInstanceID: "advance-instance", settlementID: "s", context: EventTestFixtures.makeContext(), availableCharacters: [EventTestFixtures.playerCharacter]) { _ in
            .event(snapshot.event)
        }

        let viewModel = EventFlowViewModel(
            actionInstanceID: "advance-instance",
            snapshot: snapshot,
            currentDialogueID: "line_001",
            playerName: "阿杰",
            progressStore: store
        )
        viewModel.advance()

        #expect(viewModel.currentLine?.id == "line_002")
        #expect(store.existingRecord(for: "advance-instance")?.selected?.currentDialogueID == "line_002")
    }

    @Test func finishingOnLastLineCompletesTheRecord() {
        let store = EventProgressStore(defaults: UserDefaults(suiteName: "EventFlowViewModelTests.\(UUID().uuidString)")!)
        let snapshot = makeSnapshot()
        _ = store.decideIfNeeded(actionInstanceID: "finish-instance", settlementID: "s", context: EventTestFixtures.makeContext(), availableCharacters: [EventTestFixtures.playerCharacter]) { _ in
            .event(snapshot.event)
        }

        let viewModel = EventFlowViewModel(
            actionInstanceID: "finish-instance",
            snapshot: snapshot,
            currentDialogueID: "line_003",
            playerName: "阿杰",
            progressStore: store
        )
        #expect(viewModel.continuePromptText == "結束事件")
        viewModel.advance()

        #expect(viewModel.stage == .finished)
        #expect(store.existingRecord(for: "finish-instance")?.status == .completed)
        #expect(store.currentSave().completionCount(for: snapshot.event.id) == 1)
    }
}
