//
//  EventCharacterModels.swift
//  by_monkey
//

import Foundation

// Mirrors GameEventData's Resources/characters.json (schema v1). Kept as one file
// because that's exactly the shape of the one JSON resource it decodes — see
// GameEventData/FORMAT.md §2 for field semantics.

enum EventNameSource: String, Codable {
    case fixed
    case playerName
}

enum EventImageSampling: String, Codable {
    case nearest
    case linear
}

struct EventCharacterName: Codable, Equatable {
    let source: EventNameSource
    let fallback: String

    /// `.playerName` resolves to the live player name (never baked in as a literal),
    /// falling back to `fallback` only if that name is somehow empty.
    func resolved(playerName: String) -> String {
        source == .playerName && !playerName.isEmpty ? playerName : fallback
    }
}

struct EventCharacterPresentation: Codable, Equatable {
    let sampling: EventImageSampling
    /// Relative to the UI's own auto-computed base size; 1 = no adjustment.
    let scale: Double
    /// Stage-width fraction; positive = right.
    let offsetX: Double
    /// Stage-height fraction; positive = down.
    let offsetY: Double
}

struct EventCharacter: Codable, Equatable {
    let id: String
    let name: EventCharacterName
    let portraitAsset: String
    let presentation: EventCharacterPresentation
}

struct EventCharacterFile: Codable {
    let schemaVersion: Int
    let characters: [EventCharacter]
}
