//
//  ActionSelectionViewModel.swift
//  by_monkey
//

import Foundation

final class ActionSelectionViewModel {

    private let profileStore: PlayerProfileStore

    let backgroundImageName = "back"
    let avatarImageName = "player"

    var playerName: String { profileStore.playerName }
    var playerNameCaption: String { profileStore.playerNameCaption }
    var moneyCaption: String { profileStore.moneyCaption }
    var moneyText: String { profileStore.formattedMoney() }

    let actionPointsMax = 3
    private(set) var dayNumber = 1
    private(set) var actionPointsCurrent: Int
    private(set) var selectedTimeOfDay: TimeOfDay = .morning

    let actions = PlayerAction.allCases

    var onActionSelected: ((PlayerAction) -> Void)?
    /// Fired whenever points/time-of-day/day/money change so the HUD can refresh itself.
    var onStateChanged: (() -> Void)?

    private var moneyObserver: NSObjectProtocol?

    init(profileStore: PlayerProfileStore = .shared) {
        self.profileStore = profileStore
        actionPointsCurrent = actionPointsMax

        // Money is earned elsewhere (e.g. the work mini-game) and must be reflected here
        // the moment it changes, without this screen holding its own copy of the value.
        moneyObserver = NotificationCenter.default.addObserver(
            forName: PlayerProfileStore.moneyDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onStateChanged?()
        }
    }

    deinit {
        if let moneyObserver {
            NotificationCenter.default.removeObserver(moneyObserver)
        }
    }

    var hudSnapshot: PlayerHUDSnapshot {
        PlayerHUDSnapshot(
            avatarImageName: avatarImageName,
            name: playerName,
            nameCaption: playerNameCaption,
            moneyCaption: moneyCaption,
            moneyText: moneyText,
            dayNumber: dayNumber,
            actionPointsCurrent: actionPointsCurrent,
            actionPointsMax: actionPointsMax,
            selectedTimeOfDay: selectedTimeOfDay
        )
    }

    /// Time of day is never chosen directly by the player — it only advances once
    /// the current period's action points are spent.
    func selectAction(_ action: PlayerAction) {
        guard actionPointsCurrent > 0 else { return }

        onActionSelected?(action)
        actionPointsCurrent -= 1

        if actionPointsCurrent == 0 {
            advanceTimeOfDay()
        }

        onStateChanged?()
    }

    private func advanceTimeOfDay() {
        switch selectedTimeOfDay {
        case .morning:
            selectedTimeOfDay = .afternoon
        case .afternoon:
            selectedTimeOfDay = .night
        case .night:
            selectedTimeOfDay = .morning
            dayNumber += 1
        }
        actionPointsCurrent = actionPointsMax
    }
}
