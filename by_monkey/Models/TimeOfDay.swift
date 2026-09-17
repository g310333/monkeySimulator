//
//  TimeOfDay.swift
//  by_monkey
//

import Foundation

enum TimeOfDay: CaseIterable {
    case morning
    case afternoon
    case night

    var title: String {
        switch self {
        case .morning: return "早上"
        case .afternoon: return "下午"
        case .night: return "晚上"
        }
    }

    var iconName: String {
        switch self {
        case .morning: return "time_morning"
        case .afternoon: return "time_afternoon"
        case .night: return "time_night"
        }
    }
}
