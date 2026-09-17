//
//  PlayerHUDSnapshot.swift
//  by_monkey
//

import Foundation

/// Read-only copy of the values `PlayerHUDHeader` needs, so a screen that isn't the
/// action-selection screen itself (e.g. the work mini-game) can render the same real
/// player status without holding its own reference to `ActionSelectionViewModel`.
struct PlayerHUDSnapshot {
    let avatarImageName: String
    let name: String
    let nameCaption: String
    let moneyCaption: String
    let moneyText: String
    let dayNumber: Int
    let actionPointsCurrent: Int
    let actionPointsMax: Int
    let selectedTimeOfDay: TimeOfDay

    /// Used only if the real action-selection view model has somehow already been
    /// deallocated when a snapshot is requested — should not happen in practice, since
    /// the screen that owns it outlives anything presented on top of it.
    static var fallback: PlayerHUDSnapshot {
        PlayerHUDSnapshot(
            avatarImageName: "player",
            name: PlayerProfileStore.shared.playerName,
            nameCaption: PlayerProfileStore.shared.playerNameCaption,
            moneyCaption: PlayerProfileStore.shared.moneyCaption,
            moneyText: PlayerProfileStore.shared.formattedMoney(),
            dayNumber: 1,
            actionPointsCurrent: 3,
            actionPointsMax: 3,
            selectedTimeOfDay: .morning
        )
    }
}
