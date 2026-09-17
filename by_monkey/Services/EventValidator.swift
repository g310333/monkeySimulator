//
//  EventValidator.swift
//  by_monkey
//

import UIKit

/// Points at exactly what's wrong: which file, which event (if any), which field.
/// Never let a decode/validation failure present itself to the player as "no event
/// today" — this type exists so the failure is always identifiable in logs.
struct EventValidationError: Error, CustomStringConvertible, Equatable {
    let file: String
    let eventID: String?
    let field: String?
    let message: String

    var description: String {
        var parts = [file]
        if let eventID { parts.append("event=\(eventID)") }
        if let field { parts.append("field=\(field)") }
        parts.append(message)
        return parts.joined(separator: " | ")
    }
}

/// `Codable` only checks structural shape — it silently accepts out-of-range numbers,
/// dangling cross-references, and (by default) unknown extra keys. Everything here is
/// the semantic layer GameEventData/FORMAT.md and Tools/validate.py describe on top of
/// that, ported to Swift so the app enforces the same contract the data package does.
protocol EventValidating {
    func validateCharacters(_ characters: [EventCharacter]) throws
    func validateEvents(_ events: [GameEvent], characters: [EventCharacter]) throws
    func validateRules(_ rules: [EventActionRule]) throws
    func validateRecord(_ record: EventActionRecord) throws
    /// Cross-checks `PlayerEventSave.triggeredEventIDs` against what's actually
    /// selected across `records` — they must match exactly. Guards against a save
    /// where an event was granted without being recorded as triggered (or vice versa),
    /// which would let it either re-trigger or wrongly stay excluded forever.
    func validateTriggeredConsistency(_ save: PlayerEventSave) throws
}

final class EventValidator: EventValidating {

    private let assetExists: (String) -> Bool

    /// `assetExists` is injectable so tests can validate without touching the real
    /// asset catalog.
    init(assetExists: @escaping (String) -> Bool = { UIImage(named: $0) != nil }) {
        self.assetExists = assetExists
    }

    func validateCharacters(_ characters: [EventCharacter]) throws {
        try requireUnique(characters.map { $0.id }, file: "characters.json", field: "id", label: "角色 ID")
        for character in characters {
            guard assetExists(character.portraitAsset) else {
                throw error("characters.json", nil, "portraitAsset", "未知素材: \(character.portraitAsset)（角色 \(character.id)）")
            }
            let presentation = character.presentation
            guard presentation.scale > 0, presentation.scale <= 3 else {
                throw error("characters.json", nil, "presentation.scale", "倍率超出範圍: \(presentation.scale)（角色 \(character.id)）")
            }
            for (label, value) in [("offsetX", presentation.offsetX), ("offsetY", presentation.offsetY)] {
                guard value >= -1, value <= 1 else {
                    throw error("characters.json", nil, "presentation.\(label)", "位移超出範圍: \(value)（角色 \(character.id)）")
                }
            }
        }
    }

    func validateEvents(_ events: [GameEvent], characters: [EventCharacter]) throws {
        try requireUnique(events.map { $0.id }, file: "events_work.json", field: "id", label: "事件 ID")
        let characterIDs = Set(characters.map { $0.id })
        for event in events {
            try validate(event: event, knownCharacterIDs: characterIDs)
        }
        try validatePrerequisites(events)
    }

    func validateRules(_ rules: [EventActionRule]) throws {
        try requireUnique(rules.map { $0.action.rawValue }, file: "event_rules.json", field: "action", label: "行動")
        for rule in rules {
            guard rule.eventChance >= 0, rule.eventChance <= 1 else {
                throw error("event_rules.json", nil, "eventChance", "非法機率: \(rule.eventChance)（\(rule.action.rawValue)）")
            }
        }
    }

    /// Validates a resumed/persisted record's internal consistency — the same
    /// status/selected/reason/cursor invariants Tools/validate.py's `save_check` enforces.
    func validateRecord(_ record: EventActionRecord) throws {
        let file = "save"
        switch record.status {
        case .pending:
            guard record.selected == nil, record.noEventReason == nil else {
                throw error(file, record.actionInstanceID, "status", "pending 不可有判定結果")
            }
        case .noEvent:
            guard record.selected == nil, record.noEventReason != nil else {
                throw error(file, record.actionInstanceID, "status", "no_event 必須有原因且不可有 selected")
            }
        case .inProgress, .completed:
            guard let selected = record.selected, record.noEventReason == nil else {
                throw error(file, record.actionInstanceID, "status", "\(record.status.rawValue): selected／原因錯誤")
            }
            let event = selected.snapshot.event
            let characterIDs = Set(selected.snapshot.characters.map { $0.id })
            guard characterIDs == Set(event.participants) else {
                throw error(file, event.id, "snapshot.characters", "快照角色不完整")
            }
            try validate(event: event, knownCharacterIDs: characterIDs)
            guard event.trigger.action == record.context.action else {
                throw error(file, event.id, "trigger.action", "事件來源行動與 context 不符")
            }
            guard event.dialogue(id: selected.currentDialogueID) != nil else {
                throw error(file, event.id, "currentDialogueID", "台詞游標不存在: \(selected.currentDialogueID)")
            }
            if record.status == .completed {
                guard selected.currentDialogueID == event.dialogues.last?.id else {
                    throw error(file, event.id, "currentDialogueID", "完成游標不是最後句")
                }
            }
        }
    }

    /// Checks that `triggeredEventIDs` exactly reflects the set of events ever selected
    /// across `records` — no missing entries, no phantom ones.
    ///
    /// Deliberately does *not* reject a single event ID appearing in more than one
    /// record. That would be a real problem for a record freshly created under today's
    /// rule (the runtime already prevents it — `EventConditionEvaluator` excludes
    /// anything already in `triggeredEventIDs` before it can ever be selected again),
    /// but a save migrated from before this rule existed can legitimately carry several
    /// old records that already selected the same once-repeatable event; the migration
    /// contract (FORMAT.md §5) is to preserve that history untouched, not flag it as
    /// corrupt.
    func validateTriggeredConsistency(_ save: PlayerEventSave) throws {
        let selectedEventIDs = Set(save.records.compactMap { $0.selected?.snapshot.event.id })
        guard selectedEventIDs == save.triggeredEventIDs else {
            throw error("save", nil, "triggeredEventIDs", "triggeredEventIDs 與已選取事件不一致")
        }
    }

    // MARK: - Event content semantics

    private func validate(event: GameEvent, knownCharacterIDs: Set<String>) throws {
        let file = "events_work.json"
        let participantSet = Set(event.participants)
        guard participantSet.count == event.participants.count else {
            throw error(file, event.id, "participants", "participants 重複")
        }
        guard participantSet.isSubset(of: knownCharacterIDs) else {
            throw error(file, event.id, "participants", "未知角色: \(participantSet.subtracting(knownCharacterIDs).sorted().joined(separator: ","))")
        }

        let conditions = event.conditions
        if let maximumDay = conditions.maximumDay, maximumDay < conditions.minimumDay {
            throw error(file, event.id, "conditions", "天數上下限矛盾")
        }
        if let maximumMoney = conditions.maximumMoney, maximumMoney < conditions.minimumMoney {
            throw error(file, event.id, "conditions", "金錢上下限矛盾")
        }
        guard Set(conditions.requiredFlags).isDisjoint(with: Set(conditions.excludedFlags)) else {
            throw error(file, event.id, "conditions", "旗標互斥")
        }
        guard event.selectionWeight >= 1 else {
            throw error(file, event.id, "selectionWeight", "非法權重: \(event.selectionWeight)")
        }

        guard !event.dialogues.isEmpty else {
            throw error(file, event.id, "dialogues", "空台詞陣列")
        }
        try requireUnique(event.dialogues.map { $0.id }, file: file, field: "dialogues.id", label: "台詞 ID", eventID: event.id)

        for line in event.dialogues {
            try validate(line: line, event: event, participantSet: participantSet, file: file)
        }
    }

    private func validate(line: EventDialogue, event: GameEvent, participantSet: Set<String>, file: String) throws {
        guard !line.text.isEmpty else {
            throw error(file, event.id, "dialogues[\(line.id)].text", "空台詞")
        }
        let strippedText = line.text.replacingOccurrences(of: "{playerName}", with: "")
        guard !strippedText.contains("{"), !strippedText.contains("}") else {
            throw error(file, event.id, "dialogues[\(line.id)].text", "不支援的文字替換")
        }

        let stageCharacterIDs = line.stage.map { $0.characterID }
        let stageSlots = line.stage.map { $0.slot }
        guard Set(stageCharacterIDs).count == stageCharacterIDs.count else {
            throw error(file, event.id, "dialogues[\(line.id)].stage", "站位角色重複")
        }
        guard Set(stageSlots).count == stageSlots.count else {
            throw error(file, event.id, "dialogues[\(line.id)].stage", "站位重複")
        }
        guard (1...3).contains(line.stage.count) else {
            throw error(file, event.id, "dialogues[\(line.id)].stage", "同時在場人數必須是 1～3: \(line.stage.count)")
        }
        let expectedSlots: Set<EventStageSlot> = switch line.stage.count {
        case 1: [.center]
        case 2: [.left, .right]
        default: [.left, .center, .right]
        }
        guard Set(stageSlots) == expectedSlots else {
            throw error(file, event.id, "dialogues[\(line.id)].stage", "站位不符合人數")
        }
        guard Set(stageCharacterIDs).isSubset(of: participantSet) else {
            throw error(file, event.id, "dialogues[\(line.id)].stage", "在場角色不在 participants")
        }
        guard stageCharacterIDs.contains(line.speakerID) else {
            throw error(file, event.id, "dialogues[\(line.id)].speakerID", "說話者不在本句舞台")
        }
    }

    private func validatePrerequisites(_ events: [GameEvent]) throws {
        let file = "events_work.json"
        let ids = Set(events.map { $0.id })
        let graph = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0.conditions.requiredCompletedEventIDs) })

        for (eventID, requirements) in graph {
            let unknown = Set(requirements).subtracting(ids)
            guard unknown.isEmpty else {
                throw error(file, eventID, "requiredCompletedEventIDs", "未知前置事件: \(unknown.sorted().joined(separator: ","))")
            }
        }

        var visiting = Set<String>()
        var done = Set<String>()
        func visit(_ eventID: String) throws {
            guard !visiting.contains(eventID) else {
                throw error(file, eventID, "requiredCompletedEventIDs", "前置事件循環")
            }
            guard !done.contains(eventID) else { return }
            visiting.insert(eventID)
            for dependency in graph[eventID] ?? [] {
                try visit(dependency)
            }
            visiting.remove(eventID)
            done.insert(eventID)
        }
        for eventID in ids {
            try visit(eventID)
        }
    }

    // MARK: - Helpers

    private func requireUnique(_ values: [String], file: String, field: String, label: String, eventID: String? = nil) throws {
        guard Set(values).count == values.count else {
            throw error(file, eventID, field, "重複\(label)")
        }
    }

    private func error(_ file: String, _ eventID: String?, _ field: String?, _ message: String) -> EventValidationError {
        EventValidationError(file: file, eventID: eventID, field: field, message: message)
    }
}

/// Rejects JSON keys the v1 format doesn't define — Codable's synthesized decoding
/// silently ignores stray keys, which is exactly the "typo swallowed silently" failure
/// mode GameEventData/FORMAT.md §1 calls out. Runs against the raw JSON structure
/// (before/alongside Codable decoding), checked at every object shape the schemas mark
/// `additionalProperties: false`.
enum EventRawStructureValidator {

    static func validateCharactersFile(_ data: Data, fileName: String) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try checkKeys(root, allowed: ["schemaVersion", "characters"], file: fileName, context: "root")
        guard let characters = root["characters"] as? [[String: Any]] else { return }
        for character in characters {
            let id = character["id"] as? String ?? "?"
            try checkKeys(character, allowed: ["id", "name", "portraitAsset", "presentation"], file: fileName, context: id)
            if let name = character["name"] as? [String: Any] {
                try checkKeys(name, allowed: ["source", "fallback"], file: fileName, context: "\(id).name")
            }
            if let presentation = character["presentation"] as? [String: Any] {
                try checkKeys(presentation, allowed: ["sampling", "scale", "offsetX", "offsetY"], file: fileName, context: "\(id).presentation")
            }
        }
    }

    static func validateEventsFile(_ data: Data, fileName: String) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try checkKeys(root, allowed: ["schemaVersion", "events"], file: fileName, context: "root")
        guard let events = root["events"] as? [[String: Any]] else { return }
        let eventKeys: Set<String> = [
            "id", "revision", "enabled", "title", "trigger", "conditions",
            "selectionWeight", "background", "participants", "dialogues",
        ]
        for event in events {
            let eventID = event["id"] as? String ?? "?"
            try checkKeys(event, allowed: eventKeys, file: fileName, context: eventID)
            if let trigger = event["trigger"] as? [String: Any] {
                try checkKeys(trigger, allowed: ["action", "timing"], file: fileName, context: "\(eventID).trigger")
            }
            if let conditions = event["conditions"] as? [String: Any] {
                try checkKeys(conditions, allowed: [
                    "minimumDay", "maximumDay", "minimumMoney", "maximumMoney",
                    "timePeriods", "requiredCompletedEventIDs", "requiredFlags", "excludedFlags",
                ], file: fileName, context: "\(eventID).conditions")
            }
            if let background = event["background"] as? [String: Any] {
                try checkKeys(background, allowed: ["mode", "assetName"], file: fileName, context: "\(eventID).background")
            }
            if let dialogues = event["dialogues"] as? [[String: Any]] {
                for dialogue in dialogues {
                    let lineID = dialogue["id"] as? String ?? "?"
                    try checkKeys(dialogue, allowed: ["id", "speakerID", "text", "stage"], file: fileName, context: "\(eventID).\(lineID)")
                    if let stage = dialogue["stage"] as? [[String: Any]] {
                        for actor in stage {
                            try checkKeys(actor, allowed: ["characterID", "slot"], file: fileName, context: "\(eventID).\(lineID).stage")
                        }
                    }
                }
            }
        }
    }

    static func validateRulesFile(_ data: Data, fileName: String) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try checkKeys(root, allowed: ["schemaVersion", "rules"], file: fileName, context: "root")
        guard let rules = root["rules"] as? [[String: Any]] else { return }
        for rule in rules {
            try checkKeys(rule, allowed: ["action", "enabled", "eventChance"], file: fileName, context: "rule")
        }
    }

    private static func checkKeys(_ object: [String: Any], allowed: Set<String>, file: String, context: String) throws {
        let extra = Set(object.keys).subtracting(allowed)
        guard extra.isEmpty else {
            throw EventValidationError(file: file, eventID: nil, field: extra.sorted().joined(separator: ","), message: "未定義欄位（\(context)）")
        }
    }
}
