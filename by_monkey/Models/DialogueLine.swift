//
//  DialogueLine.swift
//  by_monkey
//

import Foundation

/// One line of a scripted conversation: who says it and what they say.
/// Kept as plain data so dialogue content never lives inside view/layout code.
struct DialogueLine {
    let speaker: String
    let text: String
}
