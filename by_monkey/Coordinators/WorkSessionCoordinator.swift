//
//  WorkSessionCoordinator.swift
//  by_monkey
//

import UIKit

/// Owns the whole post-"打工" flow: present the work screen, and once (and only once)
/// its payout is claimed, run the JSON-driven event pipeline
/// (GameEventData/FORMAT.md §4's "filter conditions → roll chance → pick by weight")
/// and drive whatever it decides.
///
/// This exists specifically so `WorkViewController`/`EventViewController` never decide
/// events, persist decisions, or own the pipeline services themselves — that logic
/// lives here and in the injected `EventRepositoryProviding` / `EventValidating` /
/// `EventConditionEvaluating` / `EventSelecting` / `EventProgressStoring` collaborators.
final class WorkSessionCoordinator {

    private static let workBackgroundAsset = "shop"
    private static let workLocationName = "便利商店"

    private let hudSnapshotProvider: () -> PlayerHUDSnapshot
    private let repository: EventRepositoryProviding
    private let validator: EventValidating
    private let conditionEvaluator: EventConditionEvaluating
    private let selector: EventSelecting
    private let randomSource: EventRandomSource
    private let progressStore: EventProgressStoring
    private let profileStore: PlayerProfileStore
    private let onFinished: (String) -> Void

    private weak var workViewController: WorkViewController?

    init(hudSnapshotProvider: @escaping () -> PlayerHUDSnapshot,
         repository: EventRepositoryProviding = BundleEventRepository.shared,
         validator: EventValidating = EventValidator(),
         conditionEvaluator: EventConditionEvaluating = EventConditionEvaluator(),
         selector: EventSelecting = EventSelector(),
         randomSource: EventRandomSource = SystemEventRandomSource(),
         progressStore: EventProgressStoring = EventProgressStore.shared,
         profileStore: PlayerProfileStore = .shared,
         onFinished: @escaping (String) -> Void) {
        self.hudSnapshotProvider = hudSnapshotProvider
        self.repository = repository
        self.validator = validator
        self.conditionEvaluator = conditionEvaluator
        self.selector = selector
        self.randomSource = randomSource
        self.progressStore = progressStore
        self.profileStore = profileStore
        self.onFinished = onFinished
    }

    func start(presentingFrom viewController: UIViewController) {
        let work = WorkViewController(hudSnapshotProvider: hudSnapshotProvider)
        work.onPayoutClaimed = { [weak self] payout, actionInstanceID, settlementID in
            self?.handlePayoutClaimed(payout: payout, actionInstanceID: actionInstanceID, settlementID: settlementID)
        }
        workViewController = work

        // The action-transition curtain already covers the screen at the moment this
        // runs, so the switch itself should be invisible — no extra system animation.
        viewController.present(work, animated: false)
    }

    // MARK: - Step 1: settlement confirmed, decide the event

    private func handlePayoutClaimed(payout: Int, actionInstanceID: UUID, settlementID: UUID) {
        // FORMAT.md §4 step 1 is already satisfied here: this only ever runs from
        // `WorkViewController.onPayoutClaimed`, which only fires after
        // `WorkViewModel.claimPayout` has succeeded — there is no other call path into
        // event judging.
        let snapshot = hudSnapshotProvider()
        let context = EventActionContext(
            action: .work,
            day: snapshot.dayNumber,
            timePeriod: snapshot.selectedTimeOfDay.eventTimePeriod,
            moneyAfterSettlement: profileStore.money,
            playerName: profileStore.playerName,
            backgroundAsset: Self.workBackgroundAsset,
            locationName: Self.workLocationName
        )

        guard let catalog = loadValidatedCatalog() else {
            // Content is broken — already logged loudly inside loadValidatedCatalog().
            // Never silently record this as "no event"; just skip the event system for
            // this action instance without writing any record at all. The payout is
            // already safely committed regardless.
            finish(payout: payout)
            return
        }

        do {
            try validator.validateTriggeredConsistency(progressStore.currentSave())
        } catch {
            print("[WorkSessionCoordinator] event save inconsistent — skipping event system for this action instance: \(error)")
            finish(payout: payout)
            return
        }

        let result = progressStore.decideIfNeeded(
            actionInstanceID: actionInstanceID.uuidString,
            settlementID: settlementID.uuidString,
            context: context,
            availableCharacters: catalog.characters
        ) { [weak self] save in
            // `save` is handed in by `decideIfNeeded` itself — never re-fetch it via
            // `progressStore.currentSave()` here. This closure runs while
            // `EventProgressStore` still holds its (non-reentrant) lock, and calling
            // back into any of its locking methods from inside it deadlocks the app.
            self?.decide(catalog: catalog, context: context, save: save) ?? .noEvent(reason: .noEligibleEvents)
        }

        switch result {
        case .success(let record):
            apply(record, payout: payout)
        case .failure:
            // The payout itself is already safely committed — only the event
            // bookkeeping failed. Retry re-enters this same method, which re-uses the
            // already-cached outcome inside `EventProgressStore` rather than re-rolling.
            workViewController?.showEventDecisionSaveFailure { [weak self] in
                self?.handlePayoutClaimed(payout: payout, actionInstanceID: actionInstanceID, settlementID: settlementID)
            }
        }
    }

    // MARK: - Steps 2–7: rule check → filter → chance → weight

    private struct EventCatalogSnapshot {
        let characters: [EventCharacter]
        let events: [GameEvent]
        let rules: [EventActionRule]
    }

    private func loadValidatedCatalog() -> EventCatalogSnapshot? {
        do {
            let characters = try repository.loadCharacters()
            let events = try repository.loadEvents()
            let rules = try repository.loadRules()
            try validator.validateCharacters(characters)
            try validator.validateEvents(events, characters: characters)
            try validator.validateRules(rules)
            return EventCatalogSnapshot(characters: characters, events: events, rules: rules)
        } catch {
            print("[WorkSessionCoordinator] event content invalid — skipping event system for this action instance: \(error)")
            return nil
        }
    }

    private func decide(catalog: EventCatalogSnapshot, context: EventActionContext, save: PlayerEventSave) -> EventDecisionOutcome {
        #if DEBUG
        if EventDebugSettings.isEnabled {
            return decideWithDebugOverride(events: catalog.events, save: save)
        }
        #endif

        guard let rule = catalog.rules.first(where: { $0.action == context.action }), rule.enabled else {
            return .noEvent(reason: .disabled)
        }

        // FORMAT.md §4 step 4: filter by action/enabled/conditions/once-ever-triggered,
        // ordered by ID for deterministic test behavior.
        let candidates = catalog.events
            .filter { conditionEvaluator.isEligible($0, context: context, save: save) }
            .sorted { $0.id < $1.id }

        return selector.draw(candidates: candidates, eventChance: rule.eventChance, rng: randomSource)
    }

    #if DEBUG
    private func decideWithDebugOverride(events: [GameEvent], save: PlayerEventSave) -> EventDecisionOutcome {
        switch EventDebugSettings.forcedOutcome {
        case .none:
            return .noEvent(reason: .chanceMissed)
        case .any:
            guard let event = events.first(where: { !save.triggeredEventIDs.contains($0.id) }) else {
                return .noEvent(reason: .noEligibleEvents)
            }
            return .event(event)
        case .participantCount(let count):
            // Bypasses rule/day/money/time conditions for convenience, but never the
            // once-ever-per-save rule — that's a save-integrity invariant, not a
            // business rule, and must hold even under a forced test outcome.
            let untriggered = events.filter { !save.triggeredEventIDs.contains($0.id) }
            if let exactMatch = untriggered.first(where: { $0.participants.count == count }) {
                return .event(exactMatch)
            }
            // The specifically requested cast size is already used up in this save —
            // this is exactly what the real (non-debug) pipeline does too: a
            // used-up event doesn't stop the search, it just narrows the candidates.
            // Fall back to any other still-untriggered demo event rather than reporting
            // "no event" just because the one you asked for by name is gone.
            if let fallback = untriggered.first {
                return .event(fallback)
            }
            return .noEvent(reason: .noEligibleEvents)
        }
    }
    #endif

    // MARK: - Step 8: navigate on the persisted result

    private func apply(_ record: EventActionRecord, payout: Int) {
        switch record.status {
        case .pending:
            // `decideIfNeeded` always returns a decided record; fail safe rather than
            // getting stuck if this is ever somehow reached.
            finish(payout: payout)
        case .noEvent, .completed:
            finish(payout: payout)
        case .inProgress:
            guard let selected = record.selected else {
                finish(payout: payout)
                return
            }
            presentEvent(selected: selected, record: record, payout: payout)
        }
    }

    private func presentEvent(selected: EventSelection, record: EventActionRecord, payout: Int) {
        let eventViewModel = EventFlowViewModel(
            actionInstanceID: record.actionInstanceID,
            snapshot: selected.snapshot,
            currentDialogueID: selected.currentDialogueID,
            playerName: profileStore.playerName
        )
        let backgroundAsset = selected.snapshot.event.background.resolvedAssetName(inheritedFrom: record.context.backgroundAsset)
        let eventViewController = EventViewController(
            viewModel: eventViewModel,
            backgroundAssetName: backgroundAsset,
            locationName: record.context.locationName,
            dayNumber: record.context.day,
            timePeriod: record.context.timePeriod.timeOfDay
        )
        eventViewController.onFinished = { [weak self] in
            self?.finish(payout: payout)
        }
        workViewController?.embedEvent(eventViewController)
    }

    private func finish(payout: Int) {
        let message = "打工收入 ＋\(profileStore.formattedAmount(payout)) 已入帳"
        workViewController?.finishAndReturn { [weak self] in
            self?.onFinished(message)
        }
    }
}
