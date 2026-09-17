//
//  WorkShift.swift
//  by_monkey
//

import Foundation

/// One instance of "doing a work shift". `id` gives each playthrough of the mini-game
/// its own identity so payout logic can reason about "this particular shift", not just
/// "the work screen" in the abstract — a fresh shift (fresh `id`) is what makes a new
/// payout possible after a previous one was already claimed.
struct WorkShift {
    let id = UUID()
    let payout: Int
}

/// Where a `WorkShift` currently sits. `ViewController`s only ever react to this — all
/// transitions happen in `WorkViewModel`.
enum WorkStage: Equatable {
    /// Showing dialogue line `index` (0-based).
    case dialogue(index: Int)
    /// Dialogue finished; the payout sheet is up, waiting for the player to claim it.
    case awaitingClaim
    /// Claim in flight — re-entrant taps must no-op until this resolves.
    case claiming
    /// Payout has been granted for this shift. Terminal: this shift can't pay out again.
    case claimed
}
