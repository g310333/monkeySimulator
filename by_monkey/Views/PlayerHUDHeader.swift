//
//  PlayerHUDHeader.swift
//  by_monkey
//

import UIKit

/// Top status bar: avatar + name/money/day panel, plus the action-points bar underneath it.
final class PlayerHUDHeader: UIView {

    private let avatarPanel = PixelPanelView()
    private let avatarImageView = UIImageView()

    private let infoPanel = PixelPanelView()
    private let nameLabel = UILabel()
    private let nameCaptionLabel = UILabel()
    private let moneyCaptionLabel = UILabel()
    private let moneyLabel = UILabel()
    private let dayLabel = UILabel()

    private let pointsPanel = PixelPanelView()
    private let pointsCaptionLabel = UILabel()
    private let pointsStack = UIStackView()
    private let pointsCountLabel = UILabel()

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(avatarImageName: String,
                   name: String,
                   nameCaption: String,
                   moneyCaption: String,
                   moneyText: String,
                   dayNumber: Int,
                   actionPointsCurrent: Int,
                   actionPointsMax: Int) {
        avatarImageView.image = UIImage(named: avatarImageName)
        nameLabel.text = name
        nameCaptionLabel.text = nameCaption
        moneyCaptionLabel.text = moneyCaption
        moneyLabel.text = moneyText
        dayLabel.attributedText = Self.dayAttributedString(dayNumber)
        pointsCountLabel.text = "\(actionPointsCurrent) / \(actionPointsMax)"

        pointsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for index in 0..<actionPointsMax {
            let diamond = UIImageView(image: UIImage(named: index < actionPointsCurrent ? "action_point_full" : "action_point_empty"))
            diamond.contentMode = .scaleAspectFit
            diamond.translatesAutoresizingMaskIntoConstraints = false
            diamond.widthAnchor.constraint(equalToConstant: 20).isActive = true
            diamond.heightAnchor.constraint(equalToConstant: 20).isActive = true
            pointsStack.addArrangedSubview(diamond)
        }
    }

    private static func dayAttributedString(_ day: Int) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: "第 ",
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white]
        )
        text.append(NSAttributedString(
            string: String(format: "%02d", day),
            attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .heavy), .foregroundColor: PixelTheme.gold]
        ))
        text.append(NSAttributedString(
            string: " 天",
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white]
        ))
        return text
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        setUpAvatar()
        setUpInfoPanel()
        setUpPointsPanel()
        setUpLayout()
    }

    private func setUpAvatar() {
        avatarPanel.translatesAutoresizingMaskIntoConstraints = false
        avatarPanel.cornerCut = 10
        addSubview(avatarPanel)

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarPanel.addSubview(avatarImageView)

        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: avatarPanel.topAnchor, constant: 6),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarPanel.leadingAnchor, constant: 6),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarPanel.trailingAnchor, constant: -6),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarPanel.bottomAnchor, constant: -6),
        ])
    }

    private func setUpInfoPanel() {
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.cornerCut = 10
        addSubview(infoPanel)

        nameLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        nameLabel.textColor = .white
        nameCaptionLabel.font = .systemFont(ofSize: 11, weight: .regular)
        nameCaptionLabel.textColor = UIColor(white: 1, alpha: 0.55)
        let nameSection = verticalSection([nameLabel, nameCaptionLabel])

        moneyCaptionLabel.font = .systemFont(ofSize: 11, weight: .regular)
        moneyCaptionLabel.textColor = UIColor(white: 1, alpha: 0.55)
        moneyLabel.font = .systemFont(ofSize: 18, weight: .heavy)
        moneyLabel.textColor = PixelTheme.gold
        let moneySection = verticalSection([moneyCaptionLabel, moneyLabel])

        dayLabel.textAlignment = .center
        let daySection = verticalSection([dayLabel])

        let sectionsStack = UIStackView(arrangedSubviews: [nameSection, moneySection, daySection])
        sectionsStack.translatesAutoresizingMaskIntoConstraints = false
        sectionsStack.axis = .horizontal
        sectionsStack.distribution = .fillEqually
        infoPanel.addSubview(sectionsStack)

        let divider1 = dividerView()
        let divider2 = dividerView()
        infoPanel.addSubview(divider1)
        infoPanel.addSubview(divider2)

        NSLayoutConstraint.activate([
            sectionsStack.topAnchor.constraint(equalTo: infoPanel.topAnchor, constant: 8),
            sectionsStack.bottomAnchor.constraint(equalTo: infoPanel.bottomAnchor, constant: -8),
            sectionsStack.leadingAnchor.constraint(equalTo: infoPanel.leadingAnchor, constant: 12),
            sectionsStack.trailingAnchor.constraint(equalTo: infoPanel.trailingAnchor, constant: -12),

            divider1.centerXAnchor.constraint(equalTo: nameSection.trailingAnchor),
            divider2.centerXAnchor.constraint(equalTo: moneySection.trailingAnchor),
            divider1.topAnchor.constraint(equalTo: sectionsStack.topAnchor),
            divider1.bottomAnchor.constraint(equalTo: sectionsStack.bottomAnchor),
            divider2.topAnchor.constraint(equalTo: sectionsStack.topAnchor),
            divider2.bottomAnchor.constraint(equalTo: sectionsStack.bottomAnchor),
        ])
    }

    private func setUpPointsPanel() {
        pointsPanel.translatesAutoresizingMaskIntoConstraints = false
        pointsPanel.cornerCut = 8
        addSubview(pointsPanel)

        pointsCaptionLabel.text = "行動點數"
        pointsCaptionLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pointsCaptionLabel.textColor = .white
        pointsCaptionLabel.translatesAutoresizingMaskIntoConstraints = false

        pointsStack.translatesAutoresizingMaskIntoConstraints = false
        pointsStack.axis = .horizontal
        pointsStack.spacing = 6

        pointsCountLabel.font = .systemFont(ofSize: 15, weight: .bold)
        pointsCountLabel.textColor = .white
        pointsCountLabel.translatesAutoresizingMaskIntoConstraints = false

        pointsPanel.addSubview(pointsCaptionLabel)
        pointsPanel.addSubview(pointsStack)
        pointsPanel.addSubview(pointsCountLabel)

        NSLayoutConstraint.activate([
            pointsCaptionLabel.leadingAnchor.constraint(equalTo: pointsPanel.leadingAnchor, constant: 16),
            pointsCaptionLabel.centerYAnchor.constraint(equalTo: pointsPanel.centerYAnchor),

            pointsStack.leadingAnchor.constraint(equalTo: pointsCaptionLabel.trailingAnchor, constant: 16),
            pointsStack.centerYAnchor.constraint(equalTo: pointsPanel.centerYAnchor),

            pointsCountLabel.trailingAnchor.constraint(equalTo: pointsPanel.trailingAnchor, constant: -16),
            pointsCountLabel.centerYAnchor.constraint(equalTo: pointsPanel.centerYAnchor),

            pointsPanel.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setUpLayout() {
        NSLayoutConstraint.activate([
            avatarPanel.topAnchor.constraint(equalTo: topAnchor),
            avatarPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarPanel.widthAnchor.constraint(equalToConstant: 84),
            avatarPanel.heightAnchor.constraint(equalToConstant: 84),

            infoPanel.topAnchor.constraint(equalTo: topAnchor),
            infoPanel.leadingAnchor.constraint(equalTo: avatarPanel.trailingAnchor, constant: 10),
            infoPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            infoPanel.heightAnchor.constraint(equalTo: avatarPanel.heightAnchor),

            pointsPanel.topAnchor.constraint(equalTo: avatarPanel.bottomAnchor, constant: 10),
            pointsPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            pointsPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            pointsPanel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func verticalSection(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        return stack
    }

    private func dividerView() -> UIView {
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = PixelTheme.gold.withAlphaComponent(0.35)
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }
}
