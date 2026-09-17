//
//  TimeOfDaySegmentedControl.swift
//  by_monkey
//

import UIKit

/// The 早上 / 下午 / 晚上 tab bar. Display-only — the current period only advances
/// automatically once the day's action points are spent, so this control isn't tappable.
final class TimeOfDaySegmentedControl: UIView {

    /// Baseline icon size (28pt) shrunk by 4pt per feedback that it looked too large in this bar.
    private let iconSize: CGFloat = 24

    private let panel = PixelPanelView()
    private var buttons: [TimeOfDay: UIButton] = [:]
    private(set) var selected: TimeOfDay = .morning

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setSelected(_ timeOfDay: TimeOfDay) {
        selected = timeOfDay
        updateAppearance()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.cornerCut = 8
        addSubview(panel)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        panel.addSubview(stack)

        for timeOfDay in TimeOfDay.allCases {
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: timeOfDay.iconName)?
                .withRenderingMode(.alwaysOriginal)
                .resized(to: CGSize(width: iconSize, height: iconSize))
            config.title = timeOfDay.title
            config.imagePadding = 6
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 14, weight: .bold)
                return outgoing
            }
            button.configuration = config

            buttons[timeOfDay] = button
            stack.addArrangedSubview(button)
        }

        // Display-only: the active period changes automatically, not by tapping.
        isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: panel.topAnchor),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

            heightAnchor.constraint(equalToConstant: 52),
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        for (timeOfDay, button) in buttons {
            let isSelected = timeOfDay == selected
            button.configuration?.baseForegroundColor = isSelected ? .black : PixelTheme.gold.withAlphaComponent(0.7)
            button.backgroundColor = isSelected ? PixelTheme.gold : .clear
        }
    }
}
