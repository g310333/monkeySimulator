//
//  EventSelector.swift
//  by_monkey
//

import Foundation

/// A uniform value in [0, 1). Injectable so chance/weight boundary behavior — including
/// a fixed sequence of values — can be tested deterministically instead of relying on
/// real randomness.
protocol EventRandomSource {
    func nextUniformValue() -> Double
}

struct SystemEventRandomSource: EventRandomSource {
    func nextUniformValue() -> Double { Double.random(in: 0..<1) }
}

/// FORMAT.md §4 steps 6–7: chance and weight are two independent draws from the same
/// RNG, in that order — never conflate them into one roll.
protocol EventSelecting {
    func draw(candidates: [GameEvent], eventChance: Double, rng: EventRandomSource) -> EventDecisionOutcome
}

struct EventSelector: EventSelecting {

    /// `candidates` must already be the eligible set. An empty list is the caller's
    /// responsibility to turn into `.noEligibleEvents` *before* any chance roll happens
    /// (FORMAT.md §4 step 5 — no candidates skips sampling entirely).
    func draw(candidates: [GameEvent], eventChance: Double, rng: EventRandomSource) -> EventDecisionOutcome {
        guard !candidates.isEmpty else {
            return .noEvent(reason: .noEligibleEvents)
        }

        let u = rng.nextUniformValue()
        guard u < eventChance else {
            return .noEvent(reason: .chanceMissed)
        }

        // Deterministic ordering by ID (FORMAT.md §4 step 4) so the same candidate set
        // always maps the same way onto a given `v`.
        let ordered = candidates.sorted { $0.id < $1.id }
        let totalWeight = ordered.reduce(0) { $0 + $1.selectionWeight }
        let v = rng.nextUniformValue() * Double(totalWeight)

        var cumulative = 0.0
        for candidate in ordered {
            cumulative += Double(candidate.selectionWeight)
            if v < cumulative {
                return .event(candidate)
            }
        }
        // Floating-point edge case exactly at the top of the range.
        return .event(ordered[ordered.count - 1])
    }
}
