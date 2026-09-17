//
//  EventRepositoryTests.swift
//  by_monkeyTests
//

import Testing
import Foundation
@testable import by_monkey

struct EventRepositoryTests {

    /// `by_monkeyTests` is a host-app-hosted test target, so `Bundle.main` here is the
    /// real by_monkey app bundle — this exercises the actual shipped
    /// characters.json/events_work.json/event_rules.json, not a fixture copy.
    @Test func realBundledContentDecodesAndValidates() throws {
        let repository = BundleEventRepository(bundle: .main)
        let characters = try repository.loadCharacters()
        let events = try repository.loadEvents()
        let rules = try repository.loadRules()

        #expect(characters.map { $0.id }.sorted() == ["boss", "coworker", "player"])
        #expect(events.count == 3)
        #expect(rules.count == 4)

        let validator = EventValidator()
        try validator.validateCharacters(characters)
        try validator.validateEvents(events, characters: characters)
        try validator.validateRules(rules)
    }

    @Test func productionRulesShipDisabled() throws {
        let repository = BundleEventRepository(bundle: .main)
        let rules = try repository.loadRules()
        // event_rules.json ships with every action disabled — the real trigger rate
        // hasn't been decided, and this must not silently start passing if someone
        // enables it without updating this test deliberately.
        #expect(rules.allSatisfy { !$0.enabled && $0.eventChance == 0 })
    }

    @Test func missingResourceThrowsRatherThanSilentlyReturningNoData() {
        let emptyBundle = Bundle(path: NSTemporaryDirectory())!
        let repository = BundleEventRepository(bundle: emptyBundle)
        #expect(throws: EventRepositoryError.self) {
            try repository.loadCharacters()
        }
    }

    @Test func corruptJSONThrowsRatherThanSilentlyReturningNoData() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "{ not valid json".data(using: .utf8)!.write(to: directory.appendingPathComponent("characters.json"))

        let bundle = Bundle(path: directory.path)!
        let repository = BundleEventRepository(bundle: bundle)
        #expect(throws: EventRepositoryError.self) {
            try repository.loadCharacters()
        }
    }

    @Test func legacyEventsSchemaVersionIsRejectedNotSilentlyAccepted() throws {
        // v2 dropped `repeatable` — a v1 events file must be refused outright rather
        // than silently treated as "no events" or auto-migrated at runtime.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyEventsJSON = """
        {"schemaVersion": 1, "events": []}
        """
        try legacyEventsJSON.data(using: .utf8)!.write(to: directory.appendingPathComponent("events_work.json"))

        let bundle = Bundle(path: directory.path)!
        let repository = BundleEventRepository(bundle: bundle)
        #expect(throws: EventRepositoryError.self) {
            try repository.loadEvents()
        }
    }
}
