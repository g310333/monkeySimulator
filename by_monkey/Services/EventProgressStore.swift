//
//  EventProgressStore.swift
//  by_monkey
//

import Foundation

enum EventProgressStoreError: Error {
    case saveFailed
    case recordNotFound
}

/// Single shared source of truth for the player's `PlayerEventSave` — every judged
/// action instance, every no-event reason, every in-progress/completed event snapshot.
/// Backed by UserDefaults (this project's only existing writable-save mechanism; see
/// `PlayerProfileStore`), with the *entire* save written as one JSON blob per mutation
/// so a write is atomic from the app's point of view — there's no way to observe a save
/// with some fields updated and others not.
///
/// All mutating entry points take an internal lock for their whole critical section
/// (check-existing → decide → persist), which is what "同一 actionInstanceID 的判定由
/// 單一序列化流程處理" (FORMAT.md §5) means in a codebase with no Swift concurrency
/// actors yet — it serializes concurrent callers without requiring the rest of the
/// synchronous UIKit call chain to become `async`.
protocol EventProgressStoring: AnyObject {
    func currentSave() -> PlayerEventSave
    func existingRecord(for actionInstanceID: String) -> EventActionRecord?

    /// Decides (once) whether `actionInstanceID` gets an event, or reuses whatever was
    /// already decided. `decide` may be called more than once across retries after a
    /// save failure — the *caller* is responsible for caching its own result so a retry
    /// re-submits the same outcome rather than rolling again (see `WorkSessionCoordinator`).
    /// `availableCharacters` is only used to build the frozen snapshot for a selected
    /// event (passed in rather than loaded internally, so this store has no dependency
    /// on `EventRepository`).
    ///
    /// `decide` receives the save exactly as it stood at the start of this call, already
    /// unlocked-internal access — it must not call back into `currentSave()` (or any
    /// other locking method on this store) itself. This whole method runs under the
    /// store's lock, and `NSLock` isn't reentrant: a nested `lock.lock()` from the same
    /// thread deadlocks forever, which is exactly why the save is handed in as a plain
    /// value instead of the closure fetching it.
    func decideIfNeeded(
        actionInstanceID: String,
        settlementID: String,
        context: EventActionContext,
        availableCharacters: [EventCharacter],
        decide: (PlayerEventSave) -> EventDecisionOutcome
    ) -> Result<EventActionRecord, EventProgressStoreError>

    func saveDialogueProgress(actionInstanceID: String, dialogueID: String) -> Result<EventActionRecord, EventProgressStoreError>

    /// Marks the record completed and updates `history` in the same write. Re-entrant:
    /// calling this again on an already-completed record is a no-op that returns the
    /// existing record unchanged (never double-counts `completionCount`).
    func completeEvent(actionInstanceID: String) -> Result<EventActionRecord, EventProgressStoreError>
}

final class EventProgressStore: EventProgressStoring {

    static let shared = EventProgressStore()

    private let defaults: UserDefaults
    private let storageKey = "EventProgressStore.save"
    private let lock = NSLock()

    private var save: PlayerEventSave
    /// In-memory only: caches a freshly-rolled (but not yet persisted) outcome so a
    /// save-failure retry within the same app run resubmits it instead of re-rolling.
    /// Deliberately *not* persisted — FORMAT.md §5 explicitly accepts that a crash
    /// before the first successful commit may re-roll on relaunch; only a committed
    /// result is guaranteed stable.
    private var pendingOutcomes: [String: EventDecisionOutcome] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: storageKey) else {
            save = .empty
            return
        }
        if let decoded = try? JSONDecoder().decode(PlayerEventSave.self, from: data) {
            save = decoded
        } else if let migrated = Self.migrateLegacySave(data) {
            save = migrated
            // Persist the migrated shape immediately so this only happens once, not on
            // every launch.
            _ = persist(migrated)
        } else {
            save = .empty
        }
    }

    /// A pre-`triggeredEventIDs` save (schemaVersion 1) fails the normal decode above
    /// because that field is now required. Recovers it by decoding the old shape and
    /// deriving `triggeredEventIDs` as the union of every completed event (`history`)
    /// and every event that was ever selected into a record (`in_progress`/`completed`)
    /// — exactly preserving existing progress under the new once-ever-per-save rule.
    private static func migrateLegacySave(_ data: Data) -> PlayerEventSave? {
        struct LegacyPlayerEventSave: Decodable {
            let schemaVersion: Int
            let flags: [String]
            let history: [EventCompletionHistory]
            let records: [EventActionRecord]
        }
        guard let legacy = try? JSONDecoder().decode(LegacyPlayerEventSave.self, from: data) else { return nil }

        var triggeredEventIDs = Set(legacy.history.map { $0.eventID })
        for record in legacy.records {
            if let eventID = record.selected?.snapshot.event.id {
                triggeredEventIDs.insert(eventID)
            }
        }

        return PlayerEventSave(
            schemaVersion: PlayerEventSave.currentSchemaVersion,
            flags: legacy.flags,
            history: legacy.history,
            records: legacy.records,
            triggeredEventIDs: triggeredEventIDs
        )
    }

    func currentSave() -> PlayerEventSave {
        lock.lock(); defer { lock.unlock() }
        return save
    }

    func existingRecord(for actionInstanceID: String) -> EventActionRecord? {
        lock.lock(); defer { lock.unlock() }
        return save.record(for: actionInstanceID)
    }

    func decideIfNeeded(
        actionInstanceID: String,
        settlementID: String,
        context: EventActionContext,
        availableCharacters: [EventCharacter],
        decide: (PlayerEventSave) -> EventDecisionOutcome
    ) -> Result<EventActionRecord, EventProgressStoreError> {
        lock.lock(); defer { lock.unlock() }

        if let existing = save.record(for: actionInstanceID) {
            // Already judged (possibly further along than `pending`) — never re-decide.
            return .success(existing)
        }

        let outcome = pendingOutcomes[actionInstanceID] ?? decide(save)
        pendingOutcomes[actionInstanceID] = outcome

        let record: EventActionRecord
        switch outcome {
        case .noEvent(let reason):
            record = EventActionRecord(
                actionInstanceID: actionInstanceID, settlementID: settlementID, settled: true,
                context: context, status: .noEvent, noEventReason: reason, selected: nil
            )
        case .event(let event):
            guard let firstDialogueID = event.dialogues.first?.id else {
                return .failure(.saveFailed)
            }
            // Snapshot both the event and the characters it actually references, frozen
            // at selection time (FORMAT.md §5: a later content edit must never change
            // what an already-selected playthrough shows).
            let participantSet = Set(event.participants)
            let snapshotCharacters = availableCharacters.filter { participantSet.contains($0.id) }
            let snapshot = EventPlaybackSnapshot(event: event, characters: snapshotCharacters)
            record = EventActionRecord(
                actionInstanceID: actionInstanceID, settlementID: settlementID, settled: true,
                context: context, status: .inProgress, noEventReason: nil,
                selected: EventSelection(snapshot: snapshot, currentDialogueID: firstDialogueID)
            )
        }

        var updated = save
        updated.records.append(record)
        if case .event(let event) = outcome {
            // Same write as the record itself — this is the "single transaction" that
            // makes the event count as triggered: if persistence fails, neither the
            // record nor this insertion happened, and the cached outcome is retried
            // (never re-rolled) rather than silently marking it triggered anyway.
            updated.triggeredEventIDs.insert(event.id)
        }
        switch persist(updated) {
        case .success:
            pendingOutcomes.removeValue(forKey: actionInstanceID)
            return .success(record)
        case .failure(let error):
            // Outcome stays cached in `pendingOutcomes` for the next retry.
            return .failure(error)
        }
    }

    func saveDialogueProgress(actionInstanceID: String, dialogueID: String) -> Result<EventActionRecord, EventProgressStoreError> {
        lock.lock(); defer { lock.unlock() }
        guard let index = save.records.firstIndex(where: { $0.actionInstanceID == actionInstanceID }),
              save.records[index].selected != nil else {
            return .failure(.recordNotFound)
        }
        var updated = save
        updated.records[index].selected?.currentDialogueID = dialogueID
        return persistAndReturn(updated, actionInstanceID: actionInstanceID)
    }

    func completeEvent(actionInstanceID: String) -> Result<EventActionRecord, EventProgressStoreError> {
        lock.lock(); defer { lock.unlock() }
        guard let index = save.records.firstIndex(where: { $0.actionInstanceID == actionInstanceID }) else {
            return .failure(.recordNotFound)
        }
        if save.records[index].status == .completed {
            // Re-entrant: already completed, never double-count.
            return .success(save.records[index])
        }
        guard save.records[index].selected != nil else {
            return .failure(.recordNotFound)
        }

        var updated = save
        updated.records[index].status = .completed
        let eventID = updated.records[index].selected!.snapshot.event.id

        if let historyIndex = updated.history.firstIndex(where: { $0.eventID == eventID }) {
            updated.history[historyIndex].completionCount += 1
            updated.history[historyIndex].lastCompletedActionInstanceID = actionInstanceID
        } else {
            updated.history.append(EventCompletionHistory(eventID: eventID, completionCount: 1, lastCompletedActionInstanceID: actionInstanceID))
        }

        return persistAndReturn(updated, actionInstanceID: actionInstanceID)
    }

    // MARK: - Helpers

    private func persistAndReturn(_ updated: PlayerEventSave, actionInstanceID: String) -> Result<EventActionRecord, EventProgressStoreError> {
        switch persist(updated) {
        case .success:
            return .success(updated.record(for: actionInstanceID)!)
        case .failure(let error):
            return .failure(error)
        }
    }

    @discardableResult
    private func persist(_ updated: PlayerEventSave) -> Result<Void, EventProgressStoreError> {
        guard let data = try? JSONEncoder().encode(updated) else { return .failure(.saveFailed) }
        defaults.set(data, forKey: storageKey)
        // Same defensive pattern as `PlayerProfileStore`/prior `EventLogStore`:
        // `synchronize()` is deprecated but is still the only synchronous signal
        // UserDefaults gives that the write reached disk.
        guard defaults.synchronize() else { return .failure(.saveFailed) }
        save = updated
        return .success(())
    }
}
