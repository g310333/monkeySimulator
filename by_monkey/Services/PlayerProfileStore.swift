//
//  PlayerProfileStore.swift
//  by_monkey
//

import Foundation

/// Single shared source of truth for player profile state (currently: money) that more
/// than one screen needs to read or mutate. Screens must read/write through this rather
/// than keeping their own copy, so a change made in one place (e.g. a work payout) is
/// immediately visible everywhere else (e.g. the action-selection HUD).
final class PlayerProfileStore {

    static let shared = PlayerProfileStore()

    /// Posted whenever `money` changes, so any screen currently on screen can refresh.
    static let moneyDidChangeNotification = Notification.Name("PlayerProfileStore.moneyDidChangeNotification")

    // Placeholder profile values until a real player-creation flow exists.
    let playerName = "阿杰"
    let playerNameCaption = "玩家名稱"
    let moneyCaption = "金錢"

    private(set) var money: Int

    private let defaults: UserDefaults
    private let moneyKey = "PlayerProfileStore.money"
    private let defaultMoney = 12_800

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: moneyKey) != nil {
            money = defaults.integer(forKey: moneyKey)
        } else {
            money = defaultMoney
        }
    }

    enum EarningsError: Error {
        case saveFailed
    }

    /// Adds `amount` to the player's money, persists it, and only *then* updates the
    /// in-memory value and notifies observers. If persistence fails, `money` is left
    /// untouched so a caller can retry with the exact same amount without ever having
    /// granted it twice.
    @discardableResult
    func addMoney(_ amount: Int) -> Result<Int, EarningsError> {
        guard amount != 0 else { return .success(money) }

        let newValue = money + amount
        defaults.set(newValue, forKey: moneyKey)

        // `synchronize()` is deprecated, but it's still the only synchronous signal
        // UserDefaults gives us that the write actually reached disk — needed here so a
        // failed save can be surfaced and retried instead of silently "succeeding".
        guard defaults.synchronize() else {
            return .failure(.saveFailed)
        }

        money = newValue
        NotificationCenter.default.post(name: Self.moneyDidChangeNotification, object: self)
        return .success(newValue)
    }

    /// "$ 12,800" style — for standing balances shown in a HUD.
    func formattedMoney(_ value: Int? = nil) -> String {
        "$ \(groupedDigits(value ?? money))"
    }

    /// "$800" style (no leading space) — for a delta amount, e.g. "＋$800".
    func formattedAmount(_ value: Int) -> String {
        "$\(groupedDigits(value))"
    }

    private func groupedDigits(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
