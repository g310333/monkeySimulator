//
//  EventDialogueBoxView.swift
//  by_monkey
//

import UIKit

/// The event screen's bottom dialogue panel. Unlike the work mini-game's fixed-height
/// `DialogueBoxView`, this one grows to fit its content (per spec: "多行文字...不截斷") —
/// event lines are longer and more varied, so a fixed cap would risk cutting them off.
final class EventDialogueBoxView: UIControl {

    private let panel = PixelPanelView()
    private let speakerTag = PixelPanelView()
    private let speakerLabel = UILabel()
    private let bodyLabel = UILabel()
    private let progressLabel = UILabel()
    private let continueLabel = UILabel()
    private let continueArrow = UIImageView(image: UIImage(systemName: "chevron.down"))

    var onTap: (() -> Void)?

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.cornerCut = 12
        panel.fillColor = PixelTheme.dialoguePanelFill
        panel.panelBorderWidth = 2
        panel.isUserInteractionEnabled = false
        addSubview(panel)

        speakerTag.translatesAutoresizingMaskIntoConstraints = false
        speakerTag.cornerCut = 8
        speakerTag.fillColor = PixelTheme.gold
        speakerTag.borderColor = PixelTheme.gold
        speakerTag.isUserInteractionEnabled = false
        addSubview(speakerTag)

        speakerLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .heavy))
        speakerLabel.adjustsFontForContentSizeCategory = true
        speakerLabel.textColor = .black
        speakerLabel.translatesAutoresizingMaskIntoConstraints = false
        speakerTag.addSubview(speakerLabel)

        bodyLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16, weight: .medium))
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = UIColor(white: 0.96, alpha: 1)
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(bodyLabel)

        progressLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.textColor = UIColor(white: 1, alpha: 0.55)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(progressLabel)

        continueLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .bold))
        continueLabel.adjustsFontForContentSizeCategory = true
        continueLabel.textColor = PixelTheme.gold
        continueLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(continueLabel)

        continueArrow.tintColor = PixelTheme.gold
        continueArrow.contentMode = .scaleAspectFit
        continueArrow.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(continueArrow)

        isAccessibilityElement = true
        accessibilityTraits = .button

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            speakerTag.topAnchor.constraint(equalTo: panel.topAnchor, constant: -12),
            speakerTag.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),

            speakerLabel.topAnchor.constraint(equalTo: speakerTag.topAnchor, constant: 5),
            speakerLabel.bottomAnchor.constraint(equalTo: speakerTag.bottomAnchor, constant: -5),
            speakerLabel.leadingAnchor.constraint(equalTo: speakerTag.leadingAnchor, constant: 12),
            speakerLabel.trailingAnchor.constraint(equalTo: speakerTag.trailingAnchor, constant: -12),

            // `bodyLabel` drives the panel's height from a fixed top inset down to the
            // bottom row — this is what lets the box grow with longer dialogue instead
            // of ever truncating it.
            bodyLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
            bodyLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),

            progressLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 14),
            progressLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            progressLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),

            continueArrow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            continueArrow.centerYAnchor.constraint(equalTo: continueLabel.centerYAnchor),
            continueArrow.widthAnchor.constraint(equalToConstant: 14),
            continueArrow.heightAnchor.constraint(equalToConstant: 14),

            continueLabel.trailingAnchor.constraint(equalTo: continueArrow.leadingAnchor, constant: -6),
            continueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: progressLabel.trailingAnchor, constant: 8),
            continueLabel.centerYAnchor.constraint(equalTo: progressLabel.centerYAnchor),
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        onTap?()
    }

    /// Renders one line. When `animated`, speaker/body fade in over ~180ms (no rise —
    /// the work screen's dialogue box has that flourish; skipped entirely under Reduce
    /// Motion, and skipped outright here when `animated` is false, e.g. the first line).
    func setLine(speaker: String, text: String, progressText: String, continuePrompt: String, animated: Bool) {
        speakerLabel.text = speaker
        bodyLabel.text = text
        progressLabel.text = progressText
        continueLabel.text = continuePrompt
        accessibilityLabel = "\(speaker)：\(text)"
        accessibilityHint = continuePrompt

        guard animated, !UIAccessibility.isReduceMotionEnabled else { return }

        speakerLabel.alpha = 0
        bodyLabel.alpha = 0
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.speakerLabel.alpha = 1
            self.bodyLabel.alpha = 1
        }
    }
}
