//
//  PlayerAction.swift
//  by_monkey
//

import Foundation

// `String` + `Codable` so an action can be recorded as the source of a persisted event
// record (`ActionEventRecord`) without any separate mapping table.
enum PlayerAction: String, CaseIterable, Codable {
    case work
    case stocks
    case touge
    case shopping

    var title: String {
        switch self {
        case .work: return "打工"
        case .stocks: return "股票"
        case .touge: return "跑山"
        case .shopping: return "購物"
        }
    }

    var subtitle: String {
        switch self {
        case .work: return "努力賺取收入"
        case .stocks: return "掌握投資機會"
        case .touge: return "騎車探索山路"
        case .shopping: return "逛逛添購物品"
        }
    }

    var iconName: String {
        switch self {
        case .work: return "action_work"
        case .stocks: return "action_stocks"
        case .touge: return "action_mountain_ride"
        case .shopping: return "action_shop"
        }
    }
}
