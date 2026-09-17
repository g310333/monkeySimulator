//
//  EventRepository.swift
//  by_monkey
//

import Foundation

enum EventRepositoryError: Error, CustomStringConvertible {
    case resourceNotFound(String)
    case decodeFailed(String, underlying: Error)
    case unsupportedSchemaVersion(file: String, version: Int)

    var description: String {
        switch self {
        case .resourceNotFound(let name):
            return "EventRepository: 找不到資源 \(name).json"
        case .decodeFailed(let name, let underlying):
            return "EventRepository: \(name).json 解碼失敗 — \(underlying)"
        case .unsupportedSchemaVersion(let file, let version):
            return "EventRepository: \(file) 的 schemaVersion \(version) 不受支援"
        }
    }
}

/// Reads, decodes, and hands out event content (characters/events/rules) from the app
/// bundle. Loading is by explicit filename — never a directory scan — per
/// GameEventData/README.md's integration notes.
protocol EventRepositoryProviding {
    func loadCharacters() throws -> [EventCharacter]
    func loadEvents() throws -> [GameEvent]
    func loadRules() throws -> [EventActionRule]
}

/// Production repository: reads `characters.json` / `events_work.json` /
/// `event_rules.json` from the app bundle (copied there from
/// GameEventData/Resources — the only three files from that package that ship in the
/// app). Results are decoded once and cached; a decode failure is surfaced to the
/// caller rather than silently degrading to "no events".
final class BundleEventRepository: EventRepositoryProviding {

    static let shared = BundleEventRepository()

    private let bundle: Bundle
    private let supportedCharactersSchemaVersion = 1
    /// v2 dropped `repeatable` (see EventContentModels.swift) — this file is authored
    /// and shipped by us, not a persisted player artifact, so an old v1 file is
    /// rejected outright rather than migrated at runtime.
    private let supportedEventsSchemaVersion = 2
    private let supportedRulesSchemaVersion = 1

    private var cachedCharacters: [EventCharacter]?
    private var cachedEvents: [GameEvent]?
    private var cachedRules: [EventActionRule]?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadCharacters() throws -> [EventCharacter] {
        if let cachedCharacters { return cachedCharacters }
        let fileName = "characters.json"
        let data = try readResource("characters")
        try checkRawStructure(fileName: "characters") { try EventRawStructureValidator.validateCharactersFile(data, fileName: fileName) }
        let file: EventCharacterFile = try decode(data, resourceName: "characters")
        try requireSupportedSchema(file.schemaVersion, expected: supportedCharactersSchemaVersion, fileName: fileName)
        cachedCharacters = file.characters
        return file.characters
    }

    func loadEvents() throws -> [GameEvent] {
        if let cachedEvents { return cachedEvents }
        // Events can be split across multiple files and merged (FORMAT.md §3); today
        // there's only one, but loading through an array keeps that path open without
        // any other code needing to change when a second file is added.
        let fileNames = ["events_work"]
        var merged: [GameEvent] = []
        for resourceName in fileNames {
            let fileName = "\(resourceName).json"
            let data = try readResource(resourceName)
            try checkRawStructure(fileName: resourceName) { try EventRawStructureValidator.validateEventsFile(data, fileName: fileName) }
            let file: GameEventFile = try decode(data, resourceName: resourceName)
            try requireSupportedSchema(file.schemaVersion, expected: supportedEventsSchemaVersion, fileName: fileName)
            merged.append(contentsOf: file.events)
        }
        cachedEvents = merged
        return merged
    }

    func loadRules() throws -> [EventActionRule] {
        if let cachedRules { return cachedRules }
        let fileName = "event_rules.json"
        let data = try readResource("event_rules")
        try checkRawStructure(fileName: "event_rules") { try EventRawStructureValidator.validateRulesFile(data, fileName: fileName) }
        let file: EventRulesFile = try decode(data, resourceName: "event_rules")
        try requireSupportedSchema(file.schemaVersion, expected: supportedRulesSchemaVersion, fileName: fileName)
        cachedRules = file.rules
        return file.rules
    }

    private func requireSupportedSchema(_ version: Int, expected: Int, fileName: String) throws {
        guard version == expected else {
            throw EventRepositoryError.unsupportedSchemaVersion(file: fileName, version: version)
        }
    }

    private func readResource(_ resourceName: String) throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw EventRepositoryError.resourceNotFound(resourceName)
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw EventRepositoryError.decodeFailed(resourceName, underlying: error)
        }
    }

    private func decode<T: Decodable>(_ data: Data, resourceName: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw EventRepositoryError.decodeFailed(resourceName, underlying: error)
        }
    }

    /// Runs a raw-structure check (which parses the JSON itself via
    /// `JSONSerialization`) and translates anything that isn't already our own
    /// `EventValidationError` — e.g. a bare `NSError` from malformed JSON syntax — into
    /// `EventRepositoryError.decodeFailed`, so callers only ever see this repository's
    /// own error types.
    private func checkRawStructure(fileName: String, _ body: () throws -> Void) throws {
        do {
            try body()
        } catch let error as EventValidationError {
            throw error
        } catch {
            throw EventRepositoryError.decodeFailed(fileName, underlying: error)
        }
    }
}
