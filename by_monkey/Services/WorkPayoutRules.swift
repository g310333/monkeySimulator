//
//  WorkPayoutRules.swift
//  by_monkey
//

import Foundation

/// Centralized work-payout amounts. The project has no other defined pay-rate rule yet,
/// so this is the one place a shift's reward is decided — never hardcode it in a view.
enum WorkPayoutRules {
    static let convenienceStoreShiftPayout = 800
}
