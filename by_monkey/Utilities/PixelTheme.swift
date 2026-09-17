//
//  PixelTheme.swift
//  by_monkey
//

import UIKit

enum PixelTheme {
    static let gold = UIColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 1)
    static let panelFill = UIColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 0.82)
    /// Warm brown, not near-black — used where a solid-black fill would read as disabled/unselectable.
    /// Fully opaque and noticeably lighter than panelFill so it doesn't just look like black again.
    static let cardFill = UIColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1.0)
    /// Near-opaque dark fill for panels that must stay legible over busy art (dialogue box, modal sheets).
    static let dialoguePanelFill = UIColor(red: 0.05, green: 0.04, blue: 0.03, alpha: 0.95)
    /// Full-screen dim scrim behind modal sheets.
    static let overlayScrim = UIColor.black.withAlphaComponent(0.6)
}
