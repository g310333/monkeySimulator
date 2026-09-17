//
//  EventSelectorTests.swift
//  by_monkeyTests
//

import Testing
@testable import by_monkey

struct EventSelectorTests {

    let selector = EventSelector()

    @Test func noCandidatesSkipsSamplingEntirely() {
        let rng = FakeEventRandomSource([0.5, 0.5])
        let outcome = selector.draw(candidates: [], eventChance: 1, rng: rng)
        #expect(outcome == .noEvent(reason: .noEligibleEvents))
        #expect(rng.callCount == 0) // FORMAT.md §4 step 5: no candidates, no draw at all.
    }

    @Test func chanceZeroNeverTriggers() {
        let event = EventTestFixtures.makeEvent()
        let rng = FakeEventRandomSource([0.0])
        let outcome = selector.draw(candidates: [event], eventChance: 0, rng: rng)
        #expect(outcome == .noEvent(reason: .chanceMissed))
    }

    @Test func chanceOneAlwaysTriggers() {
        let event = EventTestFixtures.makeEvent()
        let rng = FakeEventRandomSource([0.999999, 0.0])
        let outcome = selector.draw(candidates: [event], eventChance: 1, rng: rng)
        #expect(outcome == .event(event))
    }

    @Test func chanceMissedDoesNotConsumeAWeightDraw() {
        let event = EventTestFixtures.makeEvent()
        let rng = FakeEventRandomSource([0.9])
        _ = selector.draw(candidates: [event], eventChance: 0.5, rng: rng)
        #expect(rng.callCount == 1) // missed on the chance roll — never drew for weight.
    }

    @Test func weightSelectionPicksLowerBucketAtLowV() {
        // IDs deliberately sort alphabetically in weight order (selector orders
        // candidates by ID for deterministic bucketing — see FORMAT.md §4 step 4).
        let low = EventTestFixtures.makeEvent(id: "event_1_low", selectionWeight: 1)
        let high = EventTestFixtures.makeEvent(id: "event_2_high", selectionWeight: 3)
        // total weight 4; v = 0.1 * 4 = 0.4, falls inside "event_1_low" (0..<1)
        let rng = FakeEventRandomSource([0.0, 0.1])
        let outcome = selector.draw(candidates: [low, high], eventChance: 1, rng: rng)
        #expect(outcome == .event(low))
    }

    @Test func weightSelectionPicksUpperBucketAtHighV() {
        let low = EventTestFixtures.makeEvent(id: "event_1_low", selectionWeight: 1)
        let high = EventTestFixtures.makeEvent(id: "event_2_high", selectionWeight: 3)
        // total weight 4; v = 0.9 * 4 = 3.6, falls inside "event_2_high" (1..<4)
        let rng = FakeEventRandomSource([0.0, 0.9])
        let outcome = selector.draw(candidates: [low, high], eventChance: 1, rng: rng)
        #expect(outcome == .event(high))
    }

    @Test func weightSelectionHandlesTopOfRangeFloatingPointEdge() {
        let only = EventTestFixtures.makeEvent(selectionWeight: 1)
        // v = 0.999999... * 1 ≈ total weight; must still resolve to the last candidate.
        let rng = FakeEventRandomSource([0.0, 0.9999999999])
        let outcome = selector.draw(candidates: [only], eventChance: 1, rng: rng)
        #expect(outcome == .event(only))
    }
}
