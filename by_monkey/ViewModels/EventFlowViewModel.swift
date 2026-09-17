//
//  EventFlowViewModel.swift
//  by_monkey
//

import Foundation

/// Drives dialogue progression for one already-selected, already-persisted event. Never
/// decides *whether* an event happens (that's `EventConditionEvaluator`/`EventSelector`
/// via `WorkSessionCoordinator`) and never touches money — purely: which line is
/// showing, and persisting/completing progress through `EventProgressStore`.
final class EventFlowViewModel {

    enum Stage: Equatable {
        case line(EventDialogue)
        case finished
        /// Stayed on the last line because persisting completion failed; retry re-runs
        /// the same completion attempt, never a fresh decision.
        case completionFailed(EventDialogue)
    }

    let actionInstanceID: String
    let event: GameEvent
    let characters: [EventCharacter]
    let playerName: String

    private(set) var stage: Stage
    var onStageChanged: (() -> Void)?

    private let progressStore: EventProgressStoring

    /// `currentDialogueID` resumes exactly where a persisted record left off — never
    /// index-based, per FORMAT.md's "存檔用 ID，不用陣列索引".
    init(actionInstanceID: String,
         snapshot: EventPlaybackSnapshot,
         currentDialogueID: String,
         playerName: String,
         progressStore: EventProgressStoring = EventProgressStore.shared) {
        self.actionInstanceID = actionInstanceID
        self.event = snapshot.event
        self.characters = snapshot.characters
        self.playerName = playerName
        self.progressStore = progressStore

        if let line = snapshot.event.dialogue(id: currentDialogueID) {
            stage = .line(line)
        } else {
            // EventValidator should have caught an invalid cursor before this view
            // model ever gets constructed; fail safe to the first line rather than
            // crashing on a corrupt resume value.
            stage = snapshot.event.dialogues.first.map { .line($0) } ?? .finished
        }
    }

    var currentLine: EventDialogue? {
        switch stage {
        case .line(let line), .completionFailed(let line): return line
        case .finished: return nil
        }
    }

    var isLastLine: Bool {
        currentLine?.id == event.dialogues.last?.id
    }

    var progressText: String {
        let total = event.dialogues.count
        guard let line = currentLine, let index = event.dialogues.firstIndex(where: { $0.id == line.id }) else {
            return String(format: "%02d / %02d", total, total)
        }
        return String(format: "%02d / %02d", index + 1, total)
    }

    var continuePromptText: String {
        switch stage {
        case .line: return isLastLine ? "結束事件" : "點擊繼續"
        case .completionFailed: return "重試"
        case .finished: return ""
        }
    }

    func character(id characterID: String) -> EventCharacter? {
        characters.first { $0.id == characterID }
    }

    func speakerDisplayName(for line: EventDialogue) -> String {
        character(id: line.speakerID)?.name.resolved(playerName: playerName) ?? line.speakerID
    }

    func resolvedText(for line: EventDialogue) -> String {
        line.resolvedText(playerName: playerName)
    }

    /// Advances to the next line, retries a failed completion, or — from the last line —
    /// attempts to finish the event. Never replays from the start, never re-decides.
    func advance() {
        switch stage {
        case .line(let line):
            guard let index = event.dialogues.firstIndex(where: { $0.id == line.id }) else { return }
            if index < event.dialogues.count - 1 {
                let next = event.dialogues[index + 1]
                stage = .line(next)
                // Best-effort: losing the very latest line position to a transient save
                // failure mid-event is a minor resume regression, not a duplication bug,
                // so this doesn't block the UI the way completion does.
                progressStore.saveDialogueProgress(actionInstanceID: actionInstanceID, dialogueID: next.id)
                onStageChanged?()
            } else {
                attemptCompletion(currentLine: line)
            }
        case .completionFailed(let line):
            attemptCompletion(currentLine: line)
        case .finished:
            break
        }
    }

    private func attemptCompletion(currentLine: EventDialogue) {
        switch progressStore.completeEvent(actionInstanceID: actionInstanceID) {
        case .success:
            stage = .finished
        case .failure:
            stage = .completionFailed(currentLine)
        }
        onStageChanged?()
    }
}
