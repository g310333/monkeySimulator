//
//  LocationBadgeView.swift
//  by_monkey
//

import UIKit

/// Small pixel-art pill labeling the current activity, e.g. "便利商店・打工".
final class LocationBadgeView: UIView {

    private let panel = PixelPanelView()
    private let label = UILabel()

    init(text: String) {
        super.init(frame: .zero)
        configure(text: text)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(text: String) {
        translatesAutoresizingMaskIntoConstraints = false

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.cornerCut = 8
        addSubview(panel)

        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = PixelTheme.gold
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(label)

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
        ])
    }
}
