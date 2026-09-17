//
//  WorkDialogueScript.swift
//  by_monkey
//

import Foundation

/// Scripted conversations for the work mini-game. Separate from `WorkViewModel` so new
/// shifts/locations can add a script here without touching state-machine or view logic.
enum WorkDialogueScript {
    static func convenienceStoreOpening(playerName: String) -> [DialogueLine] {
        [
            DialogueLine(speaker: "店長", text: "早安，\(playerName)！先把架上的商品補齊，等等就要開始忙了。"),
            DialogueLine(speaker: playerName, text: "好，我先整理飲料區。今天也要努力賺錢！"),
            DialogueLine(speaker: "店長", text: "沒問題，補貨時記得檢查保存期限，有客人就先幫忙結帳。"),
        ]
    }
}
