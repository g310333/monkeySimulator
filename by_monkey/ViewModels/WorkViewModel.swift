//
//  WorkViewModel.swift
//  by_monkey
//

import Foundation

/// Drives dialogue progression, work-shift state, and payout for the work mini-game.
/// `WorkViewController` only renders `stage`/`currentLine` and forwards taps here — it
/// never decides game state itself.
final class WorkViewModel {

    enum ClaimOutcome {
        case success(payout: Int, newTotal: Int)
        case failure
    }

    private let profileStore: PlayerProfileStore

    let shift: WorkShift
    let dialogueLines: [DialogueLine]

    private(set) var stage: WorkStage = .dialogue(index: 0)

    /// Fired whenever `stage` changes so the view controller can re-render.
    var onStageChanged: (() -> Void)?

    init(profileStore: PlayerProfileStore = .shared, payout: Int = WorkPayoutRules.convenienceStoreShiftPayout) {
        self.profileStore = profileStore
        self.shift = WorkShift(payout: payout)
        self.dialogueLines = WorkDialogueScript.convenienceStoreOpening(playerName: profileStore.playerName)
    }

    private var currentLineIndex: Int? {
        if case .dialogue(let index) = stage { return index }
        return nil
    }

    var currentLine: DialogueLine? {
        currentLineIndex.map { dialogueLines[$0] }
    }

    var isLastLine: Bool {
        currentLineIndex == dialogueLines.count - 1
    }

    var progressText: String {
        let oneBasedIndex = (currentLineIndex ?? dialogueLines.count - 1) + 1
        return String(format: "%02d / %02d", oneBasedIndex, dialogueLines.count)
    }

    var continuePromptText: String {
        isLastLine ? "結束打工" : "點擊繼續"
    }

    var currentMoneyText: String {
        profileStore.formattedMoney()
    }

    var projectedMoneyText: String {
        profileStore.formattedMoney(profileStore.money + shift.payout)
    }

    var payoutAmountText: String {
        "＋ \(profileStore.formattedAmount(shift.payout))"
    }

    /// Advances to the next dialogue line, or — from the last line — moves to
    /// `.awaitingClaim` so the view controller can present the settlement sheet.
    /// Never replays from the start once dialogue has finished.
    func advance() {
        guard case .dialogue(let index) = stage else { return }
        stage = index < dialogueLines.count - 1 ? .dialogue(index: index + 1) : .awaitingClaim
        onStageChanged?()
    }

    /// Claims this shift's payout exactly once. Guarded by `stage`, not just caller-side
    /// button state, so rapid double taps (or a stray re-invocation) can't double-pay:
    /// only `.awaitingClaim` is accepted, and a failed save rolls back to
    /// `.awaitingClaim` (never `.claimed`) so retrying is safe.
    func claimPayout(completion: @escaping (ClaimOutcome) -> Void) {
        guard stage == .awaitingClaim else { return }
        stage = .claiming
        onStageChanged?()

        switch profileStore.addMoney(shift.payout) {
        case .success(let newTotal):
            stage = .claimed
            onStageChanged?()
            completion(.success(payout: shift.payout, newTotal: newTotal))
        case .failure:
            stage = .awaitingClaim
            onStageChanged?()
            completion(.failure)
        }
    }
}
