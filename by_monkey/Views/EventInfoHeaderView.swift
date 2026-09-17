//
//  EventInfoHeaderView.swift
//  by_monkey
//

import UIKit

/// Lean top info panel for the event screen: just location/day/time-of-day plus the
/// event's own title — no money panel or action buttons (this screen is conversation
/// only). Fonts scale with Dynamic Type since this is a text-only status readout.
final class EventInfoHeaderView: UIView {

    private let panel = PixelPanelView()
    private let statusLabel = UILabel()
    private let contextLabel = UILabel()
    private let titleLabel = UILabel()

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(locationText: String, dayNumber: Int, timeOfDay: TimeOfDay, contextCaption: String, eventTitle: String) {
        statusLabel.text = "\(locationText) ・ 第 \(String(format: "%02d", dayNumber)) 天 ・ \(timeOfDay.title)"
        contextLabel.text = contextCaption
        titleLabel.text = eventTitle
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.cornerCut = 10
        addSubview(panel)

        statusLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold))
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = UIColor(white: 1, alpha: 0.75)

        contextLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 11, weight: .bold))
        contextLabel.adjustsFontForContentSizeCategory = true
        contextLabel.textColor = PixelTheme.gold

        titleLabel.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 19, weight: .heavy))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [statusLabel, contextLabel, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.setCustomSpacing(6, after: statusLabel)
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
        ])
    }
}
