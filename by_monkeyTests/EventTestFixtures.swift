//
//  EventTestFixtures.swift
//  by_monkeyTests
//

import Foundation
@testable import by_monkey

enum EventTestFixtures {

    static let playerCharacter = EventCharacter(
        id: "player",
        name: EventCharacterName(source: .playerName, fallback: "玩家"),
        portraitAsset: "player",
        presentation: EventCharacterPresentation(sampling: .nearest, scale: 1, offsetX: 0, offsetY: 0)
    )

    static let bossCharacter = EventCharacter(
        id: "boss",
        name: EventCharacterName(source: .fixed, fallback: "店長"),
        portraitAsset: "boss",
        presentation: EventCharacterPresentation(sampling: .nearest, scale: 1, offsetX: 0, offsetY: 0)
    )

    static let allCharacters = [playerCharacter, bossCharacter]

    static func conditions(
        minimumDay: Int = 1,
        maximumDay: Int? = nil,
        minimumMoney: Int = 0,
        maximumMoney: Int? = nil,
        timePeriods: [EventTimePeriod] = [],
        requiredCompletedEventIDs: [String] = [],
        requiredFlags: [String] = [],
        excludedFlags: [String] = []
    ) -> EventConditions {
        EventConditions(
            minimumDay: minimumDay, maximumDay: maximumDay,
            minimumMoney: minimumMoney, maximumMoney: maximumMoney,
            timePeriods: timePeriods, requiredCompletedEventIDs: requiredCompletedEventIDs,
            requiredFlags: requiredFlags, excludedFlags: excludedFlags
        )
    }

    static func makeEvent(
        id: String = "work_test_001",
        enabled: Bool = true,
        action: EventAction = .work,
        conditions: EventConditions = conditions(),
        selectionWeight: Int = 1,
        participants: [String] = ["player"],
        dialogues: [EventDialogue]? = nil
    ) -> GameEvent {
        GameEvent(
            id: id, revision: 1, enabled: enabled, title: "Test Event",
            trigger: EventTrigger(action: action, timing: .afterSettlement),
            conditions: conditions,
            selectionWeight: selectionWeight,
            background: .inherit, participants: participants,
            dialogues: dialogues ?? [
                EventDialogue(id: "line_001", speakerID: "player", text: "hi", stage: [EventStageActor(characterID: "player", slot: .center)]),
            ]
        )
    }

    static func makeContext(
        action: EventAction = .work,
        day: Int = 1,
        timePeriod: EventTimePeriod = .morning,
        money: Int = 1000,
        playerName: String = "阿杰"
    ) -> EventActionContext {
        EventActionContext(
            action: action, day: day, timePeriod: timePeriod, moneyAfterSettlement: money,
            playerName: playerName, backgroundAsset: "shop", locationName: "便利商店"
        )
    }

    static func makeSave(
        history: [EventCompletionHistory] = [],
        flags: [String] = [],
        triggeredEventIDs: Set<String> = []
    ) -> PlayerEventSave {
        PlayerEventSave(schemaVersion: PlayerEventSave.currentSchemaVersion, flags: flags, history: history, records: [], triggeredEventIDs: triggeredEventIDs)
    }
}

final class FakeEventRandomSource: EventRandomSource {
    private var values: [Double]
    private(set) var callCount = 0

    init(_ values: [Double]) {
        self.values = values
    }

    func nextUniformValue() -> Double {
        callCount += 1
        guard !values.isEmpty else { return 0 }
        return values.removeFirst()
    }
}
