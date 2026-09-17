//
//  DialogueBoxView.swift
//  by_monkey
//

import UIKit

/// The bottom dialogue panel: speaker tag, body text, progress ("01 / 03"), and a
/// continue prompt. The whole box is one tap target; content is purely data-driven via
/// `setLine` — no dialogue text lives here.
///
/// The box has a fixed height so it never grows/shrinks (and never moves the character
/// above it) as dialogue lines change length; body text wraps up to `bodyMaxLines` and
/// truncates beyond that rather than resizing the box.
final class DialogueBoxView: UIControl {

    private static let fixedHeight: CGFloat = 176
    private static let bodyMaxLines = 4

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

        speakerLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        speakerLabel.textColor = .black
        speakerLabel.translatesAutoresizingMaskIntoConstraints = false
        speakerTag.addSubview(speakerLabel)

        bodyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        bodyLabel.textColor = UIColor(white: 0.96, alpha: 1)
        bodyLabel.numberOfLines = Self.bodyMaxLines
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(bodyLabel)

        progressLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor = UIColor(white: 1, alpha: 0.55)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(progressLabel)

        continueLabel.font = .systemFont(ofSize: 13, weight: .bold)
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
            heightAnchor.constraint(equalToConstant: Self.fixedHeight),

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

            // `bodyLabel` sizes to its (capped) content from a fixed top inset; it does
            // not drive the box's height — the box's height is fixed above, and the
            // bottom row below is pinned independently to the panel's bottom edge.
            bodyLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
            bodyLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: progressLabel.topAnchor, constant: -10),

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

    /// Renders one line of dialogue. When `animated`, the speaker/body text fades in and
    /// rises ~3pt over ~180ms (skipped entirely under Reduce Motion).
    func setLine(speaker: String, text: String, progressText: String, continuePrompt: String, animated: Bool) {
        speakerLabel.text = speaker
        bodyLabel.text = text
        progressLabel.text = progressText
        continueLabel.text = continuePrompt
        accessibilityLabel = "\(speaker)：\(text)"
        accessibilityHint = continuePrompt

        guard animated, !UIAccessibility.isReduceMotionEnabled else { return }

        let riseOffset = CGAffineTransform(translationX: 0, y: 3)
        speakerLabel.alpha = 0
        bodyLabel.alpha = 0
        speakerLabel.transform = riseOffset
        bodyLabel.transform = riseOffset

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.speakerLabel.alpha = 1
            self.bodyLabel.alpha = 1
            self.speakerLabel.transform = .identity
            self.bodyLabel.transform = .identity
        }
    }
}
